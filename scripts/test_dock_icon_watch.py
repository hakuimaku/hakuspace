#!/usr/bin/env python3
"""Exercise icon file edits, additions, theme switches and batched stdin requests."""
import json
import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IconRefreshTests(unittest.TestCase):
    # Private GTK configuration avoids changing the desktop's selected icon theme.
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / 'config/gtk-3.0/settings.ini'
        self.config.parent.mkdir(parents=True)
        self.config.write_text('[Settings]\ngtk-icon-theme-name=Fixture\n')
        self.folder = self.create_theme('Fixture')
        self.icon = self.folder / 'probe.svg'
        self.icon.write_text(self.svg('red'))
        environment = dict(os.environ, XDG_CONFIG_HOME=str(self.root / 'config'),
                           XDG_DATA_HOME=str(self.root / 'data'), GSETTINGS_BACKEND='memory')
        environment.pop('DISPLAY', None)
        environment.pop('WAYLAND_DISPLAY', None)
        self.host = subprocess.Popen(['python3', '-u', str(ROOT / 'src/core/backend/user/dock_icon_watch.py')],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     env=environment)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.host.stdout, selectors.EVENT_READ)
        self.buffer = b''
        self.addCleanup(self.close_host)
        self.send(['probe', 'added'])
        self.first = self.wait_for(lambda value: 'probe' in value)

    # Generate theme metadata accepted by the native GTK icon index.
    def create_theme(self, name):
        theme = self.root / 'data/icons' / name
        folder = theme / '48x48/apps'
        folder.mkdir(parents=True)
        (theme / 'index.theme').write_text('[Icon Theme]\nName=' + name
                                          + '\nDirectories=48x48/apps\n\n[48x48/apps]\nSize=48\nType=Fixed\nContext=Applications\n')
        return folder

    # Use distinct pixels while retaining one icon name throughout each test.
    def svg(self, color):
        return '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"><rect width="48" height="48" fill="' + color + '"/></svg>'

    # Write requests together to exercise pipe buffering as well as ordinary updates.
    def send(self, icons):
        self.host.stdin.write((json.dumps({'icons': icons, 'size': 48}) + '\n').encode())
        self.host.stdin.flush()

    # Wait for observable state rather than relying on monitor debounce timing.
    def wait_for(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            while b'\n' in self.buffer:
                line, self.buffer = self.buffer.split(b'\n', 1)
                value = json.loads(line)
                if predicate(value):
                    return value
            if self.selector.select(.2):
                chunk = os.read(self.host.stdout.fileno(), 65536)
                if not chunk:
                    self.fail(self.host.stderr.read().decode())
                self.buffer += chunk
        self.fail('No matching icon update before timeout')

    # Closing stdin must terminate the monitor host and release all native watches.
    def close_host(self):
        self.host.stdin.close()
        try:
            self.assertEqual(self.host.wait(timeout=5), 0)
        finally:
            if self.host.poll() is None:
                self.host.kill()
                self.host.wait()
            self.selector.close()
            self.host.stdout.close()
            self.host.stderr.close()

    def test_edit_atomic_replace_delete_restore_and_add(self):
        self.icon.write_text(self.svg('blue'))
        edited = self.wait_for(lambda value: value.get('probe') != self.first['probe'])
        replacement = self.icon.with_suffix('.new')
        replacement.write_text(self.svg('green'))
        replacement.replace(self.icon)
        self.wait_for(lambda value: value.get('probe') != edited['probe'])
        self.icon.unlink()
        self.wait_for(lambda value: 'probe' not in value)
        self.icon.write_text(self.svg('yellow'))
        self.wait_for(lambda value: 'probe' in value)
        (self.folder / 'added.svg').write_text(self.svg('purple'))
        self.wait_for(lambda value: 'added' in value)

    def test_theme_switch_and_absolute_path(self):
        folder = self.create_theme('Other')
        (folder / 'probe.svg').write_text(self.svg('blue'))
        temporary = self.config.with_suffix('.new')
        temporary.write_text('[Settings]\ngtk-icon-theme-name=Other\n')
        temporary.replace(self.config)
        self.wait_for(lambda value: '/Other/' in value.get('probe', ''))
        self.send([str(self.icon)])
        self.wait_for(lambda value: str(self.icon) in value)

    def test_symlinked_settings_follow_target_replacement(self):
        target = self.config.with_name('theme-settings.ini')
        self.config.rename(target)
        self.config.symlink_to(target)
        self.wait_for(lambda value: 'probe' in value)
        folder = self.create_theme('Other')
        (folder / 'probe.svg').write_text(self.svg('blue'))
        temporary = target.with_suffix('.new')
        temporary.write_text('[Settings]\ngtk-icon-theme-name=Other\n')
        temporary.replace(target)
        self.wait_for(lambda value: '/Other/' in value.get('probe', ''))

    def test_batched_requests_use_latest_set(self):
        requests = [json.dumps({'icons': icons, 'size': 48}) for icons in (['probe'], ['added'], [str(self.icon)])]
        self.host.stdin.write(('\n'.join(requests) + '\n').encode())
        self.host.stdin.flush()
        self.wait_for(lambda value: list(value) == [str(self.icon)])


if __name__ == '__main__':
    unittest.main()
