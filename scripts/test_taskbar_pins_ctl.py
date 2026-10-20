#!/usr/bin/env python3
"""Check shared pin edits against JSONC, symlinks and failed atomic replacement."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Load deployable sibling imports without leaving bytecode artifacts.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'src/core/backend/user'
sys.path.insert(0, str(BACKEND))
import taskbar_pins_ctl as ctl


class TaskbarPinsTests(unittest.TestCase):
    # Isolate both the canonical document and desktop-entry metadata.
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'taskbar-pin-apps'
        self.path.write_text((ROOT / 'src/home/hakucfg/config/taskbar-pin-apps').read_text())
        self.environment = patch.dict(os.environ, HAKUSPACE_TASKBAR_PINS_FILE=str(self.path),
                                      XDG_DATA_HOME=self.temp.name, XDG_DATA_DIRS=self.temp.name)
        self.environment.start()
        self.addCleanup(self.environment.stop)

    # Exercise the actual disk-facing API used by QML.
    def run_ctl(self, action, *args):
        return ctl.run(action, list(args))

    def test_order_reserved_and_duplicate_noop(self):
        self.assertEqual([p['id'] for p in self.run_ctl('list')], ['menu', 'kitty', 'thunar', 'firefox'])
        original = self.path.read_bytes()
        self.run_ctl('add', 'kitty.desktop')
        self.assertEqual(self.path.read_bytes(), original)
        for action in ('add', 'remove'):
            with self.assertRaises(ValueError):
                self.run_ctl(action, 'menu')
        self.run_ctl('move', '3', '1')
        self.assertEqual([p['id'] for p in self.run_ctl('reload')], ['menu', 'firefox', 'kitty', 'thunar'])

    def test_add_desktop_remove_comments_and_shared_block(self):
        applications = Path(self.temp.name) / 'applications'
        applications.mkdir()
        desktop = applications / 'org.example.App.desktop'
        desktop.write_text('[Desktop Entry]\nType=Application\nName=Example\nExec=example %U\nIcon=example\n')
        self.run_ctl('add', 'org.example.App.desktop')
        document = json.loads(ctl.jsonc_text(self.path.read_text()))
        self.assertEqual(document['image#org.example.App']['on-click'], 'gio launch ' + str(desktop))
        self.assertIn('/* Add more pin apps here */', self.path.read_text())
        self.run_ctl('remove', 'org.example.App')
        self.assertNotIn('image#org.example.App', json.loads(ctl.jsonc_text(self.path.read_text())))
        raw = self.path.read_text().replace('"orientation": "horizontal",', '"orientation": "horizontal", "other": "image#kitty",')
        document = json.loads(ctl.jsonc_text(raw))
        document['group/other'] = {'modules': ['image#kitty']}
        self.path.write_text(json.dumps(document))
        self.run_ctl('remove', 'kitty')
        self.assertIn('image#kitty', json.loads(self.path.read_text()))
        self.assertNotIn('kitty', [p['id'] for p in self.run_ctl('list')])

    def test_scanner_and_invalid_input_preserve_disk(self):
        raw = r'''{/* comment */ "group/pin":{"modules":["image#menu", "image#missing",]},
            "image#missing":{"on-click":"printf 'https://host/a/*b*/ \\\" // text'"},}'''
        self.path.write_text(raw)
        self.assertIn('https://host/a/*b*/', self.run_ctl('list')[1]['command'])
        self.run_ctl('remove', 'missing')
        self.assertEqual([p['id'] for p in self.run_ctl('list')], ['menu'])
        for raw in ('{/* broken', '{"group/pin":{}}', '{"group/pin":{"modules":[]},"group/pin":{}}', '[]'):
            self.path.write_text(raw)
            with self.assertRaises(ValueError):
                self.run_ctl('add', 'safe')
            self.assertEqual(self.path.read_text(), raw)
        for identity in ('../bad', 'x;touch bad', '-bad', "app'", ''):
            with self.assertRaises(ValueError):
                ctl.app_id(identity)

    def test_missing_blocks_atomic_failure_and_managed_symlink(self):
        self.path.write_text('{"group/pin":{"modules":["image#menu","image#missing"]}}')
        self.assertEqual(self.run_ctl('list')[1]['command'], '')
        old_inode = self.path.stat().st_ino
        self.run_ctl('add', 'other')
        self.assertNotEqual(self.path.stat().st_ino, old_inode)
        original = self.path.read_bytes()
        with patch.object(ctl.os, 'replace', side_effect=OSError('test failure')), self.assertRaises(OSError):
            self.run_ctl('remove', 'other')
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse(list(self.path.parent.glob('.taskbar-pins-*')))
        link = self.path.with_name('managed-link')
        link.symlink_to(self.path)
        with patch.dict(os.environ, HAKUSPACE_TASKBAR_PINS_FILE=str(link)):
            self.run_ctl('remove', 'other')
        self.assertTrue(link.is_symlink())
        result = subprocess.run([str(BACKEND / 'taskbar_pins_ctl.py'), 'list'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(result.stdout)), 2)

    def test_remove_adjacent_alias_blocks(self):
        """Equivalent desktop-suffixed modules share one identity and remove safely."""
        self.path.write_text('{"group/pin":{"modules":["image#menu","image#x","image#x.desktop"]},'
                             '"image#x":{},"image#x.desktop":{}}')
        self.run_ctl('remove', 'x')
        self.assertEqual([pin['id'] for pin in self.run_ctl('list')], ['menu'])

    def test_move_keeps_aliases_together_and_non_image_slots_unchanged(self):
        """Visible pin indices refer to unique apps, including desktop-suffixed aliases."""
        self.path.write_text('{"group/pin":{"modules":["image#menu","clock","image#x",'
                             '"image#x.desktop","image#y"]},"image#x":{"size":40}}')
        self.run_ctl('move', '2', '1')
        data = json.loads(self.path.read_text())
        self.assertEqual([pin['id'] for pin in self.run_ctl('list')], ['menu', 'y', 'x'])
        self.assertEqual(data['group/pin']['modules'], ['image#menu', 'clock', 'image#y', 'image#x', 'image#x.desktop'])
        self.assertEqual(data['image#x'], {'size': 40})

    def test_empty_group_uses_shell_icon_default(self):
        """A new group receives 36 px without overriding explicit shared sizes."""
        self.path.write_text('{"group/pin":{"modules":[]}}')
        self.run_ctl('add', 'fresh-app')
        document = json.loads(ctl.jsonc_text(self.path.read_text()))
        self.assertEqual(document['image#fresh-app']['size'], 36)

    def test_size_preserves_jsonc_and_new_pins_inherit_it(self):
        """Resize edits touch only size values; future pins keep the same size."""
        original = self.path.read_text()
        self.run_ctl('size', '64')
        self.assertEqual(self.path.read_text(), original.replace('"size": 36', '"size": 64'))
        inode = self.path.stat().st_ino
        self.run_ctl('size', '64')
        self.assertEqual(self.path.stat().st_ino, inode)
        self.run_ctl('add', 'new-app')
        self.assertEqual(json.loads(ctl.jsonc_text(self.path.read_text()))['image#new-app']['size'], 64)
        original = self.path.read_bytes()
        for size in ('31', '73', '33', '48.0', 'bad'):
            with self.subTest(size=size), self.assertRaises(ValueError):
                self.run_ctl('size', size)
            self.assertEqual(self.path.read_bytes(), original)

    def test_size_missing_fields_aliases_and_reused_blocks(self):
        """Handle missing sizes and blocks without altering other modules or commands."""
        self.path.write_text('{/* keep */ "group/pin":{"modules":["image#menu","clock","image#x","image#x.desktop"]},'
                             '"image#menu":{}, "image#x":{"on-click":"x", /* keep x */},'
                             '"clock":{"size":9}, "image#saved":{"size":20,"on-click":"saved"}}')
        self.run_ctl('size', '60')
        data = json.loads(ctl.jsonc_text(self.path.read_text()))
        self.assertEqual(data['clock'], {'size': 9})
        self.assertEqual(data['image#saved']['size'], 20)
        for module in ('image#menu', 'image#x', 'image#x.desktop'):
            self.assertEqual(data[module]['size'], 60)
        self.assertEqual(data['image#x']['on-click'], 'x')
        self.assertIn('/* keep x */', self.path.read_text())
        self.run_ctl('add', 'saved')
        data = json.loads(ctl.jsonc_text(self.path.read_text()))
        self.assertEqual(data['image#saved'], {'size': 60, 'on-click': 'saved'})


if __name__ == '__main__':
    unittest.main()
