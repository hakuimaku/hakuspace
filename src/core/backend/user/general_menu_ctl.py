#!/usr/bin/env python3
"""Store and launch the shared General menu through stable item IDs."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys
import tempfile
import unicodedata
import uuid

# Reuse the settings controller's directory traversal without creating bytecode.
sys.dont_write_bytecode = True
from hikai_settings_ctl import open_parent

# Bound editable custom menu documents.
MAX_BYTES = 256 * 1024
# Prior converters salted the exact system row with its index under the 128-row schema cap.
LEGACY_APP_MENU_IDS = {'legacy-' + hashlib.sha256(f'{index}:  App Menu'.encode()).hexdigest()[:20]
                       for index in range(128)}

# Reject duplicate JSON keys instead of silently discarding user data.
def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'duplicate JSON key: {key}')
        result[key] = value
    return result


# Parse only bounded UTF-8 JSON objects at configuration and CLI boundaries.
def parse(raw):
    if len(raw.encode('utf-8')) > MAX_BYTES:
        raise ValueError('JSON exceeds 256 KiB')
    value = json.loads(raw, object_pairs_hook=unique_object)
    if not isinstance(value, dict):
        raise ValueError('JSON must be an object')
    return value


# Validate presentation text before it can become a menu row.
def text(value, name, limit, required=False):
    if (not isinstance(value, str) or len(value) > limit or (required and not value.strip())
            or any(unicodedata.category(char) in ('Cc', 'Cs') for char in value)):
        raise ValueError(f'invalid {name} (maximum {limit} characters)')


# Normalize one editable row while preserving its stable identity.
def item(value):
    if not isinstance(value, dict) or set(value) - {'id', 'label', 'icon', 'argv', 'enabled'}:
        raise ValueError('unknown item fields')
    identity = value.get('id')
    if (not isinstance(identity, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,95}', identity)
            or identity.startswith(('static-', 'builtin-'))):
        raise ValueError('invalid or reserved item id')
    text(value.get('label'), 'label', 96, True)
    text(value.get('icon', ''), 'icon', 16)
    argv = value.get('argv')
    if (not isinstance(argv, list) or not 1 <= len(argv) <= 128
            or any(not isinstance(arg, str) or len(arg) > 4096 or '\0' in arg
                   or any(unicodedata.category(char) == 'Cs' for char in arg) for arg in argv)
            or not argv[0].strip()):
        raise ValueError('argv must contain 1–128 strings, each at most 4096 characters, without NUL')
    if type(value.get('enabled', True)) is not bool:
        raise ValueError('enabled must be a boolean')
    return {**value, 'icon': value.get('icon', ''), 'enabled': value.get('enabled', True)}


# Validate the entire document before exposing or modifying any row.
def validate(document):
    if set(document) != {'schemaVersion', 'items'} or type(document['schemaVersion']) is not int or document['schemaVersion'] != 1:
        raise ValueError('unsupported General menu schema')
    values = document['items']
    if not isinstance(values, list) or len(values) > 128:
        raise ValueError('items must be an array of at most 128 custom rows')
    rows = [item(value) for value in values]
    if len({row['id'] for row in rows}) != len(rows):
        raise ValueError('duplicate item id')
    return {'schemaVersion': 1, 'items': rows}


# Hash exact file bytes so external formatting edits also invalidate stale writes.
def revision(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


# Expose one structured snapshot to both frontends.
def snapshot(document, raw):
    rows = [{**value, 'origin': 'user', 'mutable': True,
             'systemAction': 'app-menu' if (value['id'] == 'app-menu' or (
                 value['id'] in LEGACY_APP_MENU_IDS and value['argv'] == ['rofi', '-show', 'drun'])) else '',
             'enabled': value.get('enabled', True), 'commandText': shlex.join(value['argv'])}
            for value in document['items']]
    return {'ok': True, 'schemaVersion': 1, 'revision': revision(raw), 'items': rows}


# Read only regular user-owned files through a stable directory descriptor.
def read(parent_fd, name):
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent_fd)
    with os.fdopen(fd, 'rb') as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise ValueError('General menu config must be a regular file owned by the current user')
        raw = stream.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError('JSON exceeds 256 KiB')
    return raw, metadata


# Flush a complete temporary document before atomically replacing the previous file.
def write(parent_fd, name, document, original, metadata):
    raw = (json.dumps(document, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    if len(raw) > MAX_BYTES:
        raise ValueError('JSON exceeds 256 KiB')
    fd, temporary = tempfile.mkstemp(prefix='.general-menu-', dir=f'/proc/self/fd/{parent_fd}')
    temporary = Path(temporary).name
    try:
        with os.fdopen(fd, 'wb') as stream:
            os.fchmod(stream.fileno(), (stat.S_IMODE(metadata.st_mode) & 0o640) | 0o600)
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        current, current_metadata = read(parent_fd, name)
        if (current != original or current_metadata.st_ino != metadata.st_ino
                or current_metadata.st_mtime_ns != metadata.st_mtime_ns
                or current_metadata.st_mode != metadata.st_mode):
            raise ValueError('conflict')
        os.replace(temporary, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=parent_fd)
        except FileNotFoundError:
            pass
    return raw


# Accept command entry as shell-style words while never interpreting shell syntax.
def payload_item(payload):
    fields = {key: value for key, value in payload.items() if key not in ('expectedRevision', 'afterId')}
    if 'commandText' in fields:
        if 'argv' in fields or not isinstance(fields['commandText'], str):
            raise ValueError('provide either argv or commandText')
        fields['argv'] = shlex.split(fields.pop('commandText'))
    return fields


# Apply one CRUD operation to the custom document.
def mutate(document, action, identity, payload, index):
    rows = document['items']
    if action == 'add':
        fields = payload_item(payload)
        fields.setdefault('id', 'user-' + uuid.uuid4().hex)
        row = item(fields)
        after = payload.get('afterId')
        position = len(rows)
        if after is not None:
            position = next((i + 1 for i, value in enumerate(rows) if value['id'] == after), None)
            if position is None:
                raise ValueError('unknown afterId')
        rows.insert(position, row)
    else:
        position = next((i for i, value in enumerate(rows) if value['id'] == identity), None)
        if position is None:
            raise ValueError('unknown item id')
        if action == 'update':
            if 'afterId' in payload:
                raise ValueError('afterId is only supported by add')
            fields = payload_item(payload)
            if 'id' in fields and fields['id'] != identity:
                raise ValueError('item id is immutable')
            rows[position] = item({**rows[position], **fields})
        elif action == 'remove':
            rows.pop(position)
        elif action == 'move':
            if not 0 <= index < len(rows):
                raise ValueError('index out of range')
            rows.insert(index, rows.pop(position))
    return validate(document)


# Launch an explicit argument vector in a detached session without shell expansion.
def launch(row):
    if not row['enabled']:
        raise ValueError('item is disabled')
    argv = [os.path.expanduser(arg) for arg in row['argv']]
    environment = {**os.environ, 'PATH': str(Path.home() / '.local/bin') + os.pathsep + os.environ.get('PATH', os.defpath)}
    subprocess.Popen(argv, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


# Serialize mutations and compare the caller's revision before changing user data.
def run(action, identity=None, payload=None, index=None, expected=None):
    path = Path(os.environ.get('HAKUSPACE_GENERAL_MENU_FILE', Path.home() / 'hakucfg/config/hakumenu-general.json')).absolute()
    parent_fd = open_parent(path, False)
    try:
        fcntl.flock(parent_fd, fcntl.LOCK_EX)
        raw, metadata = read(parent_fd, path.name)
        document = validate(parse(raw.decode('utf-8')))
        result = snapshot(document, raw)
        if action in ('get', 'run'):
            row = next((row for row in result['items'] if row['id'] == identity), None)
            if row is None:
                raise ValueError('unknown item id')
            if action == 'run':
                launch(row)
            return {'ok': True, 'schemaVersion': 1, 'revision': result['revision'], 'item': row}
        if action in ('add', 'update', 'remove', 'move'):
            payload = payload or {}
            payload_revision = payload.get('expectedRevision')
            if expected is not None and payload_revision is not None and expected != payload_revision:
                raise ValueError('conflicting expectedRevision values')
            expected = expected if expected is not None else payload_revision
            if expected is not None and expected != result['revision']:
                raise ValueError('conflict')
            document = mutate(document, action, identity, payload, index)
            raw = write(parent_fd, path.name, document, raw, metadata)
            result = snapshot(document, raw)
        return result
    finally:
        os.close(parent_fd)


# Keep CLI syntax explicit and emit one JSON result on success or failure.
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'check', 'get', 'run', 'add', 'update', 'remove', 'move'):
        command = commands.add_parser(action)
        if action in ('get', 'run', 'update', 'remove', 'move'):
            command.add_argument('id')
        if action in ('add', 'update'):
            command.add_argument('payload')
        if action == 'move':
            command.add_argument('index', type=int)
        if action in ('add', 'update', 'remove', 'move'):
            command.add_argument('--expected-revision')
    args = parser.parse_args()
    try:
        result = run(args.action, getattr(args, 'id', None),
                     parse(args.payload) if hasattr(args, 'payload') else None,
                     getattr(args, 'index', None), getattr(args, 'expected_revision', None))
        print(json.dumps(result, ensure_ascii=False))
    except (OSError, ValueError, UnicodeError, RecursionError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
