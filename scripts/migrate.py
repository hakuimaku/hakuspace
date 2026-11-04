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
from general_menu_ctl import open_parent, parse, read as read_menu_file, validate

HOME = Path.home().absolute()
STATE_ROOT = Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state')
STATE = STATE_ROOT / 'hakuspace/migrations'
RECEIPT = STATE / 'v26.11.json'
MENU = HOME / 'hakucfg/config/hakumenu-general.json'
MANIFEST = json.loads((ROOT / 'scripts/migrations/v26.10-1.json').read_text())
STEP_IDS = {'v26.11-cleanup', 'v26.11-menu'}


# Reject redirected ancestors before writing or deleting destination artifacts.
def safe_path(path):
    if not path.is_absolute() or '..' in path.parts:
        raise ValueError(f'unsafe path preserved: {path}')
    path.relative_to(HOME)
    for parent in [path, *path.parents]:
        if parent == HOME:
            break
        if parent.is_symlink():
            raise ValueError(f'redirected path preserved: {parent}')
    return path


# Open state independently of HOME while retaining no-follow traversal and private ownership.
def state_directory(create):
    if not STATE_ROOT.is_absolute() or '..' in STATE_ROOT.parts:
        raise ValueError(f'XDG_STATE_HOME must be an absolute path without ..: {STATE_ROOT}')
    descriptor = None
    try:
        descriptor = open_parent(STATE_ROOT / '.migration-root', create)
        for name in (None, 'hakuspace', 'migrations'):
            if name is not None:
                if create:
                    try:
                        os.mkdir(name, mode=0o700, dir_fd=descriptor)
                    except FileExistsError:
                        pass
                child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
                os.close(descriptor)
                descriptor = child
            metadata = os.fstat(descriptor)
            if metadata.st_uid != os.getuid() or metadata.st_mode & 0o022:
                raise ValueError(f'unsafe state directory ownership/permissions: {STATE}')
            if create and metadata.st_mode & 0o300 != 0o300:
                raise ValueError(f'state directory is not writable/searchable: {STATE}')
        return descriptor
    except FileNotFoundError:
        if descriptor is not None:
            os.close(descriptor)
        if create:
            raise
        return None
    except BaseException:
        if descriptor is not None:
            os.close(descriptor)
        raise


