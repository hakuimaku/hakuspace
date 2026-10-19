#!/usr/bin/env python3
"""Terminate the selected compositor application's processes after a RAM check."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
from setting_ctl import inspect


# Read the saved Exit threshold without evaluating shell commands.
def ram_threshold():
    path = Path.home() / 'hakucfg/setting.sh'
    if not path.exists():
        return 300
    _, values, _, unsupported, _, duplicates, _ = inspect(path.read_text())
    if 'RAM_THRESHOLD_MB' in unsupported + duplicates:
        raise ValueError('Could not read the RAM warning threshold in Exit settings.')
    return values.get('RAM_THRESHOLD_MB', 300)


# Match complete compositor app IDs; never treat them as process-name patterns.
def window_pids(app_ids):
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        command, app_key = ['hyprctl', '-j', 'clients'], 'class'
    elif os.environ.get('NIRI_SOCKET'):
        command, app_key = ['niri', 'msg', '-j', 'windows'], 'app_id'
    elif os.environ.get('MANGO_INSTANCE_SIGNATURE'):
        command, app_key = ['mmsg', 'get', 'all-clients'], 'appid'
    else:
        raise ValueError('This compositor does not expose app PIDs for termination.')
    response = subprocess.run(command, capture_output=True, text=True, check=True, timeout=3)
    windows = json.loads(response.stdout)
    if app_key == 'appid':
        windows = windows['clients']
    if not isinstance(windows, list) or any(not isinstance(window, dict) for window in windows):
        raise ValueError('Could not read the compositor’s app PIDs.')
    matched = [window for window in windows if window.get(app_key) in app_ids]
    if any(type(window.get('pid')) is not int or window['pid'] <= 1 for window in matched):
        raise ValueError('The compositor could not identify this app’s process.')
    return {window['pid'] for window in matched}


# Snapshot identity, ancestry and resident memory for processes owned by this user.
def process_info(pid):
    directory = Path('/proc') / str(pid)
    if directory.stat().st_uid != os.getuid():
        return None
    fields = (directory / 'stat').read_text().rsplit(')', 1)[1].split()
    return {'pid': pid, 'parent': int(fields[1]), 'startTime': fields[19],
            'ramMb': max(0, int(fields[21])) * os.sysconf('SC_PAGE_SIZE') / 1048576}


# Include helper processes once, even when multiple app windows share a root.
def app_processes(pids, snapshot):
    selected = {pid for pid in pids if pid in snapshot}
    while True:
        children = {pid for pid, info in snapshot.items() if info['parent'] in selected}
        if children <= selected:
            return selected
        selected.update(children)


# Exclude the calling shell and its ancestors from destructive application actions.
def protected_pids(snapshot):
    protected = {os.getpid(), 1}
    pid = os.getpid()
    while pid in snapshot and snapshot[pid]['parent'] not in protected:
        pid = snapshot[pid]['parent']
        protected.add(pid)
    return protected


# Recheck root identities on confirmation and pin each signal to a Linux pidfd.
def terminate(app_ids, confirmed_roots):
    if not isinstance(app_ids, list) or not app_ids or any(not isinstance(app, str) or not app or '\0' in app for app in app_ids):
        raise ValueError('Invalid application IDs.')
    if not isinstance(confirmed_roots, list):
        raise ValueError('Invalid process confirmation.')
    threshold = ram_threshold()
    pids = window_pids(app_ids)
    snapshot = {}
    for directory in Path('/proc').iterdir():
        if not directory.name.isdecimal():
            continue
        try:
            info = process_info(int(directory.name))
            if info:
                snapshot[info['pid']] = info
        except (FileNotFoundError, ProcessLookupError):
            continue
    selected = app_processes(pids, snapshot)
    if selected & protected_pids(snapshot):
        raise ValueError('The desktop shell cannot terminate itself from the Dock.')
    roots = [{'pid': pid, 'startTime': snapshot[pid]['startTime']} for pid in sorted(pids & snapshot.keys())]
    ram_mb = sum(snapshot[pid]['ramMb'] for pid in selected)
    if roots and ram_mb >= threshold and confirmed_roots != roots:
        return {'status': 'confirmation', 'ramMb': ram_mb, 'thresholdMb': threshold, 'roots': roots}
    # Open every handle before signalling so a root cannot exit and recycle a child PID.
    handles = []
    try:
        for pid in sorted(selected):
            try:
                handle = os.pidfd_open(pid)
            except ProcessLookupError:
                continue
            handles.append(handle)
            info = process_info(pid)
            if not info or info['startTime'] != snapshot[pid]['startTime']:
                raise ValueError('The app changed processes. Please try again.')
        for handle in handles:
            try:
                signal.pidfd_send_signal(handle, signal.SIGTERM)
            except ProcessLookupError:
                pass
    finally:
        for handle in handles:
            os.close(handle)
    return {'status': 'terminated'}


# Return one structured result to the Dock without executing application text.
def main():
    try:
        if len(sys.argv) != 4 or sys.argv[1] != 'terminate':
            raise ValueError('Usage: dock_app_ctl.py terminate APP_IDS_JSON CONFIRMED_ROOTS_JSON')
        result = terminate(json.loads(sys.argv[2]), json.loads(sys.argv[3]))
    except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError) as error:
        print(json.dumps({'status': 'error', 'message': str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
