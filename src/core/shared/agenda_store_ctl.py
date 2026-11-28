#!/usr/bin/env python3
"""Headless persistent storage controller for HakuSpace dashboard agenda/todo items."""

import datetime
import json
import math
import os
import re
import stat
import sys
import tempfile

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_TITLE_LENGTH = 300


def get_user_dir() -> str:
    override = os.environ.get("HAKUSPACE_USER_DIR")
    if override:
        return override
    xdg_data = os.environ.get("XDG_DATA_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "share"
    )
    return os.path.join(xdg_data, "hakuspace", "user")


def get_agenda_path() -> str:
    return os.path.join(get_user_dir(), "agenda.json")


def fail(message: str) -> int:
    sys.stderr.write(f"agenda_store_ctl.py: {message}\n")
    return 1


def ensure_user_dir(user_dir: str, create: bool) -> None:
    if os.path.islink(user_dir):
        raise ValueError(f"rejected symlink at user directory: {user_dir}")
    if os.path.exists(user_dir):
        st = os.lstat(user_dir)
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
            raise ValueError(f"user directory path is not a directory: {user_dir}")
        if st.st_uid != os.getuid():
            raise ValueError(
                f"user directory owner mismatch: expected {os.getuid()}, got {st.st_uid}"
            )
        os.chmod(user_dir, 0o700)
        return
    if not create:
        return
    os.makedirs(user_dir, mode=0o700, exist_ok=True)
    st = os.lstat(user_dir)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
        raise ValueError(f"user directory path is not a directory: {user_dir}")
    if st.st_uid != os.getuid():
        raise ValueError(
            f"user directory owner mismatch: expected {os.getuid()}, got {st.st_uid}"
        )
    os.chmod(user_dir, 0o700)


def check_agenda_file(agenda_path: str) -> bool:
    if os.path.islink(agenda_path):
        raise ValueError(f"rejected symlink at agenda file: {agenda_path}")
    if not os.path.exists(agenda_path):
        return False
    st = os.lstat(agenda_path)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
        raise ValueError(f"agenda path is not a regular file: {agenda_path}")
    if st.st_uid != os.getuid():
        raise ValueError(
            f"agenda file owner mismatch: expected {os.getuid()}, got {st.st_uid}"
        )
    return True


def validate_payload(data: object) -> dict:
    if not isinstance(data, dict):
        raise ValueError("agenda root must be a JSON object")
    schema = data.get("schema")
    if type(schema) is not int or schema != 1:
        raise ValueError("agenda schema must equal 1")
    raw_items = data.get("items")
    if not isinstance(raw_items, list):
        raise ValueError("agenda items must be an array")

    normalized_items = []
    for idx, item in enumerate(raw_items):
        if not isinstance(item, dict):
            raise ValueError(f"item[{idx}] must be an object")

        item_id = item.get("id")
        if not isinstance(item_id, str) or not item_id.strip():
            raise ValueError(f"item[{idx}].id must be a non-empty string")

        raw_title = item.get("title")
        if not isinstance(raw_title, str):
            raise ValueError(f"item[{idx}].title must be a string")
        title = raw_title.strip()
        if not title or len(title) > MAX_TITLE_LENGTH:
            raise ValueError(
                f"item[{idx}].title must be 1..{MAX_TITLE_LENGTH} non-whitespace characters"
            )

        date_str = item.get("date")
        if not isinstance(date_str, str):
            raise ValueError(f"item[{idx}].date must be a string")
        if date_str != "":
            if not DATE_RE.match(date_str):
                raise ValueError(f"item[{idx}].date must be empty or YYYY-MM-DD")
            try:
                datetime.date.fromisoformat(date_str)
            except ValueError as exc:
                raise ValueError(f"item[{idx}].date is invalid: {date_str}") from exc

        done = item.get("done")
        if not isinstance(done, bool):
            raise ValueError(f"item[{idx}].done must be a boolean")

        created_at = item.get("createdAt")
        if (
            not isinstance(created_at, (int, float))
            or isinstance(created_at, bool)
            or not math.isfinite(created_at)
        ):
            raise ValueError(f"item[{idx}].createdAt must be a finite number")

        normalized_items.append(
            {
                "id": item_id,
                "title": title,
                "date": date_str,
                "done": done,
                "createdAt": int(created_at),
            }
        )

    return {"schema": 1, "items": normalized_items}


def cmd_paths() -> int:
    sys.stdout.write(json.dumps({"agendaPath": get_agenda_path()}, ensure_ascii=False) + "\n")
    return 0


def cmd_read() -> int:
    user_dir = get_user_dir()
    agenda_path = get_agenda_path()
    try:
        ensure_user_dir(user_dir, create=False)
        exists = check_agenda_file(agenda_path)
    except (OSError, ValueError) as exc:
        return fail(str(exc))

    if not exists:
        sys.stdout.write('{"schema":1,"items":[]}\n')
        return 0

    try:
        with open(agenda_path, "r", encoding="utf-8") as handle:
            raw_text = handle.read()
        parsed = json.loads(raw_text)
        validated = validate_payload(parsed)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return fail(f"failed to read valid agenda JSON: {exc}")

    sys.stdout.write(json.dumps(validated, ensure_ascii=False) + "\n")
    return 0


def cmd_write() -> int:
    user_dir = get_user_dir()
    agenda_path = get_agenda_path()
    try:
        ensure_user_dir(user_dir, create=True)
        check_agenda_file(agenda_path)
    except (OSError, ValueError) as exc:
        return fail(str(exc))

    if "HAKUSPACE_AGENDA_JSON" in os.environ:
        raw_payload = os.environ["HAKUSPACE_AGENDA_JSON"]
    else:
        raw_payload = sys.stdin.read()

    try:
        parsed = json.loads(raw_payload)
        validated = validate_payload(parsed)
    except (json.JSONDecodeError, ValueError) as exc:
        return fail(f"invalid agenda payload: {exc}")

    encoded = json.dumps(validated, ensure_ascii=False, indent=2) + "\n"
    tmp_path = None
    try:
        fd, tmp_path = tempfile.mkstemp(prefix=".agenda_tmp.", dir=user_dir)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
        except Exception:
            raise
        os.chmod(tmp_path, 0o600)
        if os.path.islink(agenda_path):
            raise ValueError(f"rejected symlink at agenda file: {agenda_path}")
        os.replace(tmp_path, agenda_path)
        tmp_path = None
        os.chmod(agenda_path, 0o600)
    except (OSError, ValueError) as exc:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        return fail(f"failed to write agenda file: {exc}")

    return 0


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: agenda_store_ctl.py <paths|read|write>\n")
        return 1

    action = sys.argv[1]
    if action == "paths":
        return cmd_paths()
    if action == "read":
        return cmd_read()
    if action == "write":
        return cmd_write()

    sys.stderr.write("Usage: agenda_store_ctl.py <paths|read|write>\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
