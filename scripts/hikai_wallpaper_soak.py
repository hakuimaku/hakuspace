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
ROOT = Path(__file__).resolve().parents[1]


def sample(pid):
    """Read process memory, cumulative CPU time and optional DRM resident memory."""
    process = Path("/proc") / str(pid)
    status = dict(line.split(":", 1) for line in (process / "status").read_text().splitlines() if ":" in line)
    stat = (process / "stat").read_text().rsplit(")", 1)[1].split()
    pss = None
    try:
        for line in (process / "smaps_rollup").read_text().splitlines():
            if line.startswith("Pss:"):
                pss = int(line.split()[1])
    except PermissionError:
        pass
    gpu = []
    for path in (process / "fdinfo").iterdir():
        try:
            gpu.extend(int(line.split()[1]) for line in path.read_text().splitlines() if line.startswith("drm-resident-"))
        except (OSError, ValueError):
            continue
    return {"rssKiB": int(status["VmRSS"].split()[0]), "pssKiB": pss,
            "cpuSeconds": (int(stat[11]) + int(stat[12])) / os.sysconf("SC_CLK_TCK"),
            "gpuResidentKiB": sum(gpu) if gpu else None}


def measure(pid, output, seconds):
    """Record initial, five-, fifteen-, thirty- and sixty-minute samples plus the endpoint."""
    start = time.monotonic()
    samples = []
    for target in sorted({0, seconds, *(minute * 60 for minute in (5, 15, 30, 60) if minute * 60 < seconds)}):
        while time.monotonic() - start < target:
            time.sleep(max(0, min(1, target - (time.monotonic() - start))))
        value = sample(pid) | {"elapsedSec": round(time.monotonic() - start, 2)}
        if samples:
            value["cpuPercent"] = round((value["cpuSeconds"] - samples[-1]["cpuSeconds"]) * 100
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
    args = parser.parse_args()
    if not args.source.is_file() or not 1 <= args.seconds <= 86400:
        parser.error("source must exist and duration must be 1..86400 seconds")
    args.source = args.source.resolve()
    args.output = args.output.resolve()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hikai-soak-") as temporary:
        work = Path(temporary)
        shell = work / "src/home/.config/quickshell/hakuspace"
        shell.mkdir(parents=True)
        for name in ("services", "components"):
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace" / name, shell / name)
        shutil.copy(ROOT / "scripts/hikai_wallpaper_soak_harness.qml", shell / "shell.qml")
        for name in ("backend", "lib", "theme"):
            shutil.copytree(ROOT / "src/core" / name, work / "src/core" / name)
        home = work / "home"
        (home / "hakucfg").mkdir(parents=True)
        (home / "hakucfg/setting.sh").write_text("ACCENT_COLOR_BASED_ON_WALLPAPER=false\n")
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
                           HAKUSPACE_SOAK_SECONDS=str(args.seconds))
        start = ["python3", str(Path(__file__).resolve()), "_baseline", str(args.source), str(args.output), str(args.seconds)] \
            if args.profile == "mpvpaper" else ["quickshell", "-p", str(shell / "shell.qml")]
        # A fixed 1080p output makes Screen profile comparisons reproducible.
        launcher = work / "start.sh"
        launcher.write_text("#!/usr/bin/env bash\nset -euo pipefail\nwlr-randr --output HEADLESS-1 --custom-mode 1920x1080@60Hz\nexec " + shlex.join(start) + "\n")
        with args.output.with_suffix(".log").open("w") as log:
            process = subprocess.Popen(["dbus-run-session", "--", "labwc", "-C", str(compositor), "-S", shlex.join(["bash", str(launcher)])],
                                       env=environment, stdout=log, stderr=log, start_new_session=True)
            try:
                code = process.wait(timeout=args.seconds + 330)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=10)
        if code or not args.output.exists():
            raise RuntimeError("benchmark failed; see " + str(args.output.with_suffix(".log")))
        data = json.loads(args.output.read_text())
        data.update(profile=args.profile, source=str(args.source), softwareDecode=True, outputPixels=[1920, 1080])
        current = home / ".local/state/hakuspace/state/[desktop].wallpaper.current.json"
        if current.exists():
            record = json.loads(current.read_text())
            data.update(sourceMetadata=record.get("metadata"), render=record.get("render"))
        args.output.write_text(json.dumps(data, indent=2) + "\n")
        assert data["complete"] and len(data["samples"]) >= 2
        print(json.dumps(data))


if __name__ == "__main__":
    main()
