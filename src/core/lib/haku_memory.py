"""Read Linux process metrics without retaining process resources between samples."""
import os
from pathlib import Path


def fd_classes(process):
    """Classify descriptors without exposing filenames or socket endpoints."""
    counts = {key: 0 for key in ("shm", "socket", "pipe", "anon_inode", "dmabuf", "file", "other")}
    for path in (process / "fd").iterdir():
        try:
            target = path.readlink().as_posix()
        except OSError:
            continue
        kind = ("dmabuf" if "dmabuf" in target.lower() or "dma_buf" in target.lower()
                else "shm" if target.startswith("/dev/shm/") or target.startswith("/memfd:")
                else "socket" if target.startswith("socket:")
                else "pipe" if target.startswith("pipe:")
                else "anon_inode" if target.startswith("anon_inode:")
                else "file" if target.startswith("/") else "other")
        counts[kind] += 1
    return counts


def sample(pid, classify=False, gpu=True):
    """Read KiB counters and deduplicate optional DRM residency by client/device."""
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
    # DRM reads are optional: software/unsupported backends report null, never zero.
    clients = {}
    if gpu:
        for path in (process / "fdinfo").iterdir():
            try:
                fields = dict(line.split(":", 1) for line in path.read_text().splitlines() if ":" in line)
                resident = [int(value.split()[0]) for key, value in fields.items() if key.startswith("drm-resident-")]
                if resident and fields.get("drm-client-id"):
                    client = (fields.get("drm-pdev", ""), fields["drm-client-id"].strip())
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
            "threadCount": int(status["Threads"]), "childCount": len(children),
            **({"fdClasses": fd_classes(process)} if classify else {})}
