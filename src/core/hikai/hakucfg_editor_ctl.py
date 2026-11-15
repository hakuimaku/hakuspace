#!/usr/bin/env python3
"""Safely edit UTF-8 files below hakucfg/wm and hakucfg/config."""
import fcntl
import hashlib
import json
import os
import re
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

# shortcut: 96 KiB fits Linux's per-environment-string limit, use stdin transport for larger files.
MAX_BYTES = 96 * 1024
DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC


def fail(message):
    raise ValueError(message)


def root_path():
    return Path(os.environ.get("HAKUSPACE_HAKUCFG_ROOT") or Path.home() / "hakucfg")


def parts_for(file_id):
    if not isinstance(file_id, str):
        fail("invalid file id")
    parts = file_id.split("/")
    if len(parts) < 2 or parts[0] not in ("wm", "config") or any(part in ("", ".", "..") or "\\" in part or "\0" in part for part in parts):
        fail("invalid file id")
    return parts


def open_root():
    return os.open(root_path(), DIR_FLAGS)


def open_parent(parts):
    """Walk approved directories by fd without following symlinks."""
    fd = open_root()
    try:
        for part in parts[:-1]:
            child = os.open(part, DIR_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def read_file(file_id):
    parts = parts_for(file_id)
    parent = open_parent(parts)
    try:
        fd = os.open(parts[-1], FILE_FLAGS, dir_fd=parent)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode):
                fail("not a regular file")
            if info.st_size > MAX_BYTES:
                fail("file exceeds 96 KiB limit")
            with os.fdopen(fd, "rb", closefd=False) as stream:
                raw = stream.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                fail("file exceeds 96 KiB limit")
            if b"\0" in raw:
                fail("binary file contains NUL")
            content = raw.decode("utf-8")
            return {"ok": True, "id": file_id, "path": str(root_path().joinpath(*parts)),
                    "content": content, "revision": "sha256:" + hashlib.sha256(raw).hexdigest(),
                    "size": len(raw), "mode": stat.S_IMODE(info.st_mode)}
        finally:
            os.close(fd)
    finally:
        os.close(parent)


def file_list():
    """List readable UTF-8 files under wm/ and config/, skipping unsafe entries."""
    files = []
    skipped = 0

    def walk(fd, names):
        nonlocal skipped
        with os.scandir(fd) as entries:
            for entry in entries:
                try:
                    info = entry.stat(follow_symlinks=False)
                    if stat.S_ISDIR(info.st_mode):
                        child = os.open(entry.name, DIR_FLAGS, dir_fd=fd)
                        try:
                            walk(child, names + [entry.name])
                        finally:
                            os.close(child)
                    elif stat.S_ISREG(info.st_mode):
                        file_id = "/".join(names + [entry.name])
                        try:
                            data = read_file(file_id)
                        except (OSError, UnicodeError, ValueError):
                            skipped += 1
                            continue
                        files.append({"id": file_id, "group": names[0], "name": entry.name,
                                      "relativeDir": "/".join(names), "size": data["size"]})
                    else:
                        skipped += 1
                except OSError:
                    skipped += 1

    base = open_root()
    try:
        for group in ("wm", "config"):
            try:
                fd = os.open(group, DIR_FLAGS, dir_fd=base)
            except FileNotFoundError:
                continue
            try:
                walk(fd, [group])
            finally:
                os.close(fd)
    finally:
        os.close(base)
    files.sort(key=lambda item: (0 if item["group"] == "wm" else 1, item["id"]))
    return {"ok": True, "root": str(root_path()), "files": files, "skippedCount": skipped}


