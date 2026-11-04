#!/usr/bin/env python3
"""Run floating Task Manager lifecycle and input probes in a private compositor."""
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
import unittest

# Preserve production QML while isolating unrelated shell services and preferences.
ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'src/home/.config/quickshell/hakuspace'


def prepare(work, harness_name='task_manager.qml'):
    """Assemble the real overlay, service and Temp Note in a disposable QML tree."""
    shell = work / 'shell'
    shutil.copytree(SOURCE / 'config', shell / 'config')
    (shell / 'services').mkdir()
    (shell / 'components').mkdir()
    services = ['UiState', 'Theme', 'HAnimation', 'ShellTransitionState', 'TaskManagerService', 'TaskManagerPins']
    for name in services:
        shutil.copy2(SOURCE / f'services/{name}.qml', shell / f'services/{name}.qml')
    stubs = {
        'ChromeLayout': 'property bool dockbarActive: false; property bool taskbarMode: false',
        'AppState': 'property string shellBackend: "hikai"',
        'ScreenGeometry': '''property real leftInset: 4; property real rightInset: 4
            property real bottomInset: 4; property real topBorderThickness: 4
            property bool bottomAttached: false
            function chromeAttachmentY(screenHeight) { return 40 }''',
        'ShellSettingsStore': 'property string colorMode: "dark"; property string surfaceTone: "default"; property int baseRadius: 16',
        'Env': f'property string themeDir: ""; property string binDir: "{ROOT / "src/core/backend/system"}"',
        'FlareEdges': 'property real thickness: 4',
        'TextStore': 'property string scratchDraft: ""; function setScratchDraft(text) { scratchDraft = text } function flushScratch() {}',
    }
    for name, properties in stubs.items():
        (shell / f'services/{name}.qml').write_text(f'pragma Singleton\nimport QtQuick\nQtObject {{ {properties} }}\n')
    (shell / 'services/qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n' for name in services + list(stubs)))
    for name in ('editor', 'sidebar', 'motion', 'flare', 'base', 'taskmanager'):
        shutil.copytree(SOURCE / 'components' / name, shell / 'components' / name)
    (shell / 'components/settings').mkdir()
    shutil.copy2(SOURCE / 'components/settings/SettingsTooltip.qml', shell / 'components/settings/SettingsTooltip.qml')
    for name in ('TaskManagerOverlay', 'TaskManagerHost', 'TempNoteOverlay'):
        shutil.copy2(SOURCE / f'components/{name}.qml', shell / f'components/{name}.qml')
    harness = (Path(__file__).with_name('harness') / harness_name).read_text()
    if '/*SETTINGS_MASK*/' in harness:
        settings = (SOURCE / 'components/SettingsPanel.qml').read_text()
        mask = settings[settings.index('    mask: Region {'):settings.index('    Component.onDestruction:')]
        harness = harness.replace('/*SETTINGS_MASK*/', mask.replace('root.', 'settingsProbe.'))
    (shell / 'shell.qml').write_text(harness)
    return shell


class QmlTest(unittest.TestCase):
    """Use real collectors and Qt events without taking over the user's desktop."""

    def _run_harness(self, harness_name, expected_marker, log_path, reduced=False, size=None, scale=1):
        with tempfile.TemporaryDirectory(prefix='hikai-task-manager-') as directory:
            work = Path(directory)
            shell = prepare(work, harness_name)
            (work / 'runtime').mkdir(mode=0o700)
            (work / 'labwc').mkdir()
            (work / 'labwc/rc.xml').write_text('<labwc_config/>\n')
            environment = dict(os.environ, HOME=str(work), XDG_RUNTIME_DIR=str(work / 'runtime'),
                XDG_CONFIG_HOME=str(work / 'config-home'), XDG_CACHE_HOME=str(work / 'cache'),
                DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(work / 'no-session-bus'),
                WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='2', WLR_RENDERER='pixman',
                QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software', QT_IM_MODULE='compose',
                HAKUSPACE_REDUCED_MOTION='1' if reduced else '0',
                TASK_MANAGER_INPUT_DIR=str(ROOT / 'tests/support/fixtures'))
            for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
                environment.pop(name, None)
            launch = ['quickshell', '-p', str(shell / 'shell.qml'), '--no-color']
            if size:
                width, height = size
                configure = ['wlr-randr', '--output', 'HEADLESS-1', '--custom-mode', f'{width}x{height}', '--scale', str(scale),
                    '--output', 'HEADLESS-2', '--custom-mode', '1024x768', '--pos', f'{width},0']
                launch = ['sh', '-c', shlex.join(configure) + ' && exec ' + shlex.join(launch)]
            with subprocess.Popen(['labwc', '-C', str(work / 'labwc'), '-S', shlex.join(launch)],
                env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True) as child:
                try:
                    stdout, stderr = child.communicate(timeout=55)
                finally:
                    try:
                        os.killpg(child.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    child.wait(timeout=3)
            log = stdout + stderr
            Path(log_path).write_text(log)
            self.assertEqual(child.returncode, 0, log[-10000:])
            self.assertIn(expected_marker, log[-10000:])
            self.assertNotRegex(log, r'ReferenceError|TypeError|Binding loop|Unable to assign|Failed to load')

    @unittest.skipUnless(shutil.which('labwc') and shutil.which('quickshell'), 'Labwc and Quickshell required')
    def test_floating_lifecycle(self):
        """Exercise ownership, keyboard, geometry, actions and twenty complete releases."""
        self._run_harness('task_manager.qml', 'Task Manager QML passed', '/tmp/hikai-task-manager-qml.log')

    @unittest.skipUnless(shutil.which('labwc') and shutil.which('quickshell'), 'Labwc and Quickshell required')
    def test_glass_grid_style(self):
        """Exercise Focus Card switching, reset semantics, responsive sizes and light/dark themes."""
        self._run_harness('glass_grid.qml', 'Glass Grid harness passed', '/tmp/hikai-task-manager-glass-grid.log')

    @unittest.skipUnless(shutil.which('labwc') and shutil.which('quickshell'), 'Labwc and Quickshell required')
    def test_metric_layout(self):
        """Keep full Swap values at narrow card widths and enlarged fonts across guest scales."""
        for size, scale in (((1280, 720), 1), ((1366, 768), 1), ((1920, 1080), 1), ((1920, 1080), 1.25)):
            self._run_harness('metric_layout.qml', 'Metric layout sampled: 0/12 truncated',
                f'/tmp/hikai-metric-{size[0]}-{scale}.log', size=size, scale=scale)

    @unittest.skipUnless(shutil.which('labwc') and shutil.which('quickshell'), 'Labwc and Quickshell required')
    def test_ui_polish(self):
        """Check tooltip delay and a single scrolling selection pill with both motion modes."""
        for size in ((1280, 720), (1920, 1080)):
            for reduced in (False, True):
                self._run_harness('polish.qml', 'Task Manager polish passed',
                    f'/tmp/hikai-task-manager-polish-{size[0]}-{int(reduced)}.log', reduced, size)


if __name__ == '__main__':
    unittest.main()
