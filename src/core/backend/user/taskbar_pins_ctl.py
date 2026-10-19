#!/usr/bin/env python3
"""Edit the shared Classic/Hikai Waybar pin document without rewriting its comments."""
import configparser
import fcntl
import json
import os
import re
import shlex
import stat
import sys
import tempfile
from pathlib import Path

# Reuse the deployed settings controller's safe directory traversal.
sys.dont_write_bytecode = True
from hikai_settings_ctl import open_parent


# Keep source offsets stable while masking comments and optional trailing commas.
def jsonc_text(raw):
    result = list(raw)
    index = 0
    while index < len(raw):
        if raw[index] == '"':
            index = json.decoder.scanstring(raw, index + 1)[1]
        elif raw.startswith('//', index):
            end = raw.find('\n', index)
            end = len(raw) if end < 0 else end
            result[index:end] = ' ' * (end - index)
            index = end
        elif raw.startswith('/*', index):
            end = raw.find('*/', index + 2)
            if end < 0:
                raise ValueError('unterminated JSONC comment')
            end += 2
            result[index:end] = ['\n' if c == '\n' else ' ' for c in raw[index:end]]
            index = end
        else:
            index += 1
    cleaned = ''.join(result)
    index = 0
    while index < len(cleaned):
        if cleaned[index] == '"':
            index = json.decoder.scanstring(cleaned, index + 1)[1]
        elif cleaned[index] == ',':
            following = index + 1
            while following < len(cleaned) and cleaned[following].isspace():
                following += 1
            if following < len(cleaned) and cleaned[following] in '}]':
                result[index] = ' '
            index += 1
        else:
            index += 1
    return ''.join(result)


# Reject ambiguous duplicate keys before any mutation can discard data.
def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f'duplicate JSONC key: {key}')
        value[key] = item
    return value


# Locate object values in the original document through the offset-preserving parse.
def members(cleaned, start):
    decoder = json.JSONDecoder()
    index = start + 1
    found = {}
    while True:
        while cleaned[index].isspace() or cleaned[index] == ',':
            index += 1
        if cleaned[index] == '}':
            return found
        key_start = index
        key, index = decoder.raw_decode(cleaned, index)
        while cleaned[index].isspace() or cleaned[index] == ':':
            index += 1
        value_start = index
        _, index = decoder.raw_decode(cleaned, index)
        found[key] = (key_start, value_start, index)


# Desktop suffixes denote the same canonical pin as existing short Waybar IDs.
def app_id(value):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.+\-]*', value):
        raise ValueError('invalid application ID')
    return value.removesuffix('.desktop')


# Expose only ordered image modules, leaving other Waybar modules untouched.
def normalize(document):
    group = document.get('group/pin') if isinstance(document, dict) else None
    modules = group.get('modules') if isinstance(group, dict) else None
    if not isinstance(modules, list) or not all(isinstance(item, str) for item in modules):
        raise ValueError('group/pin.modules must be an array of module names')
    pins = []
    seen = set()
    for module in modules:
        if not module.startswith('image#'):
            continue
        identity = app_id(module[6:])
        if identity in seen:
            continue
        seen.add(identity)
        block = document.get(module, {})
        command = block.get('on-click', '') if isinstance(block, dict) else ''
        pins.append({'id': identity, 'module': module, 'type': 'system' if identity == 'menu' else 'app',
                     'command': command if isinstance(command, str) else ''})
    return pins


# Launch new Classic pins through their desktop file so Exec placeholders remain valid.
def classic_block(identity):
    data_home = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    data_dirs = [data_home, *(Path(p) for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p)]
    for directory in data_dirs:
        applications = directory / 'applications'
        for desktop in applications.rglob('*.desktop') if applications.is_dir() else []:
            if desktop.relative_to(applications).as_posix().replace('/', '-') != identity + '.desktop':
                continue
            entry = configparser.ConfigParser(interpolation=None, strict=False)
            entry.read(desktop, encoding='utf-8')
            if entry.get('Desktop Entry', 'Hidden', fallback='false').lower() == 'true':
                raise ValueError('application is hidden by its desktop entry')
            command = 'gio launch ' + shlex.quote(str(desktop))
            break
        else:
            continue
        break
    else:
        command = shlex.quote(identity)
    return {'exec': '$HOME/.local/bin/taskbar_geticon.sh ' + shlex.quote(identity),
            'size': 40, 'interval': 'once', 'on-click': command}