def write_file(file_id, content=None, expected=None):
    """Replace the selected file only while its revision matches the open draft."""
    parts = parts_for(file_id)
    expected = expected if expected is not None else os.environ.get("HAKUSPACE_CONFIG_EXPECTED_REVISION", "")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", expected):
        fail("invalid expected revision")
    content = content if content is not None else os.environ.get("HAKUSPACE_CONFIG_TEXT")
    if content is None or "\0" in content:
        fail("invalid text payload")
    raw = content.encode("utf-8")
    if len(raw) > MAX_BYTES:
        fail("draft exceeds 96 KiB limit")
    parent = open_parent(parts)
    temp_name = None
    try:
        current = read_file(file_id)
        if current["revision"] != expected:
            fail("conflict: file changed on disk")
        temp_name = ".hakucfg-editor-" + secrets.token_hex(12)
        fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=parent)
        try:
            os.fchmod(fd, current["mode"])
            with os.fdopen(fd, "wb", closefd=False) as stream:
                stream.write(raw)
                stream.flush()
            os.fsync(fd)
        finally:
            os.close(fd)
        # Recheck the live target before replacing it; the directory fd stays inside the approved root.
        if read_file(file_id)["revision"] != expected:
            fail("conflict: file changed on disk")
        os.replace(temp_name, parts[-1], src_dir_fd=parent, dst_dir_fd=parent)
        temp_name = None
        return {"ok": True, "id": file_id, "path": str(root_path().joinpath(*parts)),
                "content": content, "revision": "sha256:" + hashlib.sha256(raw).hexdigest(),
                "size": len(raw)}
    finally:
        if temp_name is not None:
            os.unlink(temp_name, dir_fd=parent)
        os.close(parent)


def backup_directory():
    """Keep bounded last-working copies in private state, outside user config."""
    directory = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "hakuspace/settings-backups"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(directory, DIR_FLAGS)
    return fd


def backup_name(file_id):
    """Separate identical relative paths belonging to different config roots."""
    parts_for(file_id)
    return hashlib.sha256((str(root_path().absolute()) + "/" + file_id).encode()).hexdigest()


def save_backup(fd, name, current):
    """Atomically replace one private backup without following a leaf symlink."""
    temp = ".backup-" + secrets.token_hex(12)
    handle = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump({"content": current["content"], "revision": current["revision"]}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, name + ".json", src_dir_fd=fd, dst_dir_fd=fd)
    finally:
        try:
            os.unlink(temp, dir_fd=fd)
        except FileNotFoundError:
            pass


def validate_candidate(file_id, content):
    """Use a standalone validator when available; never execute config as code."""
    current = read_file(file_id)
    if not isinstance(content, str) or "\0" in content or len(content.encode()) > MAX_BYTES:
        fail("invalid text payload")
    if file_id != "wm/niri-custom.kdl" or not shutil.which("niri"):
        return {"validatorUnavailable": True, "validationMessage": "Standalone reload validation unavailable; save uses backup and guarded reload"}
    # A sibling candidate preserves relative include resolution and is always removed.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix=".hakucfg-validate-", suffix=".kdl", dir=Path(current["path"]).parent) as candidate:
        candidate.write(content)
        candidate.flush()
        result = subprocess.run(["niri", "validate", "-c", candidate.name], capture_output=True, text=True, timeout=15)
    if result.returncode:
        diagnostic = (result.stderr or result.stdout).strip()
        if any(word in diagnostic.lower() for word in ("unrecognized subcommand", "unexpected argument", "unknown subcommand")):
            return {"validatorUnavailable": True, "validationMessage": "Installed Niri does not support standalone validation"}
        fail("validation failed: " + diagnostic[:4096])
    return {"validatorUnavailable": False, "validationMessage": "Validation passed"}


def reload_file(file_id):
    """Reload only the active compositor; reject unrelated documents explicitly."""
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
    wm = {"wm/niri-custom.kdl": "niri", "wm/hyprland-custom.lua": "hyprland", "wm/mango-custom.conf": "mango"}.get(file_id)
    if not wm or wm not in desktop.split(":"):
        fail("Save & Reload is available only for the active compositor's custom config; use Save only")
    command = {"niri": ["niri", "msg", "action", "load-config-file"], "hyprland": ["hyprctl", "reload"], "mango": ["mmsg", "-d", "reload_config"]}[wm]
    result = subprocess.run(command, capture_output=True, text=True, timeout=15)
    if result.returncode:
        fail("reload failed: " + (result.stderr or result.stdout).strip()[:4096])
    if wm == "hyprland":
        errors = subprocess.run(["hyprctl", "configerrors"], capture_output=True, text=True, timeout=15)
        if errors.returncode or errors.stdout.strip():
            fail("reload failed: " + (errors.stdout or errors.stderr).strip()[:4096])


