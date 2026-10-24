#!/usr/bin/env python3
"""Sample a live Hikai process or exercise a disposable two-output Hikai session."""
import argparse
import json
import os
from pathlib import Path
import shutil
import shlex
import signal
import subprocess
import tempfile
import time

# Resolve production sources without placing benchmark state in the checkout.
ROOT = Path(__file__).resolve().parents[2]
SURFACES = ("navigation", "dashboard", "sidebar", "clipboard", "settings", "hakumenu",
            "actionMenu", "notifications", "wallpaper", "tempNote")


def sample(pid):
    """Read memory, CPU and resource counts without double-counting DRM clients."""
    process = Path("/proc") / str(pid)
    status = dict(line.split(":", 1) for line in (process / "status").read_text().splitlines() if ":" in line)
    stat = (process / "stat").read_text().rsplit(")", 1)[1].split()
    pss = None
    try:
        for line in (process / "smaps_rollup").read_text().splitlines():
            if line.startswith("Pss:"):
                pss = int(line.split()[1])
    except (PermissionError, FileNotFoundError):
        pass
    clients = {}
    for path in (process / "fdinfo").iterdir():
        try:
            fields = dict(line.split(":", 1) for line in path.read_text().splitlines() if ":" in line)
            resident = [int(value.split()[0]) for key, value in fields.items() if key.startswith("drm-resident-")]
            if resident:
                client = (fields.get("drm-pdev"), fields.get("drm-client-id", path.name))
                clients[client] = sum(resident)
        except (OSError, ValueError):
            continue
    children = set()
    for task in (process / "task").iterdir():
        try:
            children.update((task / "children").read_text().split())
        except FileNotFoundError:
            continue
    return {"rssKiB": int(status["VmRSS"].split()[0]), "pssKiB": pss,
            "gpuResidentKiB": sum(clients.values()) if clients else None,
            "cpuSeconds": (int(stat[11]) + int(stat[12])) / os.sysconf("SC_CLK_TCK"),
            "fdCount": len(list((process / "fd").iterdir())),
            "threadCount": int(status["Threads"]), "childCount": len(children)}


def plateau(samples, field):
    """Report a least-squares slope after warm-up, without a machine-specific RSS gate."""
    values = [(row["elapsedSec"], row[field]) for row in samples
              if row.get("phase") == "idle" and row.get(field) is not None]
    if len(values) < 2:
        return None
    mean_x = sum(x for x, _ in values) / len(values)
    mean_y = sum(y for _, y in values) / len(values)
    denominator = sum((x - mean_x) ** 2 for x, _ in values)
    return round(sum((x - mean_x) * (y - mean_y) for x, y in values) / denominator * 60, 3) if denominator else None


def measure(pid, args, ipc=None):
    """Persist incremental samples and stress checkpoints so interrupted runs remain usable."""
    start = time.monotonic()
    report = {"pid": pid, "renderer": "software" if args.software else "default",
              "outputs": args.outputs if ipc else None, "warmupSec": args.warmup,
              "idleSec": args.seconds, "cycles": args.cycles if ipc else 0,
              "notifications": args.notifications if ipc else 0, "samples": [], "complete": False}

    # Flush every checkpoint to preserve evidence if the target exits during stress.
    def record(phase, **extra):
        value = sample(pid) | {"elapsedSec": round(time.monotonic() - start, 3), "phase": phase} | extra
        report["samples"].append(value)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
        return value

    record("startup")
    time.sleep(args.warmup)
    deadline = time.monotonic() + args.seconds
    while True:
        record("idle")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(args.interval, remaining))
    if ipc and args.cycles:
        for surface in args.surfaces:
            for batch in (1, 2):
                record("before", surface=surface, batch=batch)
                for cycle in range(1, args.cycles + 1):
                    ipc("open", surface, str((cycle - 1) % args.outputs))
                    time.sleep(args.dwell)
                    ipc("close", surface)
                    time.sleep(args.dwell)
                    if cycle in (10, 50, args.cycles):
                        record("cycles", surface=surface, batch=batch, cycle=cycle)
                time.sleep(args.settle)
                state = json.loads(ipc("status"))
                if state["loaded"] is not None and state["loaded"] != 0:
                    raise RuntimeError("closed surfaces remain loaded: " + json.dumps(state))
                record("settled", surface=surface, batch=batch, lifecycle=state)
    if ipc and args.notifications:
        for index in range(args.notifications):
            subprocess.run(["notify-send", "-t", "0", "Memory churn " + str(index)], check=True, timeout=10)
        record("notification-burst", notifications=args.notifications, lifecycle=json.loads(ipc("status")))
        ipc("expireAll")
        time.sleep(args.settle)
        state = json.loads(ipc("status"))
        if state["records"] > 100 or state["handles"] or state["deadlines"] or state["loaded"]:
            raise RuntimeError("notification churn did not settle: " + json.dumps(state))
        record("notification-settled", lifecycle=state)
    report.update(complete=True, rssSlopeKiBPerMin=plateau(report["samples"], "rssKiB"),
                  pssSlopeKiBPerMin=plateau(report["samples"], "pssKiB"))
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    return report


