#!/usr/bin/env python3
"""Resolve managed icon installations and remove verified legacy backup entries."""
import configparser
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

# System installations participate in activation but never in mutation.
SYSTEM_ROOTS = (Path('/usr/local/share/icons'), Path('/usr/share/icons'))
VARIANTS = {'Hikaide-Symbols': 'dark', 'Hikaide-Symbols-Light': 'light'}


def icon_roots():
    """Honor an explicit root; otherwise follow XDG, legacy HOME, then system roots."""
    override = os.environ.get('HAKU_ICON_DIR')
    roots = [Path(override).expanduser()] if override else [
        Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'icons',
        Path.home() / '.icons', *SYSTEM_ROOTS]
    return list(dict.fromkeys(Path(os.path.abspath(path)) for path in roots))


def icon_directory(name):
    """Return the first installed directory in the same order used for reconciliation."""
    if not name or Path(name).name != name or name in ('.', '..'):
        return None
    return next((root / name for root in icon_roots() if (root / name / 'index.theme').is_file()), None)


def managed_variant(path):
    """Require exact family, version, variant and index metadata without path escapes."""
    mode = VARIANTS.get(path.name)
    try:
        if mode is None or path.resolve() != path or not path.is_dir():
            return None
        index = path / 'index.theme'
        if index.is_symlink():
            return None
        config = configparser.ConfigParser(interpolation=None)
        config.read_string(index.read_text())
        if config.get('Icon Theme', 'Name', fallback='') != path.name:
            return None
        marker = path / '.hikaide-symbols.json'
        if marker.exists() or marker.is_symlink():
            if not marker.is_symlink() and json.loads(marker.read_text()) == {
                    'family': 'Hikaide-Symbols', 'version': 2, 'variant': mode}:
                return mode
        else:
            marker = path / '.hikaide-symbols'
            if mode == 'dark' and not marker.is_symlink() and marker.read_text().rstrip('\n') == 'Hikaide-Symbols managed theme v1':
                return 'legacy'
    except (OSError, ValueError, RuntimeError, configparser.Error):
        pass
    return None


def user_writable(path):
    """Exclude system trees even when running as their owner."""
    resolved = path.resolve()
    return (not any(resolved == root or root in resolved.parents for root in SYSTEM_ROOTS)
            and path.stat().st_uid == os.getuid() and os.access(path, os.W_OK))


def installation_targets(path):
    """Validate a complete v2 pair before exposing either member to the engine."""
    variant = managed_variant(path)
    if variant is None or not user_writable(path):
        return 'not-applicable', []
    if variant == 'legacy':
        return 'active', [{'directory': str(path), 'variant': 'dark'}]
    targets = []
    for name, mode in VARIANTS.items():
        sibling = path.parent / name
        if not (sibling / 'index.theme').is_file():
            return 'missing', []
        if managed_variant(sibling) != mode or not user_writable(sibling):
            return 'not-applicable', []
        targets.append({'directory': str(sibling), 'variant': mode})
    return 'active', targets


def resolve(name, accent_mode):
    """Use one resolution result for discovery, policy, status and write targets."""
    directory = icon_directory(name)
    result = {'directory': str(directory) if directory else None, 'policy': 'disabled', 'targets': []}
    if name not in VARIANTS or accent_mode == 'off':
        return result
    if directory is None:
        result['policy'] = 'missing'
        return result
    result['policy'], _ = installation_targets(directory)
    if result['policy'] != 'active':
        return result
    copies = 0
    for root in icon_roots():
        candidate = root / name
        if not candidate.is_dir():
            continue
        policy, entries = installation_targets(candidate)
        if policy == 'active':
            result['targets'].extend(entries)
            copies += 1
    if copies > 1:
        print('appearance: warning: multiple managed icon installations; synchronizing all user copies', file=sys.stderr)
    return result


def cleanup_legacy_state():
    """Delete only hashed Hikaide entries whose state identifies a known user root."""
    state_root = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'icon-accent'
    if state_root.is_symlink() or not state_root.is_dir():
        return
    roots = (set(icon_roots()) | {Path.home() / '.icons',
             Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'icons'}) - set(SYSTEM_ROOTS)
    for entry in state_root.iterdir():
        try:
            if entry.is_symlink() or not entry.is_dir() or entry.stat().st_uid != os.getuid():
                continue
            state_file = entry / 'state.json'
            if state_file.is_symlink() or state_file.stat().st_uid != os.getuid():
                continue
            state = json.loads(state_file.read_text())
            location = Path(state['location'])
            name = state['theme']
            key = name + '-' + hashlib.sha256(str(location).encode()).hexdigest()[:16]
            if (name not in VARIANTS or location.name != name or not location.is_absolute()
                    or location.parent not in roots or location.resolve() != location or entry.name != key
                    or state.get('backend') != 'kde-colorscheme' or not isinstance(state.get('files'), dict)):
                continue
            shutil.rmtree(entry)
        except (OSError, ValueError, KeyError, TypeError, RuntimeError):
            continue
    try:
        state_root.rmdir()
    except OSError:
        pass


def main():
    """Expose resolver data and the idempotent migration to the shell controller."""
    if sys.argv[1:] == ['cleanup']:
        cleanup_legacy_state()
    else:
        print(json.dumps(resolve(sys.argv[1], sys.argv[2])))


if __name__ == '__main__':
    main()
