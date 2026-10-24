#!/usr/bin/env python3
"""Read and atomically update the supported user options in setting.sh."""
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

KINDS = {
    "WELCOME_MSG": "bool", "NIGHT_LIGHT_TEMPERATURE": "int", "SCREENSHOT_DIR": "path",
    "WALL_DIR": "path", "WALL_MPV_DIR": "path", "WALL_INTERVAL": "int",
    "ACCENT_COLOR_BASED_ON_WALLPAPER": "bool", "AWWW_OPTS": "text", "ACCENT_COLOR_MODE": "enum",
    "SCREENREC_SAVE_DIR": "path", "REC_COMMAND": "required", "REC_OPTS": "text",
    "HAKU_CLOCK_FONT_SIZE": "int", "HAKU_GENERAL_FONT_SIZE": "int",
    "HAKU_TERMINAL_FONT_SIZE": "int", "RAM_THRESHOLD_MB": "int", "EXIT_APP_LIST_USER": "list",
    "WAYBAR_MODE_USER": "list",
}
ASSIGNMENT = re.compile(r"^([ \t]*)([A-Za-z_][A-Za-z_0-9]*)=([^\r\n]*)(\r?\n?)$")
HOME = re.compile(r"\$(?:HOME\b|\{HOME\})")


def fail(message):
    raise ValueError(message)


def split_comment(raw):
    """Find a trailing comment without splitting inside quoted shell text."""
    quote = None
    escaped = False
    for index, char in enumerate(raw):
        if escaped:
            escaped = False
        elif char == "\\" and quote != "'":
            escaped = True
        elif quote:
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#" and (index == 0 or raw[index - 1].isspace()):
            return raw[:index].rstrip(), raw[len(raw[:index].rstrip()):]
    return raw.rstrip(), raw[len(raw.rstrip()):]


def parse_word(raw):
    """Read supported shell literals without evaluating commands or variables."""
    if not raw:
        return ""
    if raw[0] == "'" and raw.endswith("'") and "'" not in raw[1:-1]:
        return raw[1:-1]
    if raw[0] == '"' and raw.endswith('"'):
        raw = raw[1:-1]
        result = ""
        index = 0
        while index < len(raw):
            char = raw[index]
            if char == "\\":
                index += 1
                if index >= len(raw) or raw[index] not in '\\"$`':
                    fail("unsupported escape")
                result += raw[index]
            elif char == "$":
                match = HOME.match(raw, index)
                if not match:
                    fail("unsupported expansion")
                result += match.group()
                index = match.end() - 1
            elif char in '"`':
                fail("unsupported quoting")
            else:
                result += char
            index += 1
        return result
    if re.fullmatch(r"[A-Za-z0-9_./:+-]+", raw) or re.fullmatch(r"\$(?:HOME|\{HOME\})(?:/[A-Za-z0-9_./:+-]+)*", raw):
        return raw
    fail("unsupported shell expression")


def parse_value(raw, kind):
    if kind == "list":
        if not raw.startswith("(") or not raw.endswith(")"):
            fail("unsupported array")
        body = raw[1:-1].strip()
        if not body:
            return []
        # Canonical arrays contain quoted words; spaces inside words are preserved.
        words = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:[^\']*)\'|[^\s]+', body)
        if " ".join(words) != body or any(not word.startswith(("\"", "'")) for word in words):
            fail("unsupported array syntax")
        return [parse_word(word) for word in words]
    value = parse_word(raw)
    if kind == "bool":
        if raw not in ("true", "false"):
            fail("expected true or false")
        return raw == "true"
    if kind == "int":
        if not re.fullmatch(r"[1-9][0-9]*", raw):
            fail("expected positive integer")
        return int(raw)
    if kind == "enum" and value not in ("vivid", "dominant", "brightest", "saturated"):
        fail("invalid accent mode")
    if kind in ("path", "required", "enum") and not value:
        fail("empty value")
    return value


