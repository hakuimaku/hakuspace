#!/usr/bin/env python3
"""Read local HakuSpace repository and session information for Settings Info."""
import json
import os
import platform
import shlex
import shutil
import socket
import subprocess
import sys
from pathlib import Path


def command(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=3,
                                env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def git(repo, *args):
    return command(["git", "-C", str(repo), *args])


def repo_candidates():
    """Use local source/deployment paths; an explicit override stays exclusive."""
    override = os.environ.get("HAKUSPACE_REPO_ROOT")
    if override is not None:
        return [Path(override)] if override else []
    candidates = [Path(__file__).resolve()]
    shell = Path.home() / ".config/quickshell/hakuspace/shell.qml"
    if shell.exists():
        candidates.append(shell.resolve())
    deployed = Path.home() / ".local/bin/hakucfg_editor_ctl.py"
    if deployed.exists():
        candidates.append(deployed.resolve())
    return candidates


def detect_repo():
    """Accept only candidates proven to be Git worktrees with a valid HEAD."""
    unknown = {"detected": False, "path": "", "version": "Not detected", "exactTag": "",
               "branch": "", "commit": "", "commitFull": "", "commitDate": "", "dirty": False}
    for candidate in repo_candidates():
        path = candidate if candidate.is_dir() else candidate.parent
        top = git(path, "rev-parse", "--show-toplevel")
        if not top:
            continue
        repo = Path(top).resolve()
        full = git(repo, "rev-parse", "HEAD")
        if not full:
            continue
        short = git(repo, "rev-parse", "--short=8", "HEAD") or full[:8]
        tag = git(repo, "describe", "--tags", "--exact-match", "HEAD")
        dirty = bool(git(repo, "status", "--porcelain", "--untracked-files=normal"))
        described = git(repo, "describe", "--tags", "--always", "--abbrev=8", "--dirty")
        version = described or ((tag or short) + ("-dirty" if dirty else ""))
        return {"detected": True, "path": str(repo), "version": version,
                "exactTag": tag, "branch": git(repo, "branch", "--show-current") or "detached",
                "commit": short, "commitFull": full,
                "commitDate": git(repo, "log", "-1", "--format=%cs"), "dirty": dirty}
    return unknown


def os_release():
    """Parse release metadata as data without executing shell assignments."""
    source = Path(os.environ.get("HAKUSPACE_OS_RELEASE_FILE") or "/etc/os-release")
    values = {}
    try:
        lines = source.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return values
    for line in lines:
        if "=" not in line or line.lstrip().startswith("#"):
            continue
        key, raw = line.split("=", 1)
        if key not in ("PRETTY_NAME", "ID", "VERSION_ID"):
            continue
        try:
            parsed = shlex.split(raw, comments=False)
        except ValueError:
            continue
        if len(parsed) == 1:
            values[key] = parsed[0]
    return values


def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except (OSError, ValueError):
        return ""


def read_number(path):
    value = read_text(path)
    return int(value) if value.isdecimal() else None


def hardware_info():
    """Collect static, non-identifying hardware descriptors from optional Linux nodes."""
    proc = Path(os.environ.get("HAKUSPACE_PROC_ROOT") or "/proc")
    sys_root = Path(os.environ.get("HAKUSPACE_SYS_ROOT") or "/sys")
    dmi = sys_root / "class/dmi/id"
    device = {key: value for key, value in {
        "manufacturer": read_text(dmi / "sys_vendor"),
        "model": read_text(dmi / "product_name"),
        "version": read_text(dmi / "product_version")
    }.items() if value and value.lower() not in ("none", "not specified", "to be filled by o.e.m.")}

    processors = []
    for block in read_text(proc / "cpuinfo").split("\n\n"):
        fields = dict(line.split(":", 1) for line in block.splitlines() if ":" in line)
        if fields:
            processors.append({key.strip(): value.strip() for key, value in fields.items()})
    first = processors[0] if processors else {}
    cpu = {}
    model = first.get("model name") or first.get("Hardware") or first.get("Processor")
    vendor = first.get("vendor_id") or first.get("CPU implementer")
    if model:
        cpu["model"] = model
    if vendor:
        cpu["vendor"] = vendor
    threads = sum("processor" in item for item in processors)
    if not threads and "HAKUSPACE_PROC_ROOT" not in os.environ:
        threads = os.cpu_count() or 0
    if threads:
        cpu["threads"] = threads
    if processors and all("physical id" in item and "core id" in item for item in processors):
        cpu["physicalCores"] = len({(item["physical id"], item["core id"]) for item in processors})
    freq = read_number(sys_root / "devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
    if freq and freq > 0:
        cpu["maxFrequencyHz"] = freq * 1000

    memory = {}
    for line in read_text(proc / "meminfo").splitlines():
        if line.startswith("MemTotal:"):
            parts = line.split()
            if len(parts) >= 3 and parts[1].isdecimal() and parts[2] == "kB":
                memory["totalBytes"] = int(parts[1]) * 1024
            break

    vendor_names = {"0x1002": "AMD", "0x10de": "NVIDIA", "0x8086": "Intel"}
    gpus = []
    for card in sorted((sys_root / "class/drm").glob("card[0-9]*")):
        if not card.name[4:].isdecimal():
            continue
        pci = card / "device"
        vendor_id = read_text(pci / "vendor").lower()
        device_id = read_text(pci / "device").lower()
        if not vendor_id and not device_id:
            continue
        vendor_name = vendor_names.get(vendor_id, vendor_id)
        name = read_text(pci / "product_name")
        pci_address = pci.resolve().name
        if not name and shutil.which("lspci") and ":" in pci_address:
            line = command(["lspci", "-s", pci_address, "-mm"])
            try:
                fields = shlex.split(line)
                if len(fields) >= 4:
                    name = fields[3]
            except ValueError:
                pass
        gpu = {"name": name or (vendor_name + " GPU" if vendor_name else "GPU"),
               "vendor": vendor_name}
        try:
            gpu["driver"] = (pci / "driver").resolve(strict=True).name
        except (OSError, RuntimeError):
            driver_line = next((line for line in read_text(pci / "uevent").splitlines()
                                if line.startswith("DRIVER=")), "")
            if driver_line:
                gpu["driver"] = driver_line.partition("=")[2]
        vram = read_number(pci / "mem_info_vram_total")
        if vram is not None:
            gpu["vramBytes"] = vram
        gpus.append(gpu)

    storage = []
    for disk in sorted((sys_root / "block").glob("*")):
        if disk.name.startswith(("loop", "ram", "zram", "dm-", "md")):
            continue
        sectors = read_number(disk / "size")
        if not sectors:
            continue
        entry = {"name": disk.name, "capacityBytes": sectors * 512}
        model = read_text(disk / "device/model")
        if model:
            entry["model"] = model
        rotational = read_number(disk / "queue/rotational")
        if rotational in (0, 1):
            entry["rotational"] = bool(rotational)
        storage.append(entry)
    return {"device": device, "cpu": cpu, "memory": memory, "gpus": gpus, "storage": storage}


def read():
    release = os_release()
    quickshell = shutil.which("quickshell")
    return {"ok": True, "repo": detect_repo(), "system": {
        "hostname": socket.gethostname(),
        "shell": Path(os.environ.get("SHELL") or "").name,
        "sessionType": os.environ.get("XDG_SESSION_TYPE", ""),
        "desktop": os.environ.get("XDG_CURRENT_DESKTOP", ""),
        "distroPretty": release.get("PRETTY_NAME", ""),
        "distroId": release.get("ID", ""),
        "distroVersion": release.get("VERSION_ID", ""),
        "kernel": platform.release(), "arch": platform.machine(),
        "quickshellVersion": command([quickshell, "--version"]) if quickshell else ""},
        "hardware": hardware_info()}


if __name__ == "__main__":
    if sys.argv[1:] != ["read"]:
        print("usage: hakuspace_info_ctl.py read", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(read()))
