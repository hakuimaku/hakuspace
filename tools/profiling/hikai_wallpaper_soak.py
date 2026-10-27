#!/usr/bin/env python3
"""Measure an isolated native profile or mpvpaper baseline; defaults to a 60-minute loop."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time

# Locate production files while keeping benchmark media and state outside the repository.
ROOT = Path(__file__).resolve().parents[2]


def sample(pid):
    """Measure the shell and native renderer separately, with comparable combined totals."""
    from hikai_memory_soak import sample as process_sample
    values = process_sample(pid)
    renderers = []
    children = set()
    for task in (Path("/proc") / str(pid) / "task").iterdir():
        try:
            children.update((task / "children").read_text().split())
        except FileNotFoundError:
            pass
    for child in children:
        try:
            if b"/WallpaperRenderer.qml" in (Path("/proc") / child / "cmdline").read_bytes():
                renderers.append(process_sample(int(child)) | {"pid": int(child)})
        except FileNotFoundError:
            pass
    values["renderers"] = renderers
    for metric in ("rssKiB", "pssKiB", "cpuSeconds", "gpuResidentKiB"):
        parts = [values[metric], *(renderer[metric] for renderer in renderers)]
        values["total" + metric[0].upper() + metric[1:]] = sum(parts) if all(value is not None for value in parts) else None
    return values


def cycle_session(shell, output, seconds, cycles):
    """Gate image recovery, reload and child failure against the same native workload."""
    process = subprocess.Popen(["quickshell", "-p", shell])
    report = {"samples": [], "cycles": cycles, "warmupSec": 3, "settleSec": 3, "complete": False}
    started = time.monotonic()

    # Address only the private shell, including after its configuration reloads.
    def ipc(method, *args):
        return subprocess.check_output(["quickshell", "ipc", "--pid", str(process.pid), "call", "wallpaperSoak", method, *args],
                                       text=True, stderr=subprocess.DEVNULL, timeout=10).strip()

    def wait(kind=None, failed=False):
        for _ in range(300):
            if process.poll() is not None:
                raise RuntimeError("private shell exited")
            try:
                payload = ipc("state")
                if not payload.startswith("{"):
                    time.sleep(0.1)
                    continue
                state = json.loads(payload)
                if failed and state["error"]:
                    return state
                if state["error"]:
                    raise RuntimeError(state["error"])
                if state["ready"] and not state["busy"] and (kind is None or state.get("kind") == kind):
                    if kind != "video" or state["slots"] and all(slot["front"] for slot in state["slots"]):
                        return state
            except subprocess.CalledProcessError:
                pass
            time.sleep(0.1)
        raise RuntimeError("wallpaper state timed out")

    def select(kind):
        path = os.environ["HAKUSPACE_SOAK_SOURCE" if kind == "video" else "HAKUSPACE_SOAK_IMAGE"]
        transition = time.monotonic()
        assert ipc("select", path) == "true"
        wait(kind)
        return round(time.monotonic() - transition, 3)

    def record(phase, **extra):
        row = sample(process.pid) | {"phase": phase, "elapsedSec": round(time.monotonic() - started, 3),
                                     "state": json.loads(ipc("state"))} | extra
        report["samples"].append(row)
        Path(output).write_text(json.dumps(report, indent=2) + "\n")
        return row

    try:
        wait(); select("static"); time.sleep(3)
        baseline = record("image-baseline")
        for cycle in range(1, cycles + 1):
            latency = select("video"); time.sleep(seconds)
            playing = record("video", cycle=cycle, firstFrameSec=latency)
            assert len(playing["renderers"]) == 1, "one native renderer process must own all outputs"
            select("static"); time.sleep(3)
            image = record("image", cycle=cycle)
            assert not image["renderers"] and not image["state"]["rendererPid"], "image retained the renderer process"
            assert all(not slot["front"] and not slot["incoming"] and not slot["visible"] for slot in image["state"]["slots"])
            assert image["rssKiB"] - baseline["rssKiB"] < 32768, "image retained over 32 MiB in the shell"
            assert image["fdCount"] <= baseline["fdCount"] + 4 and image["threadCount"] <= baseline["threadCount"] + 2
        # An immediate reopen must wait for the old worker's exit before starting again.
        select("video"); select("static"); select("video")
        time.sleep(3); record("video-rapid-reopen")
        select("static"); time.sleep(3)
        # A reload must replace the worker without losing the committed video.
        select("video"); time.sleep(1)
        previous = int(json.loads(ipc("state"))["rendererPid"])
        ipc("reload")
        restored = wait("video"); time.sleep(3)
        assert int(restored["rendererPid"]) != previous and not Path(f"/proc/{previous}").exists(), "reload orphaned a renderer"
        record("video-reloaded")
        # Worker failure must leave the shell available for a new image/video selection.
        os.kill(int(restored["rendererPid"]), signal.SIGTERM)
        wait(failed=True)
        select("static"); time.sleep(3); recovered = record("image-after-failure")
        select("video"); time.sleep(seconds); record("video-recovered")
        select("static"); time.sleep(3); final = record("image-final")
        assert not final["renderers"] and final["rssKiB"] - recovered["rssKiB"] < 32768
        report["complete"] = True
        Path(output).write_text(json.dumps(report, indent=2) + "\n")
    finally:
        process.terminate()
        process.wait(timeout=10)


def measure(pid, output, seconds):
    """Record initial, five-, fifteen-, thirty- and sixty-minute samples plus the endpoint."""
    start = time.monotonic()
    samples = []
    for target in sorted({0, seconds, *(minute * 60 for minute in (5, 15, 30, 60) if minute * 60 < seconds)}):
        while time.monotonic() - start < target:
            time.sleep(max(0, min(1, target - (time.monotonic() - start))))
        value = sample(pid) | {"elapsedSec": round(time.monotonic() - start, 2)}
        if samples:
            value["cpuPercent"] = round((value["totalCpuSeconds"] - samples[-1]["totalCpuSeconds"]) * 100
                                        / max(0.001, value["elapsedSec"] - samples[-1]["elapsedSec"]), 2)
        samples.append(value)
        output.write_text(json.dumps({"pid": pid, "durationSec": seconds, "samples": samples,
                                      "complete": target == seconds, "droppedFrames": None}, indent=2) + "\n")
    return samples


def run_baseline(source, output, seconds):
    """Measure only the launched baseline process and terminate that exact child afterward."""
    process = subprocess.Popen(["mpvpaper", "-o", "no-audio loop hwdec=no", "HEADLESS-1", source])
    try:
        time.sleep(1)
        if process.poll() is not None:
            raise RuntimeError("mpvpaper could not initialize on the private headless output")
        measure(process.pid, Path(output), seconds)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    """Build a private HOME, output and compositor session for one comparable measurement."""
    if len(sys.argv) > 1 and sys.argv[1] == "_cycles":
        cycle_session(sys.argv[2], sys.argv[3], float(sys.argv[4]), int(sys.argv[5]))
        return
    if len(sys.argv) > 1 and sys.argv[1] == "_sample":
        measure(os.getppid(), Path(sys.argv[2]), int(sys.argv[3]))
        return
    if len(sys.argv) > 1 and sys.argv[1] == "_baseline":
        run_baseline(sys.argv[2], sys.argv[3], int(sys.argv[4]))
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--profile", choices=("original", "screen", "low-memory", "mpvpaper"), required=True)
    parser.add_argument("--seconds", type=int, default=3600)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cycles", type=int, default=0, help="Run image/video recovery cycles; seconds is playback time per cycle")
    args = parser.parse_args()
    if not args.source.is_file() or not 1 <= args.seconds <= 86400 or not 0 <= args.cycles <= 100 or args.cycles and args.profile == "mpvpaper":
        parser.error("source must exist, seconds must be 1..86400 and native cycles must be 0..100")
    args.source = args.source.resolve()
    args.output = args.output.resolve()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hikai-soak-") as temporary:
        work = Path(temporary)
        shell = work / "src/home/.config/quickshell/hakuspace"
        shell.mkdir(parents=True)
        for name in ("services", "components"):
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace" / name, shell / name)
        shutil.copy(ROOT / "tools/profiling/harness/wallpaper_soak.qml", shell / "shell.qml")
        for name in ("backend", "lib", "theme", "state"):
            shutil.copytree(ROOT / "src/core" / name, work / "src/core" / name)
        home = work / "home"
        (home / "hakucfg").mkdir(parents=True)
        (home / "hakucfg/setting.sh").write_text("ACCENT_COLOR_BASED_ON_WALLPAPER=false\n")
        if args.cycles:
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=green:s=64x36", "-frames:v", "1", "-threads", "1", str(home / "still.png")], check=True)
        runtime = work / "runtime"
        runtime.mkdir(mode=0o700)
        compositor = work / "labwc"
        compositor.mkdir()
        (compositor / "rc.xml").write_text("<labwc_config/>")
        environment = {key: value for key, value in os.environ.items() if key not in (
            "DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6",
            "HYPRLAND_INSTANCE_SIGNATURE", "NIRI_SOCKET", "MANGO_INSTANCE_SIGNATURE") and not key.startswith("HAKUSPACE_")}
        environment.update(HOME=str(home), XDG_CACHE_HOME=str(home / ".cache"), XDG_CONFIG_HOME=str(home / ".config"),
                           XDG_RUNTIME_DIR=str(runtime), XDG_CURRENT_DESKTOP="labwc", QT_QPA_PLATFORM="wayland",
                           QT_QUICK_BACKEND="software", QT_FFMPEG_DECODING_HW_DEVICE_TYPES=",", WLR_BACKENDS="headless",
                           WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman", HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF="1",
                           HAKUSPACE_SOAK_SOURCE=str(args.source), HAKUSPACE_SOAK_PROFILE=args.profile,
                           HAKUSPACE_SOAK_SCRIPT=str(Path(__file__).resolve()), HAKUSPACE_SOAK_OUTPUT=str(args.output),
                           HAKUSPACE_SOAK_SECONDS=str(args.seconds), HAKUSPACE_SOAK_CYCLES=str(args.cycles), HAKUSPACE_SOAK_IMAGE=str(home / "still.png"))
        start = ["python3", str(Path(__file__).resolve()), "_baseline", str(args.source), str(args.output), str(args.seconds)] \
            if args.profile == "mpvpaper" else ["quickshell", "-p", str(shell / "shell.qml")]
        if args.cycles:
            start = ["python3", str(Path(__file__).resolve()), "_cycles", str(shell / "shell.qml"), str(args.output), str(args.seconds), str(args.cycles)]
        # A fixed 1080p output makes Screen profile comparisons reproducible.
        launcher = work / "start.sh"
        launcher.write_text("#!/usr/bin/env bash\nset -euo pipefail\nwlr-randr --output HEADLESS-1 --custom-mode 1920x1080@60Hz\nexec " + shlex.join(start) + "\n")
        with args.output.with_suffix(".log").open("w") as log:
            process = subprocess.Popen(["dbus-run-session", "--", "labwc", "-C", str(compositor), "-S", shlex.join(["bash", str(launcher)])],
                                       env=environment, stdout=log, stderr=log, start_new_session=True)
            try:
                code = process.wait(timeout=(args.seconds + 6) * (args.cycles + 3) + 330)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=10)
        if code or not args.output.exists() or not json.loads(args.output.read_text()).get("complete"):
            raise RuntimeError("benchmark failed; see " + str(args.output.with_suffix(".log")))
        data = json.loads(args.output.read_text())
        data.update(profile=args.profile, source=str(args.source), softwareDecode=True, renderer="software", outputPixels=[1920, 1080])
        current = home / ".local/state/hakuspace/state/[desktop].wallpaper.current.json"
        if current.exists():
            record = json.loads(current.read_text())
            data.update(sourceMetadata=record.get("metadata"), render=record.get("render"))
        args.output.write_text(json.dumps(data, indent=2) + "\n")
        assert data["complete"] and len(data["samples"]) >= 2
        print(json.dumps(data))


if __name__ == "__main__":
    main()
