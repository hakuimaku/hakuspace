#!/usr/bin/env python3
"""Measure a disposable Task Manager with the shared Hikai live-PID sampler."""
import argparse
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time

from test_qml import ROOT, SOURCE, prepare

# Reuse production sampling and report math without changing the global profiler.
sys.path.insert(0, str(ROOT / 'tools/profiling'))
from hikai_memory_soak import measure, sample


def run(args):
    """Collect matched baseline/open/closed intervals and two batches of ten cycles."""
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='task-manager-profile-') as temporary:
        work = Path(temporary)
        shell = prepare(work)
        profile = (Path(__file__).with_name('harness') / 'profile.qml').read_text()
        production = (SOURCE / 'shell.qml').read_text()
        ipc = production[production.index('    // Task Manager remains'):production.index('    // Toggle only the floating note')]
        surfaces = (SOURCE / 'components/EphemeralSurfaces.qml').read_text()
        loader_start = surfaces.index('    Base.LifecycleLoader {\n        id: taskManager')
        loader_end = surfaces.index('    Base.LifecycleLoader {', loader_start + 8)
        loader = surfaces[loader_start:loader_end].replace('root.modelData', 'profileHost.modelData')
        (shell / 'shell.qml').write_text(profile.replace('/*TASK_MANAGER_IPC*/', ipc).replace('/*TASK_MANAGER_LOADER*/', loader))
        environment = dict(os.environ, HOME=str(work), XDG_CONFIG_HOME=str(work / 'config'),
                           XDG_CACHE_HOME=str(work / 'cache'), DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(work / 'no-bus'),
                           QSG_INFO='1')
        for name in ('QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
            environment.pop(name, None)
        if args.hardware:
            # Use the current Wayland output without changing the user's shell or input.
            environment.pop('QT_QUICK_BACKEND', None)
            environment.pop('QSG_RHI_BACKEND', None)
            environment['QT_QPA_PLATFORM'] = 'wayland'
            command = ['quickshell', '-p', str(shell), '--no-color']
        else:
            (work / 'runtime').mkdir(mode=0o700)
            (work / 'labwc').mkdir()
            (work / 'labwc/rc.xml').write_text('<labwc_config/>\n')
            environment.update(XDG_RUNTIME_DIR=str(work / 'runtime'), WLR_BACKENDS='headless',
                               WLR_HEADLESS_OUTPUTS='2', WLR_RENDERER='pixman',
                               QT_QUICK_BACKEND='software', QT_QPA_PLATFORM='wayland')
            for name in ('WAYLAND_DISPLAY', 'DISPLAY'):
                environment.pop(name, None)
            command = ['labwc', '-C', str(work / 'labwc'), '-S', shlex.join(['quickshell', '-p', str(shell), '--no-color'])]
        with (args.output / 'runtime.log').open('w') as log:
            child = subprocess.Popen(command, env=environment, stdout=log, stderr=log, start_new_session=True)
            try:
                def ipc_call(target, method, *values):
                    """Select only this profile's unique config, including its private display."""
                    return subprocess.check_output(['quickshell', '-p', str(shell), 'ipc', '--any-display',
                        'call', target, method, *values], env=environment, stderr=subprocess.DEVNULL, text=True, timeout=5).strip()

                def status():
                    """Read the production Task Manager diagnostic endpoint."""
                    return json.loads(ipc_call('taskManager', 'status'))

                def wait_for(predicate):
                    """Wait for observable lifecycle completion with a bounded deadline."""
                    deadline = time.monotonic() + 8
                    while time.monotonic() < deadline:
                        try:
                            if predicate():
                                return
                        except subprocess.CalledProcessError:
                            if child.poll() is not None:
                                raise RuntimeError('profile exited; see runtime.log')
                        time.sleep(0.05)
                    raise RuntimeError('profile timed out; see runtime.log')

                wait_for(lambda: bool(ipc_call('taskManagerProfile', 'diagnostics')))
                diagnostics = json.loads(ipc_call('taskManagerProfile', 'diagnostics'))
                pid = diagnostics['pid']
                result = {'renderer': 'default-hardware-session' if args.hardware else 'software',
                          'screens': diagnostics['screens'], 'cycles': [], 'checkpoints': []}

                def observe(name, observed_pid):
                    """Use the existing soak sampler for matched short live-PID observations."""
                    options = argparse.Namespace(software=not args.hardware, outputs=len(diagnostics['screens']),
                        warmup=args.warmup, seconds=args.seconds, cycles=0, notifications=0, backend='hikai',
                        lock_profile=None, interval=1, output=args.output / (name + '.json'))
                    measure(observed_pid, options)
                    return json.loads(options.output.read_text())

                result['baseline'] = observe('baseline', pid)
                started = time.monotonic()
                ipc_call('taskManager', 'openDefault')
                wait_for(lambda: status()['ready'])
                result['readyLatencyMs'] = round((time.monotonic() - started) * 1000, 2)
                collector = status()['collectorPid']
                result['open'] = observe('open', pid)
                result['collector'] = observe('collector', collector)
                result['telemetry'] = json.loads(ipc_call('taskManagerProfile', 'diagnostics'))['snapshot']
                ipc_call('taskManager', 'close')
                wait_for(lambda: status()['subscribers'] == 0 and not Path(f'/proc/{collector}').exists())
                result['closed'] = observe('closed', pid)
                result['checkpoints'].append({'batch': 0, **sample(pid)})
                for batch in (1, 2):
                    for index in range(10):
                        ipc_call('taskManager', 'openDefault')
                        wait_for(lambda: status()['ready'])
                        collector = status()['collectorPid']
                        time.sleep(0.2)
                        ipc_call('taskManager', 'close')
                        wait_for(lambda: status()['subscribers'] == 0 and not Path(f'/proc/{collector}').exists())
                        state = status()
                        assert not state['collectorRunning'] and not state['processCount'] and not state['historyCount'], state
                        result['cycles'].append(state)
                    time.sleep(args.warmup)
                    result['checkpoints'].append({'batch': batch, **sample(pid)})
                result['settled'] = observe('settled', pid)
                result['complete'] = True
                (args.output / 'report.json').write_text(json.dumps(result, indent=2) + '\n')
                print(json.dumps({key: result[key] for key in ('renderer', 'screens', 'readyLatencyMs', 'checkpoints', 'complete')}, indent=2))
                ipc_call('taskManagerProfile', 'quit')
                child.wait(timeout=5)
            finally:
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGTERM)
                    child.wait(timeout=5)
        errors = ('TypeError', 'ReferenceError', 'Binding loop', 'Failed to load configuration')
        assert not any(error in (args.output / 'runtime.log').read_text() for error in errors), 'QML error in runtime.log'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hardware', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seconds', type=float, default=5)
    parser.add_argument('--warmup', type=float, default=2)
    run(parser.parse_args())
