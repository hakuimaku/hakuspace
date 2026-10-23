#!/usr/bin/env python3
"""Native Hikai discovery, proxy cache and two-phase wallpaper selection."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import math
import os
import signal
import subprocess
import sys
import tempfile
import time
from fractions import Fraction
from pathlib import Path

# Source and flattened installations use the same settings and state helpers.
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.extend([str(SCRIPT_DIR.parent / "user"), str(SCRIPT_DIR.parent.parent / "lib")])
from hikai_wallpaper_settings_ctl import run as settings_run
from haku_state import state_path

# Recognized local media extensions never allow network URLs as sources.
IMAGES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".avif"}
VIDEOS = {".mp4", ".mkv", ".webm", ".mov", ".m4v"}
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hakuspace/wallpaper"
CURRENT = state_path("desktop.wallpaper.current.json")
RUNTIME = state_path("desktop.wallpaper.runtime.json")
PENDING = CACHE / "pending.json"


def read_json(path, default=None):
    """Treat absent cache entries as misses while surfacing malformed state."""
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def atomic_json(path, value):
    """Publish complete JSON through a flushed sibling temporary file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".wallpaper-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


@contextlib.contextmanager
def locked(path, blocking=True):
    """Serialize cache mutations and deduplicate proxy jobs across processes."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield


def directories():
    """Read existing shell preferences in one subprocess, without parsing shell syntax."""
    result = subprocess.run(["bash", "-c", 'if [ -f "$HOME/hakucfg/setting.sh" ]; then source "$HOME/hakucfg/setting.sh" >&2; fi; printf "%s\\0%s\\0" "${WALL_DIR:-$HOME/Pictures/Wallpapers}" "${WALL_MPV_DIR:-$HOME/Videos/Wallpapers}"'],
                            capture_output=True, check=True)
    return [Path(os.fsdecode(value)) for value in result.stdout.split(b"\0")[:2]]


def resolve(source):
    """Resolve paths or discovered names to a supported regular local media file."""
    path = Path(source).expanduser()
    if not path.is_absolute() and not path.is_file():
        path = next((directory / source for directory in directories() if (directory / source).is_file()), path)
    path = path.resolve(strict=True)
    if not path.is_file() or path.suffix.lower() not in IMAGES | VIDEOS:
        raise ValueError("unsupported wallpaper source")
    return path


def fingerprint(path):
    """Invalidate artifacts when the canonical source size or nanosecond mtime changes."""
    info = path.stat()
    return {"path": str(path.resolve()), "size": info.st_size, "mtimeNs": info.st_mtime_ns}


def digest(value):
    """Hash an ordered contract so equivalent requests share a cache identity."""
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def inspect(path):
    """Cache ffprobe results once per source fingerprint outside QML delegates."""
    key = fingerprint(path)
    target = CACHE / "metadata" / (digest(key) + ".json")
    cached = read_json(target)
    if cached:
        return cached
    result = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                             "stream=width,height,avg_frame_rate,codec_name:format=duration", "-of", "json", str(path)],
                            capture_output=True, text=True, check=True, timeout=30)
    data = json.loads(result.stdout)
    stream = data["streams"][0]
    fps = float(Fraction(stream.get("avg_frame_rate", "0/1")))
    metadata = {"width": int(stream["width"]), "height": int(stream["height"]), "fps": fps,
                "durationMs": round(float(data.get("format", {}).get("duration", 0)) * 1000),
                "codec": stream.get("codec_name", ""), "fileSize": key["size"]}
    if metadata["width"] < 2 or metadata["height"] < 2 or not math.isfinite(fps) or fps <= 0:
        raise ValueError("video has invalid dimensions or frame rate")
    atomic_json(target, metadata)
    return metadata


def profile_result(metadata, profile, width=1920, height=1080):
    """Fit source dimensions without upscaling and bound decoded frame rate."""
    if profile not in ("original", "screen", "low-memory"):
        raise ValueError("unknown playback profile")
    if not 2 <= width <= 32768 or not 2 <= height <= 32768:
        raise ValueError("invalid target output dimensions")
    source_w, source_h = metadata["width"], metadata["height"]
    cap_w, cap_h, fps = (1280, 720, 24) if profile == "low-memory" else (width, height, 60)
    scale = min(1, cap_w / source_w, cap_h / source_h)
    needed = profile != "original" and (scale < 1 or metadata["fps"] > fps)
    return {"width": max(2, int(source_w * scale) // 2 * 2) if needed else source_w,
            "height": max(2, int(source_h * scale) // 2 * 2) if needed else source_h,
            "fps": min(fps, metadata["fps"]) if needed else metadata["fps"], "needed": needed}


def proxy_identity(path, profile, width, height, metadata):
    """Include source, target caps, profile and encoder version in every proxy key."""
    return digest({"source": fingerprint(path), "profile": profile, "widthCap": 1280 if profile == "low-memory" else width,
                   "heightCap": 720 if profile == "low-memory" else height, "fpsCap": 24 if profile == "low-memory" else 60,
                   "codecVersion": "h264-yuv420p-v1", "output": profile_result(metadata, profile, width, height)})


def run_ffmpeg(arguments, output):
    """Bound workers and remove partial media on failure or termination."""
    temporary = output.with_name(output.stem + ".part" + output.suffix)
    process = None
    try:
        process = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-threads", "2",
                                    *arguments, str(temporary)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        _, error = process.communicate()
        if process.returncode:
            raise ValueError("FFmpeg failed: " + error[-1500:])
        if not temporary.is_file() or temporary.stat().st_size == 0:
            raise ValueError("FFmpeg produced an empty file")
        return temporary
    except BaseException:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        temporary.unlink(missing_ok=True)
        raise


def thumbnail(path):
    """Build a bounded still preview; thumbnails never write into source folders."""
    target = CACHE / "thumbnails" / (digest(fingerprint(path)) + ".jpg")
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        with locked(target.with_suffix(".lock")):
            if not target.exists():
                temporary = run_ffmpeg(["-filter_threads", "1", "-i", str(path), "-frames:v", "1", "-vf",
                                        "scale=480:270:force_original_aspect_ratio=decrease", "-an", "-threads", "2"], target)
                os.replace(temporary, target)
    return str(target)


def ensure_proxy(path, profile, width, height, build, rebuild=False):
    """Build once under a key lock, validate the output and publish it atomically."""
    if profile == "original":
        try:
            metadata = inspect(path)
            return str(path), metadata, profile_result(metadata, profile, width, height)
        except (OSError, ValueError, KeyError, IndexError, ZeroDivisionError, subprocess.SubprocessError):
            # Qt can play the original without the optional ffprobe/FFmpeg command-line tools.
            return str(path), {}, {"needed": False}
    metadata = inspect(path)
    result = profile_result(metadata, profile, width, height)
    if not result["needed"]:
        return str(path), metadata, result
    key = proxy_identity(path, profile, width, height, metadata)
    if rebuild:
        key = digest({"base": key, "rebuild": time.time_ns()})
    target = CACHE / "proxies" / (key + ".mp4")
    with locked(target.with_suffix(".lock")):
        if not target.exists():
            if not build:
                raise ValueError("Proxy is missing. Use Build & apply or select Original.")
            # A single encoder worker bounds CPU and peak memory across distinct requests.
            with locked(CACHE / "encoder.lock"):
                temporary = run_ffmpeg(["-filter_threads", "1", "-i", str(path), "-map", "0:v:0", "-vf",
                                        f"scale={result['width']}:{result['height']},fps={result['fps']}",
                                        "-an", "-sn", "-dn", "-c:v", "libx264", "-profile:v", "main", "-pix_fmt", "yuv420p",
                                        "-preset", "veryfast", "-crf", "24", "-threads", "2", "-movflags", "+faststart"], target)
                try:
                    checked = inspect(temporary)
                    if (checked["width"], checked["height"]) != (result["width"], result["height"]) or checked["fps"] > result["fps"] + 0.02:
                        raise ValueError("proxy validation failed")
                    os.replace(temporary, target)
                finally:
                    temporary.unlink(missing_ok=True)
        os.utime(target, None)
    return str(target), metadata, result


def evict(max_mib, clear=False):
    """Evict least recently used proxies while protecting committed and pending sources."""
    protected = {record.get("proxyPath") for record in (read_json(CURRENT, {}), read_json(PENDING, {}))}
    files = sorted((CACHE / "proxies").glob("*.mp4"), key=lambda file: file.stat().st_mtime)
    total = sum(file.stat().st_size for file in files)
    for file in files:
        if not clear and total <= max_mib * 1024 * 1024:
            break
        if str(file) in protected:
            continue
        try:
            with locked(file.with_suffix(".lock"), blocking=False):
                total -= file.stat().st_size
                file.unlink()
        except BlockingIOError:
            continue
    return total


def prepare(source, profile, width, height, build=False, rebuild=False):
    """Resolve a candidate without replacing the working committed wallpaper."""
    path = resolve(source)
    preferences = settings_run("read")["values"]
    profile = profile or preferences["playback"]["profile"]
    record = {"path": str(path), "kind": "video" if path.suffix.lower() in VIDEOS else "static", "profile": profile,
              "proxyPath": "", "thumbnail": "", "targetWidth": width, "targetHeight": height}
    if record["kind"] == "video":
        record["proxyPath"], record["metadata"], record["render"] = ensure_proxy(
            path, profile, width, height, build or preferences["proxy"]["buildPolicy"] != "manual", rebuild)
    else:
        record["proxyPath"] = str(path)
    try:
        record["thumbnail"] = thumbnail(path)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    record["token"] = digest({"record": record, "created": time.time_ns()})
    atomic_json(PENDING, record)
    evict(preferences["proxy"]["maxCacheMiB"])
    return record


def commit(token):
    """Apply images through awww and persist videos only after native readiness."""
    pending = read_json(PENDING, {})
    if not token or pending.get("token") != token:
        raise ValueError("selection expired; select the wallpaper again")
    resolve(pending["path"])
    if not Path(pending["proxyPath"]).is_file():
        raise ValueError("prepared wallpaper has disappeared")
    setter = SCRIPT_DIR.parent.parent / "theme/wallpaper_set.sh"
    if not setter.is_file():
        setter = Path.home() / ".local/bin/wallpaper_set.sh"
    applied = subprocess.run(["bash", str(setter), pending["path"]], capture_output=True, text=True,
                             env=dict(os.environ, HAKUSPACE_WALLPAPER_NATIVE_COMMIT="1"))
    if applied.returncode:
        raise ValueError(applied.stderr.strip() or "could not apply wallpaper")
    atomic_json(CURRENT, pending)
    PENDING.unlink(missing_ok=True)
    # Preserve the legacy read-only compatibility pointer for other desktop tools.
    legacy = Path.home() / ".cache/current_wallpaper"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".wallpaper-", dir=legacy.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(pending["path"] + "\n")
        os.replace(temporary, legacy)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return pending


def discover(kind="all"):
    """Discover local images and videos with cached metadata and still thumbnails."""
    items = []
    seen = set()
    current = read_json(CURRENT, {}).get("path")
    for directory in directories():
        if not directory.is_dir():
            continue
        for path in directory.iterdir():
            suffix = path.suffix.lower()
            category = "video" if suffix in VIDEOS else "static"
            if suffix not in IMAGES | VIDEOS or not path.is_file() or (kind != "all" and category != kind):
                continue
            canonical = str(path.resolve())
            if canonical in seen:
                continue
            seen.add(canonical)
            record = {"id": path.name, "path": canonical, "label": path.stem, "kind": category,
                      "selected": canonical == current, "thumbnail": "", "previewVersion": str(path.stat().st_mtime_ns)}
            try:
                record["thumbnail"] = thumbnail(path)
                if category == "video":
                    record["metadata"] = inspect(path)
            except (OSError, ValueError, KeyError, IndexError, ZeroDivisionError, subprocess.SubprocessError) as error:
                record["error"] = str(error)
            items.append(record)
    return sorted(items, key=lambda item: item["label"].casefold())


def current_source():
    """Restore native state, adopting the Classic compatibility pointer on first start."""
    record = read_json(CURRENT, {})
    if record.get("path"):
        return record["path"]
    legacy = Path.home() / ".cache/current_wallpaper"
    return legacy.read_text().splitlines()[0] if legacy.is_file() and legacy.stat().st_size else ""


def main():
    """Expose JSON commands and configure decoder policy before Qt initializes."""
    if len(sys.argv) > 1 and sys.argv[1] == "launch":
        environment = os.environ.copy()
        try:
            decode = settings_run("read")["values"]["playback"]["hardwareDecode"]
        except (ValueError, OSError) as error:
            print(error, file=sys.stderr)
            decode = "auto"
        environment.pop("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", None)
        if decode == "software":
            environment["QT_FFMPEG_DECODING_HW_DEVICE_TYPES"] = ","
        # Prefer keeps Qt's validated platform ordering instead of forcing a GPU vendor.
        os.execvpe("qs", ["qs", *sys.argv[2:]], environment)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "inspect", "select", "commit", "cancel", "current", "status", "restore", "proxy", "runtime", "handoff", "warm"))
    parser.add_argument("source", nargs="?", default="")
    parser.add_argument("--profile", choices=("original", "screen", "low-memory"))
    parser.add_argument("--kind", choices=("all", "static", "video"), default="all")
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.action == "list":
        return discover(args.kind)
    if args.action == "inspect":
        return inspect(resolve(args.source))
    if args.action == "current":
        return read_json(CURRENT, {})
    if args.action == "status":
        return {"current": read_json(CURRENT, {}), "runtime": read_json(RUNTIME, {}),
                "cacheBytes": sum(path.stat().st_size for path in (CACHE / "proxies").glob("*.mp4"))}
    if args.action == "warm":
        sources = json.loads(os.environ.get("HAKUSPACE_WALLPAPER_SOURCES_JSON", "[]"))
        if type(sources) is not list or len(sources) > 10000 or any(type(path) is not str for path in sources):
            raise ValueError("invalid background wallpaper list")
        preferences = settings_run("read")["values"]
        errors = []
        for source in sources:
            try:
                with locked(CACHE / "cache.lock"):
                    ensure_proxy(resolve(source), args.profile or preferences["playback"]["profile"], args.width, args.height, True)
                    evict(preferences["proxy"]["maxCacheMiB"])
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                errors.append(str(error))
        return {"errors": errors}
    if args.action == "runtime":
        data = json.loads(os.environ.get("HAKUSPACE_WALLPAPER_RUNTIME_JSON", "{}"))
        atomic_json(RUNTIME, data)
        return data
    if args.action == "handoff":
        # Called once after a ready native surface takes ownership during Hikai activation.
        if not os.environ.get("HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF"):
            subprocess.run(["pkill", "-x", "mpvpaper"], check=False)
        return {"ok": True}
    with locked(CACHE / "cache.lock"):
        if args.action == "cancel":
            if read_json(PENDING, {}).get("token") == args.source:
                PENDING.unlink(missing_ok=True)
            return {"ok": True}
        if args.action == "commit":
            return commit(args.source)
        if args.action == "proxy":
            preferences = settings_run("read")["values"]
            if args.source == "clear-unused":
                return {"cacheBytes": evict(preferences["proxy"]["maxCacheMiB"], clear=True)}
            if args.source == "rebuild-current":
                record = read_json(CURRENT, {})
                path = resolve(record["path"])
                # Keep the active proxy intact until a new fingerprinted build succeeds.
                record = prepare(str(path), args.profile or record["profile"], args.width, args.height, True, rebuild=True)
                return record
            raise ValueError("usage: proxy clear-unused|rebuild-current")
        source = current_source() if args.action == "restore" else args.source
        return prepare(source, args.profile, args.width, args.height, args.build) if source else {}


if __name__ == "__main__":
    # Termination unwinds FFmpeg cleanup instead of leaving an orphan encoder.
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(143))
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, ValueError, KeyError, IndexError, ZeroDivisionError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
