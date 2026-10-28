#!/usr/bin/env python3
"""Check PID selection, RAM confirmation and termination with disposable processes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'src/core/backend/user'))
import dock_app_ctl as ctl


class DockTerminationTests(unittest.TestCase):
    # Keep all settings and signal targets outside the user's desktop apps.
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / 'hakucfg').mkdir()
        self.environment = patch.dict(os.environ, HOME=str(self.home))
        self.environment.start()
        self.addCleanup(self.environment.stop)

    # Allocate a real resident buffer so the threshold branch has observable memory.
    def app_process(self):
        app = subprocess.Popen([sys.executable, '-c',
                                'import time; buffer=bytearray(16*1024*1024); print("ready", flush=True); time.sleep(30)'],
                               stdout=subprocess.PIPE, text=True)
        self.addCleanup(lambda: app.stdout.close())
        self.addCleanup(lambda: app.wait(timeout=5))
        self.addCleanup(lambda: app.kill() if app.poll() is None else None)
        self.assertEqual(app.stdout.readline().strip(), 'ready')
        return app

    def test_saved_threshold_and_unsupported_assignment(self):
        self.assertEqual(ctl.ram_threshold(), 300)
        setting = self.home / 'hakucfg/setting.sh'
        setting.write_text('RAM_THRESHOLD_MB=42 # custom\n')
        self.assertEqual(ctl.ram_threshold(), 42)
        setting.write_text('RAM_THRESHOLD_MB=0 # minimum\n')
        self.assertEqual(ctl.ram_threshold(), 0)
        for text in ('RAM_THRESHOLD_MB=$(touch unsafe)\n', 'RAM_THRESHOLD_MB=1\nRAM_THRESHOLD_MB=2\n'):
            setting.write_text(text)
            with self.assertRaises(ValueError):
                ctl.ram_threshold()
        self.assertFalse((self.home / 'unsafe').exists())

    def test_compositor_pid_mapping_is_exact(self):
        cases = [('NIRI_SOCKET', [{'app_id': 'org.App', 'pid': 100}, {'app_id': 'org.AppExtra', 'pid': 200}], ['niri', 'msg', '-j', 'windows']),
                 ('HYPRLAND_INSTANCE_SIGNATURE', [{'class': 'org.App', 'pid': 100}], ['hyprctl', '-j', 'clients']),
                 ('MANGO_INSTANCE_SIGNATURE', {'clients': [{'appid': 'org.App', 'pid': 100}]}, ['mmsg', 'get', 'all-clients'])]
        for variable, response, command in cases:
            with self.subTest(compositor=variable), patch.dict(os.environ, {variable: 'fixture'}, clear=True), \
                    patch.object(ctl.subprocess, 'run', return_value=subprocess.CompletedProcess(command, 0, json.dumps(response))) as run:
                self.assertEqual(ctl.window_pids(['org.App']), {100})
                self.assertEqual(run.call_args.args[0], command)
        with patch.dict(os.environ, clear=True), self.assertRaises(ValueError):
            ctl.window_pids(['org.App'])
        with patch.dict(os.environ, NIRI_SOCKET='fixture'), \
                patch.object(ctl.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '[{"app_id":"org.App","pid":null}]')), \
                self.assertRaises(ValueError):
            ctl.window_pids(['org.App'])

    def test_high_ram_waits_for_second_click_and_identity_match(self):
        app = self.app_process()
        with patch.object(ctl, 'window_pids', return_value={app.pid}), patch.object(ctl, 'ram_threshold', return_value=1):
            first = ctl.terminate(['org.App'], [])
            self.assertEqual(first['status'], 'confirmation')
            self.assertGreater(first['ramMb'], 16)
            self.assertIsNone(app.poll())
            stale = [{'pid': app.pid, 'startTime': '0'}]
            self.assertEqual(ctl.terminate(['org.App'], stale)['status'], 'confirmation')
            self.assertIsNone(app.poll())
            self.assertEqual(ctl.terminate(['org.App'], first['roots'])['status'], 'terminated')
            self.assertEqual(app.wait(timeout=5), -15)

    def test_below_threshold_terminates_on_first_click(self):
        app = self.app_process()
        with patch.object(ctl, 'window_pids', return_value={app.pid}), patch.object(ctl, 'ram_threshold', return_value=1000000):
            self.assertEqual(ctl.terminate(['org.App'], []), {'status': 'terminated'})
        self.assertEqual(app.wait(timeout=5), -15)

    def test_descendants_deduplicate_and_shell_is_protected(self):
        snapshot = {10: {'parent': 1}, 11: {'parent': 10}, 12: {'parent': 11}, 99: {'parent': 1}}
        self.assertEqual(ctl.app_processes({10, 11}, snapshot), {10, 11, 12})
        with patch.object(ctl, 'window_pids', return_value={os.getpid()}), patch.object(ctl.signal, 'pidfd_send_signal') as send:
            with self.assertRaisesRegex(ValueError, 'cannot terminate itself'):
                ctl.terminate(['shell'], [])
            send.assert_not_called()

    def test_pid_reuse_aborts_before_any_signal(self):
        app = self.app_process()
        original = ctl.process_info
        reads = 0
        def changed_identity(pid):
            nonlocal reads
            info = original(pid)
            if pid == app.pid:
                reads += 1
                if reads > 1:
                    info['startTime'] = 'changed'
            return info
        with patch.object(ctl, 'window_pids', return_value={app.pid}), patch.object(ctl, 'ram_threshold', return_value=1000000), \
                patch.object(ctl, 'process_info', side_effect=changed_identity), patch.object(ctl.signal, 'pidfd_send_signal') as send:
            with self.assertRaisesRegex(ValueError, 'changed processes'):
                ctl.terminate(['org.App'], [])
            send.assert_not_called()
        self.assertIsNone(app.poll())

    def test_invalid_input_never_queries_compositor(self):
        with patch.object(ctl, 'window_pids') as query:
            for ids, confirmation in (([], []), ([''], []), ('app', []), ([None], []), (['app'], {})):
                with self.assertRaises(ValueError):
                    ctl.terminate(ids, confirmation)
            query.assert_not_called()


if __name__ == '__main__':
    unittest.main()