def save_reload(file_id, restore=False):
    """Serialize editor transactions, preserve revisions and roll back failed reloads."""
    fd = backup_directory()
    name = backup_name(file_id)
    lock = os.open(name + ".lock", os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=fd)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = read_file(file_id)
        if current["revision"] != os.environ.get("HAKUSPACE_CONFIG_EXPECTED_REVISION"):
            fail("conflict: file changed on disk")
        if restore:
            backup = os.open(name + ".json", FILE_FLAGS, dir_fd=fd)
            with os.fdopen(backup, "r", encoding="utf-8") as stream:
                data = json.loads(stream.read(MAX_BYTES * 6 + 1024))
            content = data["content"]
            if "sha256:" + hashlib.sha256(content.encode()).hexdigest() != data["revision"]:
                fail("invalid backup revision")
        else:
            content = os.environ.get("HAKUSPACE_CONFIG_TEXT")
        validation = validate_candidate(file_id, content)
        # Check reload support before committing bytes or replacing the last working backup.
        desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":")
        wm = {"wm/niri-custom.kdl": "niri", "wm/hyprland-custom.lua": "hyprland", "wm/mango-custom.conf": "mango"}.get(file_id)
        if not wm or wm not in desktop:
            fail("Save & Reload is available only for the active compositor's custom config; use Save only")
        if not restore:
            save_backup(fd, name, current)
        saved = write_file(file_id, content, current["revision"])
        try:
            reload_file(file_id)
        except (OSError, ValueError, subprocess.TimeoutExpired) as error:
            try:
                write_file(file_id, current["content"], saved["revision"])
            except (OSError, ValueError) as rollback:
                fail(str(error) + "; rollback failed: " + str(rollback) + "; backup retained")
            try:
                reload_file(file_id)
            except (OSError, ValueError, subprocess.TimeoutExpired) as rollback:
                fail(str(error) + "; previous file restored; previous reload failed: " + str(rollback))
            fail(str(error) + "; previous file restored and reloaded")
        return dict(saved, **validation, backupAvailable=True)
    finally:
        os.close(lock)
        os.close(fd)


def open_vscode(file_id):
    data = read_file(file_id)
    executable = os.environ.get("HAKUSPACE_CODE_BIN") or shutil.which("code")
    if not executable:
        fail("VS Code executable `code` was not found")
    subprocess.Popen([executable, "--reuse-window", data["path"]],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, close_fds=True, start_new_session=True)
    return {"ok": True, "id": file_id, "path": data["path"]}


def check():
    base = open_root()
    try:
        for group in ("wm", "config"):
            try:
                fd = os.open(group, DIR_FLAGS, dir_fd=base)
            except FileNotFoundError:
                continue
            else:
                os.close(fd)
    finally:
        os.close(base)
    return {"ok": True, "root": str(root_path())}


def main(argv):
    if len(argv) == 1 and argv[0] == "list":
        return file_list()
    if len(argv) == 1 and argv[0] == "check":
        return check()
    if len(argv) == 2 and argv[0] == "read":
        return read_file(argv[1])
    if len(argv) == 2 and argv[0] == "write":
        return write_file(argv[1])
    if len(argv) == 2 and argv[0] == "validate":
        return dict(ok=True, **validate_candidate(argv[1], os.environ.get("HAKUSPACE_CONFIG_TEXT")))
    if len(argv) == 2 and argv[0] in ("save-reload", "restore-backup"):
        return save_reload(argv[1], restore=argv[0] == "restore-backup")
    if len(argv) == 2 and argv[0] == "open-vscode":
        return open_vscode(argv[1])
    fail("usage: hakucfg_editor_ctl.py list|check|read|write|open-vscode [file-id]")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (OSError, UnicodeError, ValueError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
