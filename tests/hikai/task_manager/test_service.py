#!/usr/bin/env python3
"""Exercise the production service with real children and isolated Quickshell IPC."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'src/home/.config/quickshell/hakuspace'


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class ServiceTest(unittest.TestCase):
    """Keep each service, collector and failure fixture in one private session."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='task-manager-service-')
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        services = self.work / 'services'
        services.mkdir()
        source = Path(os.environ.get('TASK_MANAGER_SERVICE_SOURCE', SOURCE / 'services/TaskManagerService.qml'))
        shutil.copy2(source, services / 'TaskManagerService.qml')
        (services / 'AppState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string shellBackend: "hikai" }\n')
        (services / 'Env.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string binDir: '
            + json.dumps(str(self.work)) + ' }\n')
        (services / 'Theme.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { '
            'property color accent: "blue"; property color overlayInk: "white"; property bool isLight: false }\n')
        (services / 'qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n'
            for name in ('TaskManagerService', 'AppState', 'Env', 'Theme')))
        charts = self.work / 'components/taskmanager/glassgrid'
        charts.mkdir(parents=True)
        shutil.copy2(SOURCE / 'components/taskmanager/glassgrid/TaskSparkline.qml', charts / 'TaskSparkline.qml')
        (self.work / 'task_manager_monitor.py').write_text('import json,os,sys,time\nfrom pathlib import Path\n'
            'root = Path(__file__).parent\n'
            'previous = [json.loads(line) for line in (root / "starts").read_text().splitlines()] if (root / "starts").exists() else []\n'
            'alive = [row["pid"] for row in previous if Path(f"/proc/{row[\"pid\"]}").exists()]\n'
            'with (root / "starts").open("a") as log:\n'
            '    log.write(json.dumps(dict(pid=os.getpid(), startTime=int(Path("/proc/self/stat").read_text().rsplit(")", 1)[1].split()[19]), t=time.monotonic(), args=sys.argv[1:], overlap=alive)) + "\\n")\n'
            'if (root / "fail").exists(): raise SystemExit(7)\n'
            + f'os.execv(sys.executable, [sys.executable, {str(ROOT / "src/core/backend/system/task_manager_monitor.py")!r}] + sys.argv[1:])\n')
        (self.work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/taskmanager/glassgrid" as Charts
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Charts.TaskSparkline { id: sparkline; history: TaskManagerService.history }
    IpcHandler {
        target: "probe"
        function open() { TaskManagerService.acquire() }
        function close() { TaskManagerService.release() }
        function interval(ms: int) { TaskManagerService.setIntervalMs(ms) }
        function rapid(close: bool) {
            TaskManagerService.setIntervalMs(900)
            TaskManagerService.setIntervalMs(800)
            TaskManagerService.setIntervalMs(700)
            if (close) TaskManagerService.release()
        }
        function restartClose() {
            TaskManagerService.setIntervalMs(TaskManagerService.intervalMs === 500 ? 1000 : 500)
            TaskManagerService.release()
        }
        function reopen() {
            TaskManagerService.release()
            TaskManagerService.acquire()
        }
        function bounds(): string {
            var values = []
            for (var ms of [-10, 250, 9999, NaN, Infinity]) {
                TaskManagerService.setIntervalMs(ms)
                values.push(TaskManagerService.intervalMs)
            }
            return JSON.stringify(values)
        }
        function frames(): string {
            TaskManagerService.snapshot = ({})
            TaskManagerService.history = []
            TaskManagerService.processes = []
            TaskManagerService.processTimestamp = -1
            var row = {pid: 1234, startTime: 100, key: "1234:100"}
            var base = {schema: 1, seq: 1, cpu: {usage: 20}, memory: {percent: 30},
                gpus: [], network: {all: {}}, disks: {}}
            var values = [
                Object.assign({}, base, {monotonicMs: 1000, processMonotonicMs: 1000, processes: [row]}),
                Object.assign({}, base, {monotonicMs: 1500, processMonotonicMs: 1000}),
                Object.assign({}, base, {monotonicMs: 2000, processMonotonicMs: 2000, processes: [row]}),
                Object.assign({}, base, {monotonicMs: 1900, processMonotonicMs: 1900, processes: []}),
                Object.assign({}, base, {monotonicMs: 2500, processMonotonicMs: 2000, processes: null}),
                Object.assign({}, base, {monotonicMs: 3000, processMonotonicMs: 2000, processes: []})
            ]
            var results = []
            for (var i = 0; i < values.length; i++) {
                var previous = TaskManagerService.processes
                TaskManagerService.receive(JSON.stringify(values[i]))
                results.push({same: previous === TaskManagerService.processes,
                    monotonicMs: TaskManagerService.snapshot.monotonicMs,
                    timestamp: TaskManagerService.processTimestamp, processes: TaskManagerService.processes,
                    error: TaskManagerService.error})
            }
            return JSON.stringify(results)
        }
        function history(ms: int): string {
            TaskManagerService.snapshot = ({})
            TaskManagerService.history = []
            for (var t = 1000; t <= 71000; t += ms) {
                TaskManagerService.receive(JSON.stringify({schema: 1, seq: 1, monotonicMs: t,
                    processMonotonicMs: 1000, cpu: {}, memory: {percent: 30}, gpus: [], network: {}, disks: {}}))
            }
            return JSON.stringify({history: TaskManagerService.history, series: sparkline.primarySeries})
        }
        function status(): string { return JSON.stringify(TaskManagerService.status()) }
        function identity(): string {
            return JSON.stringify(TaskManagerService.processes.find(row => row.pid === Quickshell.processId))
        }
        function capabilities(): string { return JSON.stringify(TaskManagerService.snapshot.capabilities || {}) }
    }
}
''')
        (self.work / 'runtime').mkdir(mode=0o700)
        self.environment = dict(os.environ, XDG_RUNTIME_DIR=str(self.work / 'runtime'),
            XDG_CACHE_HOME=str(self.work / 'cache'), QT_QPA_PLATFORM='offscreen',
            DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(self.work / 'no-bus'))
        for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
            self.environment.pop(name, None)
        self.log = (self.work / 'runtime.log').open('w')
        self.child = subprocess.Popen(['quickshell', '-p', str(self.work), '--no-color'],
            env=self.environment, stdout=self.log, stderr=self.log)
        self.addCleanup(self.stop)
        self.events = []
        self.wait(lambda: self.status() is not None)

    def stop(self):
        """Reap test children even when a lifecycle assertion fails."""
        self.child.terminate()
        self.child.wait(timeout=5)
        # Pin leftover fixture lifetimes before cleanup; historical PIDs may be reused.
        for row in self.starts():
            descriptor = None
            try:
                descriptor = os.pidfd_open(row['pid'])
                fields = Path(f'/proc/{row["pid"]}/stat').read_text().rsplit(')', 1)[1].split()
                if int(fields[19]) == row['startTime']:
                    signal.pidfd_send_signal(descriptor, signal.SIGTERM)
            except (OSError, AttributeError):
                pass
            finally:
                if descriptor is not None:
                    os.close(descriptor)
        self.log.close()
        artifact = dict(starts=self.starts(), events=self.events,
            log=(self.work / 'runtime.log').read_text())
        Path(f'/tmp/hikai-task-manager-{self._testMethodName}.json').write_text(json.dumps(artifact, indent=2))

    def ipc(self, method, *args):
        """Address only the private service instance."""
        return subprocess.check_output(['quickshell', '-p', str(self.work), 'ipc', '--any-display',
            'call', 'probe', method, *map(str, args)], env=self.environment, stderr=subprocess.DEVNULL,
            text=True, timeout=3).strip()

    def status(self):
        """Read observable collector ownership rather than assuming timer completion."""
        return json.loads(self.ipc('status'))

    def wait(self, predicate):
        """Allow scheduling and process exit with a bounded observable deadline."""
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            if self.child.poll() is not None:
                self.fail((self.work / 'runtime.log').read_text())
            try:
                if predicate():
                    return
            except subprocess.CalledProcessError:
                pass
            time.sleep(0.02)
        self.fail('service timeout: ' + self.ipc('status'))

    def starts(self):
        """Read PID, start time, interval and overlap evidence from the child wrapper."""
        path = self.work / 'starts'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def record(self, phase):
        """Capture subscription ownership and all direct child PIDs at each transition."""
        children = set()
        for task in Path(f'/proc/{self.child.pid}/task').iterdir():
            children.update((task / 'children').read_text().split())
        event = dict(phase=phase, t=time.monotonic(), children=sorted(children),
            fdCount=len(list(Path(f'/proc/{self.child.pid}/fd').iterdir())), **self.status())
        self.events.append(event)
        self.assertLessEqual(len(children), 1, event)
        return event

    def open(self):
        """Wait for the first live snapshot from one collector."""
        self.ipc('open')
        self.wait(lambda: self.status()['ready'])
        return self.record('open')['collectorPid']

    def closed(self, pid):
        """Require zero service children after the last subscriber releases."""
        self.wait(lambda: not self.status()['collectorRunning'] and not Path(f'/proc/{pid}').exists())
        event = self.record('closed')
        self.assertFalse(event['children'], event)
        self.assertEqual(event['subscribers'], 0)
        self.assertFalse(event['error'], event)
        self.assertFalse(event.get('restartPending'), event)
        self.assertTrue(all(not row['overlap'] for row in self.starts()), self.starts())

    def test_interval_restart_and_close(self):
        """Restart once with the newest interval, retain history and release the new PID."""
        old = self.open()
        identity = json.loads(self.ipc('identity'))['key']
        before = self.status()['monotonicMs']
        self.ipc('interval', 500)
        self.wait(lambda: self.status()['collectorPid'] not in (0, old) and self.status()['monotonicMs'] > before)
        state = self.record('restarted')
        self.assertFalse(Path(f'/proc/{old}').exists())
        self.assertFalse(state['error'], state)
        self.assertGreaterEqual(state['historyCount'], 2)
        self.assertEqual(json.loads(self.ipc('identity'))['key'], identity)
        self.assertIn('processControl', json.loads(self.ipc('capabilities')))
        count = len(self.starts())
        self.ipc('rapid', 'false')
        self.wait(lambda: len(self.starts()) > count and not self.status().get('restartPending'))
        self.assertEqual(len(self.starts()), count + 1)
        self.assertEqual(self.starts()[-1]['args'][-1], '700')
        pid = self.record('rapid-restarted')['collectorPid']
        self.ipc('close')
        self.closed(pid)
        time.sleep(0.2)
        self.assertFalse(self.record('settled')['children'])

    def test_twenty_cycles_per_restart_mode(self):
        """Check ordinary close, changed intervals and immediate close for twenty cycles each."""
        for mode in ('ordinary', 'interval', 'immediate'):
            fds = []
            for cycle in range(20):
                pid = self.open()
                if mode == 'interval':
                    interval = (500, 2000, 300, 1000)[cycle % 4]
                    self.ipc('interval', interval)
                    self.wait(lambda: self.status()['collectorPid'] not in (0, pid) and self.status()['ready'])
                    self.assertFalse(Path(f'/proc/{pid}').exists())
                    pid = self.record('interval')['collectorPid']
                    self.ipc('close')
                elif mode == 'immediate':
                    self.ipc('rapid' if cycle % 2 else 'restartClose', *(['true'] if cycle % 2 else []))
                else:
                    self.ipc('close')
                self.closed(pid)
                fds.append(self.events[-1]['fdCount'])
            self.assertFalse(all(b > a for a, b in zip(fds, fds[1:])), fds)
            self.assertLessEqual(fds[-1], fds[0] + 1, fds)

    def test_crash_and_start_failure_do_not_loop(self):
        """Expose unexpected exits and invalidate live capabilities without respawning."""
        pid = self.open()
        os.kill(pid, signal.SIGKILL)
        self.wait(lambda: bool(self.status()['error']))
        count = len(self.starts())
        time.sleep(0.3)
        self.assertEqual(len(self.starts()), count)
        self.assertFalse(self.status()['ready'])
        self.assertEqual(json.loads(self.ipc('capabilities')), {})
        self.ipc('close')
        self.closed(pid)
        (self.work / 'fail').touch()
        self.ipc('open')
        self.wait(lambda: 'exit 7' in self.status()['error'])
        count = len(self.starts())
        time.sleep(0.3)
        self.assertEqual(len(self.starts()), count)
        self.assertFalse(self.record('failed')['children'])
        self.ipc('close')
        (self.work / 'fail').unlink()
        self.ipc('interval', 100)
        pid = self.open()
        (self.work / 'fail').touch()
        self.ipc('interval', 500)
        self.wait(lambda: 'exit 7' in self.status()['error'])
        self.assertFalse(self.status()['ready'])
        self.assertEqual(json.loads(self.ipc('capabilities')), {})
        count = len(self.starts())
        time.sleep(0.3)
        self.assertEqual(len(self.starts()), count)
        self.ipc('close')
        self.closed(pid)

    def test_payload_timestamp_and_time_history(self):
        """Omitted payloads preserve model identity; pruning follows time across cadence changes."""
        pid = self.open()
        results = json.loads(self.ipc('frames'))
        self.assertTrue(all(not result['error'] for result in results))
        self.assertEqual([r['same'] for r in results], [False, True, False, True, True, True])
        self.assertEqual([r['monotonicMs'] for r in results], [1000, 1500, 2000, 2000, 2500, 3000])
        self.assertEqual([r['timestamp'] for r in results], [1000, 1000, 2000, 2000, 2000, 2000])
        self.assertTrue(all(r['processes'][0]['key'] == '1234:100' for r in results))
        for interval in (100, 500, 1000, 2000):
            result = json.loads(self.ipc('history', interval))
            history, series = result['history'], result['series']
            self.assertEqual(history[-1]['t'] - history[0]['t'], 60000)
            self.assertLessEqual(len(history), 800)
            self.assertEqual(series[-1]['t'] - series[0]['t'], 30000)
            self.assertEqual(len(series), 30000 // interval + 1)
        self.ipc('close')
        self.closed(pid)

    def test_declarative_running_binding(self):
        """Reject direct writes that detach process ownership from demand."""
        text = (self.work / 'services/TaskManagerService.qml').read_text()
        self.assertNotRegex(text, r'monitor\.running\s*=')
        self.assertEqual(json.loads(self.ipc('bounds')), [100, 300, 2000, 2000, 2000])
        self.assertFalse(self.starts())

    def test_reopen_before_previous_exit(self):
        """A synchronous release/reacquire waits for the former child to exit."""
        pid = self.open()
        count = len(self.starts())
        self.ipc('reopen')
        self.wait(lambda: len(self.starts()) == count + 1 and self.status()['ready'])
        self.assertFalse(Path(f'/proc/{pid}').exists())
        pid = self.record('reopened')['collectorPid']
        self.ipc('close')
        self.closed(pid)


if __name__ == '__main__':
    unittest.main()
