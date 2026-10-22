#!/usr/bin/env python3
"""Split legacy chrome state before Quickshell starts watching its files."""
import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

# Support repository modules and the flattened installed bin directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
from haku_state import state_path

from hikai_settings_ctl import open_parent, read_file, replace_file


def read_text(parent_fd, name):
    """Read an optional regular user-owned entry without following links."""
    try:
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent_fd)
    except FileNotFoundError:
        return None
    with os.fdopen(fd) as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise ValueError("chrome state must be a regular file owned by the current user")
        return stream.read()


def write_state(parent_fd, name, enabled):
    """Atomically publish one watched boolean after checking the target entry."""
    read_text(parent_fd, name)
    fd, path = tempfile.mkstemp(prefix=".chrome-state-", dir=f"/proc/self/fd/{parent_fd}")
    temporary = Path(path).name
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write("1\n" if enabled else "0\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=parent_fd)
        except FileNotFoundError:
            pass


def migrate():
    """Journal target states so interrupted upgrades resume without reinterpretation."""
    journal_path = state_path("migration.hikai-chrome-v6.json")
    settings_path = Path(os.path.abspath(os.environ.get("HAKUSPACE_HIKAI_SETTINGS_FILE")
                                        or Path.home() / "hakucfg/hikai/hikai-shell.json"))
    state_fd = open_parent(journal_path, True)
    try:
        fcntl.flock(state_fd, fcntl.LOCK_EX)
        saved = read_text(state_fd, journal_path.name)
        journal = json.loads(saved) if saved is not None else None
        if journal is not None:
            if (type(journal) is not dict or set(journal) != {"complete", "taskbar", "dockbar"}
                    or any(type(value) is not bool for value in journal.values())):
                raise ValueError("invalid chrome migration journal")
            if journal["complete"]:
                return
        settings_fd = open_parent(settings_path, True)
        try:
            raw = read_text(settings_fd, settings_path.name)
            document = json.loads(raw) if raw is not None else {}
            values, mode, _ = read_file(settings_fd, settings_path.name)
            if journal is None:
                taskbar = (read_text(state_fd, state_path("desktop.taskbar.requested").name) or "").strip() == "1"
                dockbar_text = read_text(state_fd, state_path("desktop.dockbar.requested").name)
                if document.get("version") == 6:
                    dockbar = (dockbar_text or "").strip() == "1"
                else:
                    full = document.get("dock", {}).get("style", "dock") == "bar"
                    dockbar = taskbar and not full
                    taskbar = taskbar and full
                journal = {"complete": False, "taskbar": taskbar, "dockbar": dockbar}
                replace_file(state_fd, journal_path.name, journal, 0o600)
            replace_file(settings_fd, settings_path.name, values, mode)
            write_state(state_fd, state_path("desktop.taskbar.requested").name, journal["taskbar"])
            write_state(state_fd, state_path("desktop.dockbar.requested").name, journal["dockbar"])
            replace_file(state_fd, journal_path.name, dict(journal, complete=True), 0o600)
        finally:
            os.close(settings_fd)
    finally:
        os.close(state_fd)


if __name__ == "__main__":
    try:
        if sys.argv[1:] != ["migrate"]:
            raise ValueError("usage: hikai_chrome_state_ctl.py migrate")
        migrate()
    except (OSError, ValueError, UnicodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