def session(args):
    """Launch and stop only the private Quickshell child in the disposable compositor."""
    shell = Path(os.environ["HAKUSPACE_MEMORY_SHELL"])
    with args.output.with_suffix(".qs.log").open("w") as log:
        process = subprocess.Popen(["quickshell", "-p", str(shell)], stdout=log, stderr=log)
        try:
            # Select by PID so the benchmark can never drive the user's running shell.
            def ipc(method, *values):
                return subprocess.check_output(["quickshell", "ipc", "--pid", str(process.pid), "call",
                                                "memoryProbe", method, *values], text=True, stderr=subprocess.DEVNULL, timeout=10).strip()
            for _ in range(200):
                if process.poll() is not None:
                    raise RuntimeError("Quickshell exited; see " + str(args.output.with_suffix(".qs.log")))
                try:
                    ipc("status")
                    break
                except subprocess.CalledProcessError:
                    time.sleep(0.1)
            else:
                raise RuntimeError("Quickshell IPC did not initialize")
            measure(process.pid, args, ipc)
            log.flush()
            errors = ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration")
            if any(error in args.output.with_suffix(".qs.log").read_text() for error in errors):
                raise RuntimeError("QML runtime error during soak; see " + str(args.output.with_suffix(".qs.log")))
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def headless(args):
    """Copy the real shell and backends into a private HOME and D-Bus session."""
    with tempfile.TemporaryDirectory(prefix="hikai-memory-") as temporary:
        work = Path(temporary)
        shell = work / "src/home/.config/quickshell/hakuspace"
        shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace", shell)
        for name in ("backend", "lib", "theme", "state"):
            shutil.copytree(ROOT / "src/core" / name, work / "src/core" / name)
        bin_dir = work / "src/home/.local/bin"
        bin_dir.mkdir(parents=True)
        for helper in (work / "src/core/backend").rglob("*"):
            if helper.is_file() and helper.suffix in (".sh", ".py"):
                destination = bin_dir / helper.name
                if not destination.exists():
                    destination.symlink_to(helper)
        shutil.copy(ROOT / "tools/profiling/harness/memory.qml", shell / "MemoryProbe.qml")
        production = (shell / "shell.qml").read_text()
        hosts = "ephemeralHosts.instances" if "id: ephemeralHosts" in production else "[]"
        (shell / "shell.qml").write_text(production.rsplit("}", 1)[0]
            + "\n    MemoryProbe { hosts: " + hosts + "; lazy: " + str(hosts != "[]").lower() + " }\n}\n")
        home = work / "home"
        shutil.copytree(ROOT / "src/home/hakucfg", home / "hakucfg")
        (home / "hakucfg/setting.sh").write_text("ACCENT_COLOR_BASED_ON_WALLPAPER=false\n")
        runtime = work / "runtime"
        runtime.mkdir(mode=0o700)
        compositor = work / "labwc"
        compositor.mkdir()
        (compositor / "rc.xml").write_text("<labwc_config/>\n")
        environment = {key: value for key, value in os.environ.items() if key not in (
            "DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6",
            "HYPRLAND_INSTANCE_SIGNATURE", "NIRI_SOCKET", "MANGO_INSTANCE_SIGNATURE") and not key.startswith("HAKUSPACE_")}
        environment.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"), XDG_CACHE_HOME=str(home / ".cache"),
                           XDG_RUNTIME_DIR=str(runtime), XDG_CURRENT_DESKTOP="labwc", QT_QPA_PLATFORM="wayland",
                           WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS=str(args.outputs), WLR_RENDERER="pixman",
                           HAKUSPACE_MEMORY_SHELL=str(shell / "shell.qml"))
        if args.software:
            environment["QT_QUICK_BACKEND"] = "software"
        else:
            environment.pop("QT_QUICK_BACKEND", None)
        # Labwc starts the sampler in its own Wayland environment and exits with it.
        command = ["python3", str(Path(__file__).resolve()), *os.sys.argv[1:], "--session"]
        with args.output.with_suffix(".log").open("w") as log:
            process = subprocess.Popen(["dbus-run-session", "--", "labwc", "-C", str(compositor), "-S", shlex.join(command)],
                                       env=environment, stdout=log, stderr=log, start_new_session=True)
            try:
                code = process.wait()
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=10)
        if code or not args.output.exists() or not json.loads(args.output.read_text()).get("complete"):
            raise RuntimeError("benchmark failed; see " + str(args.output.with_suffix(".log")))


def main():
    """Validate bounded benchmark options and select live sampling or isolated stress."""
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--pid", type=int)
    target.add_argument("--headless", action="store_true")
    parser.add_argument("--session", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seconds", type=float, default=900)
    parser.add_argument("--warmup", type=float, default=120)
    parser.add_argument("--interval", type=float, default=5)
    parser.add_argument("--cycles", type=int, default=100)
    parser.add_argument("--notifications", type=int, default=0)
    parser.add_argument("--dwell", type=float, default=0.7)
    parser.add_argument("--settle", type=float, default=30)
    parser.add_argument("--outputs", type=int, choices=(1, 2), default=2)
    parser.add_argument("--surfaces", nargs="+", choices=SURFACES, default=list(SURFACES))
    parser.add_argument("--software", action="store_true", help="Explicit debug profile; GPU residency is unavailable")
    args = parser.parse_args()
    if args.seconds < 0 or args.warmup < 0 or args.interval <= 0 or args.cycles < 0 or args.dwell < 0 or args.settle < 0 or args.notifications < 0:
        parser.error("durations and cycles must be nonnegative; interval must be positive")
    args.output = args.output.resolve()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.session:
        session(args)
    elif args.headless:
        headless(args)
    else:
        measure(args.pid, args)
    print(str(args.output))


if __name__ == "__main__":
    main()