# Hash only bounded regular file content at migration boundaries.
def digest(path):
    if not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise ValueError(f'unsupported file preserved: {path}')
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Publish receipts and converted JSON with atomic replacement.
def atomic_json(path, value, parent_fd=None, expected=...):
    own_parent = parent_fd is None
    if own_parent:
        safe_path(path)
        parent_fd = open_parent(path, True)
    name = None
    try:
        fcntl.flock(parent_fd, fcntl.LOCK_EX)
        fd, temporary = tempfile.mkstemp(prefix='.migration-', dir=f'/proc/self/fd/{parent_fd}')
        name = Path(temporary).name
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, indent=2, ensure_ascii=False)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        if expected is not ...:
            try:
                current, _ = read_menu_file(parent_fd, path.name)
            except FileNotFoundError:
                current = None
            if current != expected:
                raise ValueError(f'destination changed during migration; preserved: {path}')
        os.replace(name, path.name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        if name is not None:
            try:
                os.unlink(name, dir_fd=parent_fd)
            except FileNotFoundError:
                pass
        if own_parent:
            os.close(parent_fd)


# Persist backup entries and newly created ancestor directories before destructive cleanup.
def sync_backup_directories(directory):
    for path in (directory, *directory.parents):
        descriptor = open_parent(path / '.backup-sync', False)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        if path == HOME:
            break


# Retain exact originals in the shared run backup without overwriting prior backups.
def backup(path):
    target = Path(os.environ['BACKUP_DIR']) / path.relative_to(HOME)
    safe_path(target.parent)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        if path.is_symlink() and target.is_symlink() and os.readlink(path) == os.readlink(target):
            sync_backup_directories(target.parent)
            return
        if not path.is_symlink() and not target.is_symlink() and digest(path) == digest(target):
            with target.open('rb') as stream:
                os.fsync(stream.fileno())
            sync_backup_directories(target.parent)
            return
        raise ValueError(f'backup collision: {target}')
    if path.is_symlink():
        target.symlink_to(os.readlink(path))
    else:
        fd, temporary = tempfile.mkstemp(prefix='.migration-backup-', dir=target.parent)
        os.close(fd)
        try:
            shutil.copy2(path, temporary)
            with open(temporary, 'rb') as stream:
                os.fsync(stream.fileno())
            # Publish only a complete backup and never replace an existing one.
            os.link(temporary, target)
        finally:
            os.unlink(temporary)
    sync_backup_directories(target.parent)
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
        argv = actions.pop(label)
        # Only the original icon, label and launcher command identify the system action.
        identity = 'app-menu' if line == '  App Menu' and argv == ['rofi', '-show', 'drun'] else (
            'legacy-' + hashlib.sha256(f'{index}:{line}'.encode()).hexdigest()[:20])
        rows.append({'id': identity, 'label': label, 'icon': icon, 'argv': argv})
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
def read_receipt(source, parent_fd):
    try:
        if parent_fd is None:
            raise FileNotFoundError
        raw, metadata = read_menu_file(parent_fd, RECEIPT.name)
        if metadata.st_mode & 0o022:
            raise ValueError('migration receipt is writable by other users')
        document = parse(raw.decode('utf-8'))
        if (not isinstance(document, dict) or document.get('target_version') != 'v26.11'
                or document.get('status') not in ('pending', 'applied', 'failed', 'skipped')
                or not isinstance(document.get('steps'), dict)
                or set(document['steps']) - STEP_IDS
                or any(not isinstance(step, dict) or step.get('status') not in ('pending', 'applied', 'failed', 'skipped')
                       for step in document['steps'].values())):
            raise ValueError('invalid migration receipt')
        return document, True
    except FileNotFoundError:
        pass
    except (OSError, ValueError, UnicodeError) as error:
        raise ValueError(f'{RECEIPT}: {error}') from error
    return {'source_version': source or 'legacy-unknown', 'target_version': 'v26.11',
            'status': 'pending', 'steps': {}}, False


# Use the backend's bounded parser and no-follow file reader for migration inputs.
def read_menu(path):
    safe_path(path)
    parent_fd = open_parent(path, False)
    try:
        fcntl.flock(parent_fd, fcntl.LOCK_SH)
        raw, _ = read_menu_file(parent_fd, path.name)
        return parse(raw.decode('utf-8')), raw
    finally:
        os.close(parent_fd)


# History never substitutes for the validity of the user's current destination.
def menu_destination(receipt):
    result = {'path': str(MENU)}
    try:
        document, _ = read_menu(MENU)
    except FileNotFoundError:
        legacy = HOME / 'hakucfg/general-menu.sh'
        required = receipt['steps'].get('v26.11-menu', {}).get('status') == 'applied' or legacy.exists() or legacy.is_symlink()
        return {**result, 'status': 'missing' if required else 'not-required'}
    except json.JSONDecodeError as error:
        return {**result, 'status': 'malformed', 'reason': str(error)}
    except (OSError, ValueError, UnicodeError) as error:
        return {**result, 'status': 'invalid', 'reason': str(error)}
    try:
        validate(document)
    except ValueError as error:
        return {**result, 'status': 'schema-invalid', 'reason': str(error)}
    return {**result, 'status': 'valid'}


# Convert legacy actions once; completed receipts leave later user data untouched.
def migrate_menu(apply, receipt):
    previous = receipt['steps'].get('v26.11-menu', {})
    if previous.get('status') == 'applied':
        return previous
    legacy = HOME / 'hakucfg/general-menu.sh'
    if not legacy.exists() and not legacy.is_symlink():
        return {'status': 'skipped', 'reason': 'no legacy menu'}
    affected = legacy
    try:
        safe_path(legacy)
        fingerprint = digest(legacy)
        document = convert_menu(legacy.read_text())
        destination = safe_path(MENU)
        affected = destination
        original = None
        if destination.exists():
            existing, original = read_menu(destination)
            existing = validate(existing)
            default = validate(parse((ROOT / 'src/home/hakucfg/config/hakumenu-general.json').read_text()))
            if existing != default and existing != document:
                raise ValueError('manual migration required: existing custom JSON preserved')
        if apply:
            backup(legacy)
            # A published conversion may outlive an interrupted receipt write.
            if original is None or existing != document:
                if destination.exists():
                    backup(destination)
                atomic_json(destination, document, expected=original)
            return {'status': 'applied', 'source_sha256': fingerprint, 'output_sha256': digest(destination)}
        return {'status': 'pending', 'reason': f'convert {len(document["items"])} actions; retain legacy source'}
    except (OSError, ValueError, UnicodeError) as error:
        return {'status': 'failed', 'reason': f'manual migration required: {affected}: {error}'}


# Separate destination changes from completion, which belongs to the final update gate.
def run(args, state_fd):
    receipt, recorded = read_receipt(args.source, state_fd)
    changes = cleanup_plan()
    menu = migrate_menu(False, receipt)
    destination = menu_destination(receipt)
    invalid_destination = destination['status'] not in ('valid', 'missing', 'not-required') or (
        receipt['steps'].get('v26.11-menu', {}).get('status') == 'applied' and destination['status'] != 'valid')
    eligible = (set(receipt['steps']) == STEP_IDS
                and all(step['status'] in ('applied', 'skipped') for step in receipt['steps'].values())
                and not any(action in ('remove', 'replace-on-deploy') for _, action, _ in changes)
                and menu['status'] in ('applied', 'skipped')
                and destination['status'] in ('valid', 'not-required'))
    if args.status:
        print(json.dumps({**receipt, 'receipt_present': recorded, 'menu_destination': destination,
                          'completion_eligible': eligible}, indent=2))
        return 0
    for path, action, evidence in changes:
        print(f'LEGACY CLEANUP: {action}: {path} ({evidence})')
    if args.audit:
        if (destination['status'] not in ('valid', 'not-required') or menu['status'] == 'failed'
                or any(action in ('remove', 'replace-on-deploy') for _, action, _ in changes)):
            print(f'MIGRATION AUDIT: incomplete; receipt={receipt["status"]}; '
                  f'destination={destination}; menu={menu}', file=sys.stderr)
            return 1
        if not recorded:
            if destination['status'] == 'not-required':
                print('MIGRATION AUDIT: not-required; no receipt, legacy menu or destination')
                return 0
            print('MIGRATION AUDIT: unverified; destination valid but receipt missing')
            return 2
        if eligible and receipt['status'] in ('applied', 'skipped'):
            print(f'MIGRATION AUDIT: {receipt["status"]}; destination={destination["status"]}')
            return 0
        if eligible and receipt['status'] == 'pending':
            print('MIGRATION AUDIT: pending-finalization; steps and destination valid')
            return 3
        print(f'MIGRATION AUDIT: {receipt["status"]}; migration not complete', file=sys.stderr)
        return 1
    if args.complete:
        if not eligible:
            receipt['status'] = 'failed'
            atomic_json(RECEIPT, receipt, state_fd)
            print(f'migrate: completion refused: destination={destination}; menu={menu}; '
                  f'check unfinished steps; backup={os.environ["BACKUP_DIR"]}', file=sys.stderr)
            return 1
        receipt['status'] = 'applied'
        atomic_json(RECEIPT, receipt, state_fd)
        return 0
    print(f'MIGRATION PLAN: source_version={receipt["source_version"]}; to=v26.11; menu={menu}')
    print(f'MIGRATION DESTINATION: {destination}; completion_eligible={eligible}')
    print(f'BACKUP: {os.environ["BACKUP_DIR"]}')
    if args.plan:
        return int(menu['status'] == 'failed' or invalid_destination)
    if menu['status'] == 'failed' or invalid_destination:
        if menu['status'] == 'failed':
            receipt['steps']['v26.11-menu'] = menu
        receipt['status'] = 'failed'
        atomic_json(RECEIPT, receipt, state_fd)
        return 1
    receipt['status'] = 'pending'
    atomic_json(RECEIPT, receipt, state_fd)
    for path, action, _ in changes:
        if action == 'remove':
            backup(path)
            path.unlink()
            print(f'LEGACY CLEANUP: removed: {path}')
    # Facades still pointing at old paths require deployment before completion.
    unresolved = any(action == 'replace-on-deploy' for _, action, _ in cleanup_plan())
    receipt['steps']['v26.11-cleanup'] = {'status': 'failed' if unresolved else 'applied'}
    receipt['steps']['v26.11-menu'] = migrate_menu(True, receipt)
    failed = any(step['status'] == 'failed' for step in receipt['steps'].values())
    destination = menu_destination(receipt)
    if destination['status'] not in ('valid', 'not-required'):
        failed = True
    if failed:
        receipt['status'] = 'failed'
        print(f'MIGRATION FAILED: menu={receipt["steps"]["v26.11-menu"]}; '
              f'destination={destination}; backup={os.environ["BACKUP_DIR"]}', file=sys.stderr)
    atomic_json(RECEIPT, receipt, state_fd)
    return int(failed)


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
        descriptor = state_directory(args.apply or args.complete)
        try:
            if descriptor is not None:
                fcntl.flock(descriptor, fcntl.LOCK_EX)
            return run(args, descriptor)
        finally:
            if descriptor is not None:
                os.close(descriptor)
    except (OSError, ValueError, KeyError, UnicodeError, RecursionError) as error:
        print(f'migrate: {error}; backup={os.environ.get("BACKUP_DIR", "unset")}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