def inspect(content):
    """Index managed assignments and report duplicates or unsupported syntax."""
    lines = content.splitlines(keepends=True)
    values, positions, unsupported, duplicates = {}, {}, [], []
    version = ""
    for index, line in enumerate(lines):
        match = ASSIGNMENT.match(line)
        if not match:
            continue
        key = match.group(2)
        if key not in KINDS and key != "SETTING_VERSION":
            continue
        if key in positions:
            duplicates.append(key)
            continue
        positions[key] = index
        raw, _ = split_comment(match.group(3))
        try:
            value = parse_value(raw, "text" if key == "SETTING_VERSION" else KINDS[key])
            if key == "SETTING_VERSION":
                version = value
            else:
                values[key] = value
        except ValueError:
            if key in KINDS:
                unsupported.append(key)
    return lines, values, positions, sorted(set(unsupported)), sorted(set(KINDS) - positions.keys()), sorted(set(duplicates)), version


def validate(key, value):
    kind = KINDS[key]
    if kind == "bool":
        valid = type(value) is bool
    elif kind == "int":
        valid = type(value) is int and value > 0
    elif kind == "list":
        valid = isinstance(value, list) and all(isinstance(item, str) and item and not any(char in item for char in "\n\r\0") for item in value)
    else:
        valid = isinstance(value, str) and not any(char in value for char in "\n\r\0") and (kind not in ("path", "required", "enum") or bool(value))
        if kind == "enum":
            valid = valid and value in ("vivid", "dominant", "brightest", "saturated")
    if not valid:
        fail(f"{key}: invalid {kind} value")


def quote(value, home=False):
    result = '"'
    index = 0
    while index < len(value):
        match = HOME.match(value, index) if home else None
        if match:
            result += match.group()
            index = match.end()
            continue
        char = value[index]
        result += "\\" + char if char in '\\"$`' else char
        index += 1
    return result + '"'


def serialize(key, value, original=""):
    kind = KINDS[key]
    if kind == "bool":
        return "true" if value else "false"
    if kind == "int":
        return str(value)
    if kind == "list":
        return "(" + " ".join(quote(item) for item in value) + ")"
    # Keep literal HOME text literal when the original assignment explicitly quoted it that way.
    literal_home = original.startswith("'") or "\\$HOME" in original or "\\${HOME}" in original
    return quote(value, kind in ("path", "required") and not literal_home)


def response(path, content):
    _, values, _, unsupported, missing, duplicates, version = inspect(content)
    return {"ok": True, "path": str(path), "settingVersion": version, "values": values,
            "unsupportedKeys": unsupported, "missingKeys": missing, "duplicateKeys": duplicates}


def run(action):
    """Validate requested edits, preserve other lines, and atomically replace the file."""
    path = Path(os.environ.get("HAKUSPACE_SETTING_FILE") or Path.home() / "hakucfg/setting.sh")
    content = path.read_bytes().decode("utf-8")
    data = response(path, content)
    if action == "read":
        return data
    if data["duplicateKeys"]:
        fail("duplicate assignments: " + ", ".join(data["duplicateKeys"]))
    if action == "check":
        if data["unsupportedKeys"] or data["missingKeys"]:
            fail("unsupported or missing managed settings")
        checked = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
        if checked.returncode:
            fail(checked.stderr.strip() or "bash syntax check failed")
        return data
    if action != "write":
        fail("usage: setting_ctl.py read|write|check")
    payload = json.loads(os.environ.get("HAKUSPACE_SETTINGS_JSON", ""))
    if not isinstance(payload, dict):
        fail("settings payload must be an object")
    lines, _, positions, unsupported, missing, _, _ = inspect(content)
    for key, value in payload.items():
        if key not in KINDS:
            fail(f"{key}: unknown or read-only setting")
        if key in unsupported or key in missing:
            fail(f"{key}: unsupported or missing assignment")
        validate(key, value)
        match = ASSIGNMENT.match(lines[positions[key]])
        original, comment = split_comment(match.group(3))
        lines[positions[key]] = match.group(1) + key + "=" + serialize(key, value, original) + comment + match.group(4)
    updated = "".join(lines)
    if not payload:
        return data
    original_stat = path.stat()
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".setting-", delete=False) as temp:
            temp_name = temp.name
            temp.write(updated)
            temp.flush()
            os.fchmod(temp.fileno(), stat.S_IMODE(original_stat.st_mode))
            os.fsync(temp.fileno())
        checked = subprocess.run(["bash", "-n", temp_name], capture_output=True, text=True)
        if checked.returncode:
            fail(checked.stderr.strip() or "bash syntax check failed")
        os.replace(temp_name, path)
        temp_name = None
    finally:
        if temp_name is not None:
            os.unlink(temp_name)
    return response(path, updated)


if __name__ == "__main__":
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) == 2 else "")))
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
