#!/usr/bin/env python3
"""Present General menu snapshots and dispatch Rofi metadata IDs."""
import json
import os
from pathlib import Path
import subprocess
import sys


# Resolve both the flat installation and the source-tree backend.
def controller():
    directory = Path(__file__).absolute().parent
    for path in (directory / 'general_menu_ctl.py', directory / '../../backend/user/general_menu_ctl.py',
                 Path.home() / '.local/bin/general_menu_ctl.py'):
        if path.is_file():
            return path
    raise ValueError('General menu backend not found')


# Keep display labels out of action dispatch, including duplicate labels.
def main():
    try:
        action = os.environ.get('ROFI_RETV', '1' if len(sys.argv) > 1 else '0')
        if action == '0':
            arguments = ['list']
        elif action == '1' and os.environ.get('ROFI_INFO'):
            arguments = ['run', os.environ['ROFI_INFO']]
        else:
            return 0
        response = subprocess.run([sys.executable, str(controller()), *arguments],
                                  capture_output=True, text=True, check=False)
        model = json.loads(response.stdout)
        if response.returncode or not model.get('ok'):
            raise ValueError(model.get('error', 'General menu backend failed'))
        if action == '0':
            sys.stdout.write('\0no-custom\x1ftrue\n')
            for row in model['items']:
                if row['enabled']:
                    sys.stdout.write(f"{row['icon']}  {row['label']}\0info\x1f{row['id']}\n")
        return 0
    except (OSError, ValueError, KeyError) as error:
        print(f'General menu: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
