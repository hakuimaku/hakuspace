#!/usr/bin/env python3
"""Plan and migrate verified v26.10 artifacts without executing user shell code."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import tempfile

# Use current backend validation without producing source-tree bytecode.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'src/core/backend/user'))
from general_menu_ctl import validate

HOME = Path.home().absolute()
STATE = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'hakuspace/migrations'
RECEIPT = STATE / 'v26.11.json'
MANIFEST = json.loads((ROOT / 'scripts/migrations/v26.10-1.json').read_text())
STEP_IDS = {'v26.11-cleanup', 'v26.11-menu'}


# Reject redirected ancestors before writing or deleting destination artifacts.
def safe_path(path):
    path.relative_to(HOME)
    for parent in [path, *path.parents]:
        if parent == HOME:
            break
        if parent.is_symlink():
            raise ValueError(f'redirected path preserved: {parent}')
    return path


# Hash only bounded regular file content at migration boundaries.
def digest(path):
    if not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise ValueError(f'unsupported file preserved: {path}')
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Publish receipts and converted JSON with atomic replacement.
def atomic_json(path, value):
    safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.migration-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, indent=2, ensure_ascii=False)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


# Retain exact originals in the shared run backup without overwriting prior backups.
def backup(path):
    target = Path(os.environ['BACKUP_DIR']) / path.relative_to(HOME)
    safe_path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        if path.is_symlink() and target.is_symlink() and os.readlink(path) == os.readlink(target):
            return
        if not path.is_symlink() and not target.is_symlink() and digest(path) == digest(target):
            return
        raise ValueError(f'backup collision: {target}')
    if path.is_symlink():
        target.symlink_to(os.readlink(path))
    else:
        shutil.copy2(path, target)
    print(f'BACKUP: {path} -> {target}')


# Support the original heredoc/case/spawn grammar; reject all other shell constructs.
def convert_menu(raw):
    source = '\n'.join(line for line in raw.splitlines() if not line.lstrip().startswith('#')).strip()
    match = re.fullmatch(r'''spawn\(\) \{ \( "\$@" & \) >/dev/null 2>&1; \}
\s*if \[\[ \$# -eq 0 \]\]; then\s*cat <<'EOF'\n(.*?)\nEOF
\s*exit 0\s*fi\s*chosen="\$\*"\s*case "\$chosen" in\n(.*?)\nesac\s*exit 0''', source, re.S)
    if not match:
        raise ValueError('manual migration required: unsupported legacy menu structure')
    labels = [line.strip() for line in match[1].splitlines() if line.strip()]
    actions = {}
    for line in match[2].splitlines():
        action = re.fullmatch(r'\s*\*"([^"$`]+)"\*\) spawn (.+?)\s*;;\s*', line)
        if not action or action[1] in actions:
            raise ValueError('manual migration required: unsupported or duplicate menu action')
        if re.search(r"'[^']*\$[^']*'", action[2]):
            raise ValueError('manual migration required: literal variable syntax')
        command = re.sub(r'\$(?:\{HOME\}|HOME(?=/|["\s]|$))', '~', action[2])
        if any(char in command for char in '$`;&|<>()\n\\'):
            raise ValueError('manual migration required: shell expansion or control syntax')
        actions[action[1]] = shlex.split(command)
    if any(left != right and left in right for left in actions for right in actions):
        raise ValueError('manual migration required: overlapping legacy case patterns')
    rows = []
    for index, line in enumerate(labels):
        matched = [label for label in actions if line == label or line.endswith('  ' + label)]
        if len(matched) != 1:
            raise ValueError('manual migration required: ambiguous menu label')
        label = matched[0]
        icon = line[:-len(label)].strip()
        rows.append({'id': 'legacy-' + hashlib.sha256(f'{index}:{line}'.encode()).hexdigest()[:20],
                     'label': label, 'icon': icon, 'argv': actions.pop(label)})
    if actions:
        raise ValueError('manual migration required: actions absent from displayed menu')
    return validate({'schemaVersion': 1, 'items': rows})


# Inspect the explicit manifest and exact repo-owned bytecode links without mutating HOME.
def cleanup_plan():
    result = []
    for entry in MANIFEST['files']:
        path = HOME / entry['destination']
        if not path.exists() and not path.is_symlink():
            continue
        try:
            safe_path(path.parent)
            if path.is_symlink():
                owned = os.path.abspath(path.parent / os.readlink(path)) == str(ROOT / entry['source'])
            else:
                safe_path(path)
                owned = digest(path) == entry['sha256']
            # Current facade names are replaced by deploy, never deleted from the new catalog.
            current = list((ROOT / 'src/core').rglob(path.name)) if entry['source'].startswith('src/core/') else []
            action = 'replace-on-deploy' if owned and current else 'remove' if owned else 'preserve'
            result.append((path, action, 'legacy manifest target/checksum' if owned else 'ownership unproven'))
        except (OSError, ValueError) as error:
            result.append((path, 'preserve', str(error)))
    binary = HOME / '.local/bin'
    try:
        safe_path(binary)
    except ValueError as error:
        return result + [(binary, 'preserve', str(error))]
    if binary.is_dir():
        for path in sorted(binary.iterdir()):
            if path.suffix not in ('.pyc', '.pyo') or not path.is_symlink():
                continue
            target = Path(os.path.abspath(path.parent / os.readlink(path)))
            if (target.is_relative_to(ROOT / 'src/core') and target.parent.name == '__pycache__'
                    and target.suffix in ('.pyc', '.pyo') and path.name == target.name):
                result.append((path, 'remove', 'exact repo bytecode symlink target'))
    return result


# Read operational history as inert JSON and never infer installed versions from Git HEAD.
def read_receipt(source):
    safe_path(RECEIPT)
    if RECEIPT.exists():
        digest(RECEIPT)
        document = json.loads(RECEIPT.read_text())
        if (not isinstance(document, dict) or document.get('target_version') != 'v26.11'
                or document.get('status') not in ('pending', 'applied', 'failed', 'skipped')
                or not isinstance(document.get('steps'), dict)
                or set(document['steps']) - STEP_IDS
                or any(not isinstance(step, dict) or step.get('status') not in ('pending', 'applied', 'failed', 'skipped')
                       for step in document['steps'].values())):
            raise ValueError('invalid migration receipt')
        return document
    return {'source_version': source or 'legacy-unknown', 'target_version': 'v26.11',
            'status': 'pending', 'steps': {}}


# Convert legacy actions once; completed receipts leave later user data untouched.
def migrate_menu(apply, receipt):
    previous = receipt['steps'].get('v26.11-menu', {})
    if previous.get('status') == 'applied':
        return previous
    legacy = HOME / 'hakucfg/general-menu.sh'
    if not legacy.exists() and not legacy.is_symlink():
        return {'status': 'skipped', 'reason': 'no legacy menu'}
    try:
        safe_path(legacy)
        fingerprint = digest(legacy)
        document = convert_menu(legacy.read_text())
        destination = safe_path(HOME / 'hakucfg/config/hakumenu-general.json')
        if destination.exists():
            existing = validate(json.loads(destination.read_text()))
            default = validate(json.loads((ROOT / 'src/home/hakucfg/config/hakumenu-general.json').read_text()))
            if existing != default and existing != document:
                raise ValueError('manual migration required: existing custom JSON preserved')
        if apply:
            backup(legacy)
            if destination.exists():
                backup(destination)
            atomic_json(destination, document)
            return {'status': 'applied', 'source_sha256': fingerprint, 'output_sha256': digest(destination)}
        return {'status': 'pending', 'reason': f'convert {len(document["items"])} actions; retain legacy source'}
    except (OSError, ValueError, UnicodeError) as error:
        return {'status': 'failed', 'reason': f'manual migration required: {error}'}


# Separate destination changes from completion, which belongs to the final update gate.
def run(args):
    receipt = read_receipt(args.source)
    if args.status:
        print(json.dumps(receipt, indent=2))
        return 0
    changes = cleanup_plan()
    for path, action, evidence in changes:
        print(f'LEGACY CLEANUP: {action}: {path} ({evidence})')
    if args.audit:
        return int(any(action in ('remove', 'replace-on-deploy') for _, action, _ in changes))
    if args.complete:
        if (set(receipt['steps']) != STEP_IDS
                or any(step['status'] not in ('applied', 'skipped') for step in receipt['steps'].values())
                or any(action in ('remove', 'replace-on-deploy') for _, action, _ in changes)
                or migrate_menu(False, receipt)['status'] not in ('applied', 'skipped')):
            raise ValueError('migration has unfinished steps; completion refused')
        receipt['status'] = 'applied'
        atomic_json(RECEIPT, receipt)
        return 0
    menu = migrate_menu(False, receipt)
    print(f'MIGRATION PLAN: source_version={receipt["source_version"]}; to=v26.11; menu={menu}')
    print(f'BACKUP: {os.environ["BACKUP_DIR"]}')
    if args.plan:
        return 0
    receipt['status'] = 'pending'
    atomic_json(RECEIPT, receipt)
    for path, action, _ in changes:
        if action == 'remove':
            backup(path)
            path.unlink()
            print(f'LEGACY CLEANUP: removed: {path}')
    # Facades still pointing at old paths require deployment before completion.
    unresolved = any(action == 'replace-on-deploy' for _, action, _ in cleanup_plan())
    receipt['steps']['v26.11-cleanup'] = {'status': 'failed' if unresolved else 'applied'}
    receipt['steps']['v26.11-menu'] = migrate_menu(True, receipt)
    atomic_json(RECEIPT, receipt)
    return int(any(step['status'] == 'failed' for step in receipt['steps'].values()))


# Serialize apply/finalize calls while inspection remains entirely read-only.
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    for name in ('plan', 'apply', 'status', 'audit', 'complete'):
        mode.add_argument('--' + name, action='store_true')
    parser.add_argument('--from', dest='source', choices=('v26.10-1', 'legacy-unknown'))
    parser.add_argument('--to', '--target', default='v26.11', choices=('v26.11',))
    args = parser.parse_args()
    try:
        if args.apply or args.complete:
            safe_path(STATE)
            STATE.mkdir(parents=True, exist_ok=True)
            descriptor = os.open(STATE, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX)
                return run(args)
            finally:
                os.close(descriptor)
        return run(args)
    except (OSError, ValueError, KeyError) as error:
        print(f'migrate: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
