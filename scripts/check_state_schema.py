#!/usr/bin/env python3
"""Reject legacy, unregistered, or independently constructed runtime state paths."""
from pathlib import Path
import re
import subprocess
import sys

# Import the production registries so schema checks track real migration coverage.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src/core/lib"))
sys.path.insert(0, str(ROOT / "src/core/state"))
from haku_state import STATE_FILES, state_path
from haku_state_migrate import LEGACY_KEYS, RETIRED_FILES

# Migration code alone may refer to pre-upgrade runtime filenames.
EXCLUDED = {"src/core/state/haku_state_migrate.py"}
DOMAINS = {"shell", "desktop", "cava", "screen", "theme", "system", "migration"}
LEGACY = re.compile(r"(?<![\w.-])(?:" + "|".join(map(re.escape, (*LEGACY_KEYS, *RETIRED_FILES))) + r")(?![\w.-])")
CANONICAL = re.compile(r'''(?<=[/"'`])\[([^]\n]+)\]\.[A-Za-z0-9.-]+''')
DIRECT = re.compile(r'(?:hakuspace/state/|\$(?:\{(?:HAKU_STATE_DIR|STATE_DIR)\}|(?:HAKU_STATE_DIR|STATE_DIR))/|(?:Env\.)?stateDir\s*\+\s*["\']/)([^\s"\'`;<>]+)')


def check_text(path, text):
    """Return schema violations with line locations for one production source."""
    errors = []
    for number, line in enumerate(text.splitlines(), 1):
        if LEGACY.search(line):
            errors.append(f"{path}:{number}: legacy state filename")
        for match in CANONICAL.finditer(line):
            if match[1] not in DOMAINS or match[0] not in STATE_FILES.values():
                errors.append(f"{path}:{number}: unregistered canonical state: {match[0]}")
        for match in DIRECT.finditer(line):
            name = match[1]
            if not name.startswith(("$", "{")) and name not in STATE_FILES.values():
                errors.append(f"{path}:{number}: unregistered runtime state path: {name}")
        if path.endswith('.sh') and path != 'src/core/lib/haku_state.sh':
            if re.search(r'(?:STATE_DIR|state_dir)=["\'].*hakuspace/state', line):
                errors.append(f"{path}:{number}: independent runtime state root")
    return errors


def main():
    """Scan production files and verify Bash and Python path registries agree."""
    errors = []
    for base in (ROOT / "src", ROOT / "scripts"):
        for path in sorted(base.rglob("*")):
            relative = path.relative_to(ROOT).as_posix()
            if (not path.is_file() or path.is_symlink() or relative in EXCLUDED
                    or path.name.startswith(("test_", "check_state_schema"))
                    or path.suffix in (".pyc", ".svg", ".png", ".jpg", ".jpeg", ".webp")):
                continue
            try:
                errors.extend(check_text(relative, path.read_text()))
            except UnicodeError:
                continue
    # Resolve every registered key through Bash; no directory or default is created.
    for key in STATE_FILES:
        result = subprocess.run(["bash", "-c", 'source "$1"; haku_state_path "$2"',
                                 "state-schema", str(ROOT / "src/core/lib/haku_state.sh"), key],
                                capture_output=True, text=True)
        if result.returncode or Path(result.stdout.strip()) != state_path(key):
            errors.append(f"Bash/Python state registry mismatch: {key}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"State schema: PASS ({len(STATE_FILES)} registered paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
