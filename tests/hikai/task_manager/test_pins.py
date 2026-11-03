#!/usr/bin/env python3
"""Exercise shared live-instance pins with real FileView persistence and isolated IPC."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class PinsTest(unittest.TestCase):
    """Keep pin files and process fixtures outside the user's shell and state."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='task-manager-pins-')
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.frame_number = 0
        self.path = self.work / 'state/hakuspace/task_manager_pins.json'
        if self._testMethodName != 'test_cold_storage':
            self.path.parent.mkdir(parents=True)
            self.path.write_text('["7:100", "9:200", "7:100"]')
        services = self.work / 'services'
        services.mkdir()
        shutil.copy2(ROOT / 'src/home/.config/quickshell/hakuspace/services/TaskManagerPins.qml', services)
        (services / 'TaskManagerService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool ready: false; property bool warmingUp: false
    property bool monitorRestartPending: false; property bool monitorStopPending: false
    property real processTimestamp: -1; property var processes: []
}
''')
        (services / 'qmldir').write_text('singleton TaskManagerPins 1.0 TaskManagerPins.qml\nsingleton TaskManagerService 1.0 TaskManagerService.qml\n')
        (self.work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
    Component.onCompleted: { Quickshell.watchFiles = false; TaskManagerPins.pinnedKeys }
    IpcHandler {
        target: "pins"
        function state(): string { return JSON.stringify({keys: TaskManagerPins.pinnedKeys,
            rows: TaskManagerPins.pinnedProcesses, error: TaskManagerPins.error,
            misses: TaskManagerPins.missingFramesByKey,
            processes: TaskManagerService.processes, ready: TaskManagerService.ready, timestamp: TaskManagerService.processTimestamp}) }
        function frame(payload: string): string {
            var value = JSON.parse(payload)
            TaskManagerService.ready = value.ready
            TaskManagerService.warmingUp = value.warming
            TaskManagerService.monitorRestartPending = value.restart
            TaskManagerService.processes = value.rows
            TaskManagerService.processTimestamp = value.timestamp
            return JSON.stringify(TaskManagerService.processes)
        }
        function pin(row: string) { TaskManagerPins.pin(JSON.parse(row)) }
        function unpin(row: string) { TaskManagerPins.unpin(JSON.parse(row)) }
        function toggle(row: string) { TaskManagerPins.toggle(JSON.parse(row)) }
        function reload() { TaskManagerPins.reload() }
    }
}
''')
        (self.work / 'runtime').mkdir(mode=0o700)
        self.environment = dict(os.environ, HOME=str(self.work), XDG_RUNTIME_DIR=str(self.work / 'runtime'),
            XDG_CACHE_HOME=str(self.work / 'cache'), QT_QPA_PLATFORM='offscreen',
            HAKUSPACE_TM_PINS_FILE=str(self.path), DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(self.work / 'no-bus'))
        for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
            self.environment.pop(name, None)
        self.log = (self.work / 'runtime.log').open('w')
        self.child = subprocess.Popen(['quickshell', '-p', str(self.work), '--no-color'],
            env=self.environment, stdout=self.log, stderr=self.log)
        self.addCleanup(self.stop)
        expected = [] if self._testMethodName == 'test_cold_storage' else ['7:100', '9:200']
        self.wait(lambda: self.state()['keys'] == expected)

    def stop(self):
        """Reap the private engine and retain diagnostics for a failed assertion."""
        self.child.terminate()
        self.child.wait(timeout=5)
        self.log.close()
        log = (self.work / 'runtime.log').read_text()
        Path('/tmp/task-manager-pins.log').write_text(log)
        self.assertNotRegex(log, r'ReferenceError|TypeError|Binding loop|Failed to load')

    def ipc(self, method, *args):
        """Address only this fixture's offscreen Quickshell instance."""
        return subprocess.check_output(['quickshell', '-p', str(self.work), 'ipc', '--any-display',
            'call', 'pins', method, *map(str, args)], env=self.environment, stderr=subprocess.STDOUT,
            text=True, timeout=3).strip()

    def state(self):
        """Observe public API values after asynchronous file changes."""
        return json.loads(self.ipc('state'))

    def wait(self, predicate):
        """Wait for file I/O or IPC readiness without assuming a timer duration."""
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
                pass
            time.sleep(0.03)
        self.fail((self.work / 'runtime.log').read_text())

    def frame(self, rows, ready=True, timestamp=None, warming=False, restart=False):
        """Publish a complete process model, including the warm-up boundary."""
        self.frame_number += 1
        if timestamp is None:
            timestamp = self.frame_number
        value = dict(rows=rows, ready=ready, timestamp=timestamp, warming=warming, restart=restart)
        self.assertEqual(json.loads(self.ipc('frame', json.dumps(value))), rows)

    def test_legacy_order_toggle_and_atomic_persistence(self):
        """Keep pin order, avoid duplicates and replace the pin file atomically."""
        first, second = {'key': '7:100', 'pid': 7}, {'key': '9:200', 'pid': 9}
        self.frame([second, first])
        self.assertEqual([row['key'] for row in self.state()['rows']], ['7:100', '9:200'], self.state())
        self.ipc('pin', json.dumps(first))
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        inode = self.path.stat().st_ino
        self.ipc('toggle', json.dumps(first))
        self.wait(lambda: json.loads(self.path.read_text()) == ['9:200'])
        self.assertNotEqual(self.path.stat().st_ino, inode)
        self.ipc('toggle', json.dumps(first))
        self.wait(lambda: json.loads(self.path.read_text()) == ['9:200', '7:100'])
        self.ipc('unpin', json.dumps(second))
        self.wait(lambda: json.loads(self.path.read_text()) == ['7:100'])

    def test_prune_only_after_complete_process_frame(self):
        """Shutdown and warm-up preserve pins; PID reuse never matches a former pin."""
        self.frame([], False, -1)
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.frame([], True, -1)
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.frame([{'key': '7:999', 'pid': 7}, {'key': '9:200', 'pid': 9}])
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.assertEqual([row['key'] for row in self.state()['rows']], ['9:200'])
        self.frame([{'key': '9:200', 'pid': 9}])
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.frame([{'key': '9:200', 'pid': 9}])
        self.wait(lambda: json.loads(self.path.read_text()) == ['9:200'])
        self.assertEqual(self.state()['keys'], ['9:200'])
        self.frame([])
        self.assertEqual(self.state()['keys'], ['9:200'])
        self.frame([])
        self.assertEqual(self.state()['keys'], ['9:200'])
        self.frame([])
        self.wait(lambda: json.loads(self.path.read_text()) == [])

    def test_reappearance_resets_grace_without_writing(self):
        """A temporary /proc miss and file reloads never alter the persisted pin set."""
        visible = [{'key': '7:100', 'pid': 7}, {'key': '9:200', 'pid': 9}]
        self.frame(visible)
        initial = self.path.stat()
        self.frame([])
        self.frame([])
        self.assertEqual(self.state()['misses'], {'7:100': 2, '9:200': 2})
        self.ipc('reload')
        self.assertEqual(self.state()['misses'], {'7:100': 2, '9:200': 2})
        self.assertEqual(self.path.stat().st_mtime_ns, initial.st_mtime_ns)
        self.assertEqual(self.path.stat().st_ino, initial.st_ino)
        self.frame(visible)
        self.assertEqual(self.state()['misses'], {})
        self.frame([])
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.assertEqual(self.state()['misses'], {'7:100': 1, '9:200': 1})
        self.assertEqual(self.path.stat().st_mtime_ns, initial.st_mtime_ns)

    def test_incomplete_duplicate_and_restart_frames_do_not_count(self):
        """Only distinct valid complete scans advance the three-frame threshold."""
        self.frame([])
        self.assertEqual(self.state()['misses']['7:100'], 1)
        self.frame([], timestamp=self.frame_number)
        self.assertEqual(self.state()['misses']['7:100'], 1)
        self.frame([{}])
        self.assertEqual(self.state()['misses']['7:100'], 1)
        self.frame([], warming=True)
        self.assertEqual(self.state()['misses'], {})
        self.frame([], restart=True)
        self.assertEqual(self.state()['misses'], {})
        self.frame([], ready=False, timestamp=-1)
        self.assertEqual(self.state()['misses'], {})
        self.frame([], ready=True, timestamp=-1)
        self.assertEqual(self.state()['misses'], {})
        self.frame([])
        self.assertEqual(self.state()['misses']['7:100'], 1)

    def test_malformed_file_and_unknown_process(self):
        """Reject broken files and unknown identities while retaining the valid model."""
        for value in ('broken', '{}', '[7]', '["9"]'):
            self.path.write_text(value)
            self.ipc('reload')
            self.wait(lambda: bool(self.state()['error']))
            self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.ipc('pin', '{"key":"99:100"}')
        self.assertEqual(self.state()['keys'], ['7:100', '9:200'])
        self.path.write_text('["9:200"]')
        self.ipc('reload')
        self.wait(lambda: self.state()['keys'] == ['9:200'] and not self.state()['error'])

    def test_cold_storage(self):
        """Create a missing state directory and persist the first pin without losing it."""
        row = {'key': '7:100', 'pid': 7}
        self.frame([row])
        self.ipc('pin', json.dumps(row))
        self.wait(lambda: self.path.exists() and json.loads(self.path.read_text()) == ['7:100'])
        self.assertFalse(self.state()['error'])


if __name__ == '__main__':
    unittest.main()