# Apply narrow edits so unrelated Waybar values, comments and formatting survive.
def edit(raw, action, args):
    cleaned = jsonc_text(raw)
    document = json.loads(cleaned, object_pairs_hook=unique_object)
    pins = normalize(document)
    if action in ('list', 'reload'):
        if args:
            raise ValueError('list/reload takes no arguments')
        return raw, pins
    modules = document['group/pin']['modules'][:]
    root_fields = members(cleaned, len(cleaned) - len(cleaned.lstrip()))
    group_start = root_fields['group/pin'][1]
    _, modules_start, modules_end = members(cleaned, group_start)['modules']
    edits = []
    if action in ('add', 'remove') and len(args) == 1:
        identity = app_id(args[0])
        if identity == 'menu':
            raise ValueError('image#menu is reserved')
        existing = [pin['module'] for pin in pins if pin['id'] == identity]
        module = existing[0] if existing else 'image#' + identity
        if action == 'add':
            if existing:
                return raw, pins
            modules.append(module)
            if module not in document:
                block = json.dumps(classic_block(identity), ensure_ascii=False, indent=4).replace('\n', '\n    ')
                last_end = list(root_fields.values())[-1][2]
                edits.append((last_end, last_end, ',\n    ' + json.dumps(module) + ': ' + block))
        else:
            if not existing:
                return raw, pins
            removed = list(dict.fromkeys(name for name in modules if name.startswith('image#') and app_id(name[6:]) == identity))
            modules = [name for name in modules if name not in removed]
            for name in removed:
                # Retain blocks referenced by another Waybar group or module list.
                others = {key: value for key, value in document.items() if key != name}
                others['group/pin'] = {**document['group/pin'], 'modules': modules}
                if name not in root_fields or referenced(others, name):
                    continue
                key_start, _, value_end = root_fields[name]
                following = value_end
                while following < len(cleaned) and cleaned[following].isspace():
                    following += 1
                if cleaned[following] == ',':
                    edits.append((following, following + 1, ''))
                else:
                    preceding = key_start - 1
                    while cleaned[preceding].isspace():
                        preceding -= 1
                    if cleaned[preceding] == ',':
                        edits.append((preceding, preceding + 1, ''))
                edits.append((key_start, value_end, ''))
    elif action == 'move' and len(args) == 2:
        source, target = map(int, args)
        if not (0 <= source < len(pins) and 0 <= target < len(pins)):
            raise ValueError('pin index out of range')
        # Ordered pin indices exclude any non-image Waybar modules.
        slots = [index for index, name in enumerate(modules) if name.startswith('image#')]
        identities = [pin['id'] for pin in pins]
        identities.insert(target, identities.pop(source))
        # Move every alias of a visible app together without dropping shared modules.
        ordered = [modules[index] for identity in identities for index in slots
                   if app_id(modules[index][6:]) == identity]
        for index, name in zip(slots, ordered):
            modules[index] = name
    else:
        raise ValueError('usage: taskbar_pins_ctl.py list|reload|add ID|remove ID|move FROM TO')
    edits.append((modules_start, modules_end, json.dumps(modules, ensure_ascii=False, indent=4).replace('\n', '\n        ')))
    # Adjacent alias blocks can share the comma selected for deletion.
    deletions = []
    for start, end, replacement in sorted(edits):
        if replacement:
            continue
        if deletions and start <= deletions[-1][1]:
            deletions[-1] = (deletions[-1][0], max(end, deletions[-1][1]), '')
        else:
            deletions.append((start, end, ''))
    for start, end, replacement in sorted([edit for edit in edits if edit[2]] + deletions, reverse=True):
        raw = raw[:start] + replacement + raw[end:]
    return raw, normalize(json.loads(jsonc_text(raw), object_pairs_hook=unique_object))


# Detect references recursively before removing an image block shared outside the pin group.
def referenced(value, module):
    if isinstance(value, dict):
        return any(referenced(item, module) for item in value.values())
    if isinstance(value, list):
        return any(referenced(item, module) for item in value)
    return value == module


# Serialize backend mutations and atomically replace the actual target of managed symlinks.
def run(action, args):
    path = Path(os.environ.get('HAKUSPACE_TASKBAR_PINS_FILE', Path.home() / 'hakucfg/config/taskbar-pin-apps')).resolve()
    parent_fd = open_parent(path, False)
    try:
        fcntl.flock(parent_fd, fcntl.LOCK_EX)
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent_fd)
        with os.fdopen(fd, encoding='utf-8') as stream:
            metadata = os.fstat(stream.fileno())
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
                raise ValueError('pin config must be a regular file owned by the current user')
            original = stream.read()
        updated, pins = edit(original, action, args)
        if updated != original:
            fd, temporary = tempfile.mkstemp(prefix='.taskbar-pins-', dir=f'/proc/self/fd/{parent_fd}')
            temporary = Path(temporary).name
            try:
                with os.fdopen(fd, 'w', encoding='utf-8') as stream:
                    os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode) & 0o644)
                    stream.write(updated)
                    stream.flush()
                    os.fsync(stream.fileno())
                current = os.stat(path.name, dir_fd=parent_fd, follow_symlinks=False)
                if (current.st_ino, current.st_mtime_ns, current.st_size) != (metadata.st_ino, metadata.st_mtime_ns, metadata.st_size):
                    raise ValueError('pin config changed; retry the operation')
                os.replace(temporary, path.name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
                os.fsync(parent_fd)
            finally:
                try:
                    os.unlink(temporary, dir_fd=parent_fd)
                except FileNotFoundError:
                    pass
        return pins
    finally:
        os.close(parent_fd)


if __name__ == '__main__':
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) > 1 else '', sys.argv[2:]), ensure_ascii=False))
    except (OSError, ValueError, UnicodeError, configparser.Error) as error:
        print(f'taskbar-pins: {error}', file=sys.stderr)
        sys.exit(1)
