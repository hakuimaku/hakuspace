#!/usr/bin/env python3
"""Sample Hikai and reserve infrequent engine recycling in registered shell state."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

# Support both the source tree and the flattened deployment directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
from haku_memory import sample
from haku_state import state_path


def version_guard(text):
    """Accept stable, explicitly identified Quickshell releases from the running binary."""
    match = re.match(r"^Quickshell (\d+)\.(\d+)\.(\d+)(?:\s|$)", text.strip())
    version = tuple(map(int, match.groups())) if match else None
    eligible = version is not None and version >= (0, 3, 2)
    return {"version": ".".join(map(str, version)) if version else "unknown",
            "recycleEligible": eligible,
            "versionReason": "" if eligible else "auto recycle requires a verified stable Quickshell >= 0.3.2"}


def runtime_version(pid):
    """Query /proc/exe once so a different executable on PATH cannot enable recycling."""
    try:
        result = subprocess.run([f"/proc/{pid}/exe", "--version"], capture_output=True, text=True, timeout=3)
        return version_guard(result.stdout if result.returncode == 0 else "")
    except (OSError, subprocess.TimeoutExpired):
        return version_guard("")


def read_protection(path):
    """Reject damaged cooldown state instead of silently allowing a reload loop."""
    try:
        value = json.loads(path.read_text())
    except FileNotFoundError:
        return {"lastRecycleTimestamp": 0, "recycleCount": 0, "recentRecycles": []}
    if (not isinstance(value, dict) or type(value.get("lastRecycleTimestamp")) is not int
            or value["lastRecycleTimestamp"] < 0 or type(value.get("recycleCount")) is not int
            or value["recycleCount"] < 0 or not isinstance(value.get("recentRecycles"), list)
            or len(value["recentRecycles"]) > 24
            or any(type(stamp) is not int or stamp < 0 for stamp in value["recentRecycles"])):
        raise ValueError("invalid memory maintenance cooldown state")
    return value


def reserve(path, cooldown_ms, window_ms, limit, now=None):
    """Persist the attempt before reload; failures and interrupted attempts consume cooldown."""
    now = int(time.time() * 1000) if now is None else now
    path.parent.mkdir(parents=True, exist_ok=True)
    # Lock the directory so replacing the JSON cannot invalidate the lock inode.
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(directory, fcntl.LOCK_EX)
        value = read_protection(path)
        recent = [stamp for stamp in value["recentRecycles"] if now - stamp < window_ms]
        if (value["lastRecycleTimestamp"] and now - value["lastRecycleTimestamp"] < cooldown_ms) or len(recent) >= limit:
            raise ValueError("recycle cooldown or loop protection")
        value = {"lastRecycleTimestamp": now, "recycleCount": value["recycleCount"] + 1,
                 "recentRecycles": (recent + [now])[-24:]}
        descriptor, temporary = tempfile.mkstemp(prefix=".memory-", dir=path.parent)
        try:
            with os.fdopen(descriptor, "w") as stream:
                json.dump(value, stream)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
            os.fsync(directory)
        finally:
            Path(temporary).unlink(missing_ok=True)
        return value
    finally:
        os.close(directory)


def main():
    """Emit one finite JSON reply per sparse request; no resident sampling subprocess."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("sample", "reserve"))
    parser.add_argument("pid", type=int)
    parser.add_argument("--initialize", action="store_true")
    parser.add_argument("--classify", action="store_true")
    parser.add_argument("--gpu", action="store_true")
    parser.add_argument("--cooldown-ms", type=int, default=7200000)
    parser.add_argument("--window-ms", type=int, default=86400000)
    parser.add_argument("--limit", type=int, default=2)
    args = parser.parse_args()
    if args.pid <= 0 or args.cooldown_ms < 0 or args.window_ms <= 0 or not 1 <= args.limit <= 24:
        parser.error("invalid PID or recycle limits")
    try:
        path = state_path("shell.memory-maintenance.json")
        if args.action == "reserve":
            guard = runtime_version(args.pid)
            if not guard["recycleEligible"]:
                raise ValueError(guard["versionReason"])
            value = {"protection": reserve(path, args.cooldown_ms, args.window_ms, args.limit)}
        else:
            value = sample(args.pid, args.classify, args.gpu)
            if args.initialize:
                value.update(runtime_version(args.pid))
                try:
                    value["protection"] = read_protection(path)
                    value["protectionReady"] = True
                except (OSError, ValueError):
                    value["protectionReady"] = False
                    value["versionReason"] = "recycle disabled: unreadable cooldown state"
        print(json.dumps(value))
    except (OSError, ValueError, KeyError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
