#!/usr/bin/env python3
"""Send allowlisted signals to an explicitly selected process identity."""
import argparse
import json
import os
from pathlib import Path
import signal

from task_manager_monitor import parse_stat


def control(action, pid, signal_name=None, start_time=None):
    """Pin a PID with pidfd before checking identity and sending a signal."""
    if pid <= 0 or (action == 'signal' and signal_name not in ('TERM', 'KILL')):
        return {'ok': False, 'status': 'invalidRequest', 'pid': pid}, 2
    descriptor = None
    try:
        # pidfd prevents a process exit/reuse between identity validation and signalling.
        descriptor = os.pidfd_open(pid)
        identity = parse_stat(Path(f'/proc/{pid}/stat').read_text())
        if start_time is not None and identity['startTime'] != start_time:
            return {'ok': True, 'status': 'alreadyExited', 'pid': pid}, 0
        if action == 'signal':
            signal.pidfd_send_signal(descriptor, getattr(signal, 'SIG' + signal_name))
        return {'ok': True, 'status': 'sent' if action == 'signal' else 'running',
                'pid': pid, 'startTime': identity['startTime']}, 0
    except (ProcessLookupError, FileNotFoundError):
        return {'ok': True, 'status': 'alreadyExited', 'pid': pid}, 0
    except PermissionError:
        return {'ok': False, 'status': 'permissionDenied', 'pid': pid}, 1
    except (OSError, ValueError, IndexError, AttributeError) as error:
        return {'ok': False, 'status': 'unavailable', 'pid': pid, 'error': str(error)}, 1
    finally:
        if descriptor is not None:
            os.close(descriptor)


def main():
    """Return machine-readable status for valid and invalid command requests."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('signal', 'status'))
    parser.add_argument('pid')
    parser.add_argument('signal_name', nargs='?')
    parser.add_argument('--start-time', type=int)
    args = parser.parse_args()
    try:
        pid = int(args.pid)
    except ValueError:
        result, code = {'ok': False, 'status': 'invalidPid'}, 2
    else:
        result, code = control(args.action, pid, args.signal_name, args.start_time)
    print(json.dumps(result))
    raise SystemExit(code)


if __name__ == '__main__':
    main()
