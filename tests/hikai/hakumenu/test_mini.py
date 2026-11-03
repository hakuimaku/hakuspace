#!/usr/bin/env python3
"""Probe embedded Task Manager in isolated, software-rendered Wayland outputs."""
import os
import json
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

# Reuse the Task Manager fixture's real content, service and isolated preferences.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'task_manager'))
from test_qml import prepare, SOURCE, ROOT


@unittest.skipUnless(shutil.which('labwc') and shutil.which('quickshell'), 'Labwc and Quickshell required')
class MiniTest(unittest.TestCase):
    """Cover only HakuMenu hosts and the Task Manager presentation they embed."""

    def run_mini(self, width, height, reduced=False, harness_name='mini.qml'):
        """Run production hosts with controlled chrome topology and real collectors."""
        with tempfile.TemporaryDirectory(prefix='haku-mini-') as directory:
            work = Path(directory)
            shell = prepare(work, str(Path(__file__).with_name('harness') / harness_name))
            shutil.copytree(SOURCE / 'components/hakumenu', shell / 'components/hakumenu')
            shutil.copy2(SOURCE / 'components/HakuMenuPanel.qml', shell / 'components/HakuMenuPanel.qml')
            for name in ('ScreenGeometry.qml', 'ScreenGeometry.js', 'Interaction.qml', 'GeneralMenuService.qml'):
                shutil.copy2(SOURCE / 'services' / name, shell / 'services' / name)
            shutil.copy2(SOURCE / 'components/settings/SettingsActionButton.qml', shell / 'components/settings/SettingsActionButton.qml')
            stubs = {
                'ChromeLayout': '''property bool topBarMode: true
                    property bool taskbarMode: !topBarMode
                    property bool dockbarActive: false
                    property bool topStatusBarVisible: topBarMode
                    property bool topEdgeHakuMenuEnabled: false
                    property string defaultHakuMenuPresentation: taskbarMode ? "bottomFlare" : "topFlare"''',
                'AppState': 'property string shellBackend: "hikai"; property bool taskbarManualState: false; property bool dockbarManualState: false',
                'TooltipManager': 'function dismiss() {}',
                'ShellSettingsStore': '''property string colorMode: "dark"; property string surfaceTone: "default"
                    property int baseRadius: 16; property int roundedScreenRadius: 16
                    property int roundedScreenBorderThickness: 4; property int dockIconSize: 48
                    property bool dockExclusiveSpace: false; property bool ready: true
                    property bool loading: false; property bool saving: false; property string error: ""''',
                'Env': f'''property string themeDir: ""; property string stateShellBackend: "{work / "backend"}"
                    property string stateCavaEnabled: ""; property string stateCavaDynamicPosition: ""
                    property string stateCavaColorMode: ""; property string stateDesktopIconsEnabled: ""
                    property string binDir: "{work / "bin"}"''',
            }
            for name, properties in stubs.items():
                (shell / f'services/{name}.qml').write_text(f'pragma Singleton\nimport QtQuick\nQtObject {{ {properties} }}\n')
            with (shell / 'services/qmldir').open('a') as stream:
                stream.write('singleton Interaction 1.0 Interaction.qml\nsingleton TooltipManager 1.0 TooltipManager.qml\nsingleton GeneralMenuService 1.0 GeneralMenuService.qml\n')
            (work / 'bin').mkdir()
            (work / 'backend').write_text('hikai\n')
            for name in ('task_manager_monitor.py', 'task_manager_ctl.py'):
                (work / 'bin' / name).symlink_to(ROOT / 'src/core/backend/system' / name)
            # Supply the real General backend and seed instead of legacy stdout rows.
            (work / 'bin/general_menu_ctl.py').symlink_to(ROOT / 'src/core/backend/user/general_menu_ctl.py')
            (work / 'hakucfg/config').mkdir(parents=True)
            shutil.copy2(ROOT / 'src/home/hakucfg/config/hakumenu-general.json', work / 'hakucfg/config/hakumenu-general.json')
            (work / 'runtime').mkdir(mode=0o700)
            (work / 'labwc').mkdir()
            (work / 'labwc/rc.xml').write_text('<labwc_config/>\n')
            environment = dict(os.environ, HOME=str(work), XDG_RUNTIME_DIR=str(work / 'runtime'),
                XDG_CONFIG_HOME=str(work / 'config-home'), XDG_CACHE_HOME=str(work / 'cache'),
                DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(work / 'no-bus'),
                WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='2', WLR_RENDERER='pixman',
                QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software', QT_IM_MODULE='compose',
                HAKUSPACE_TEST_KEYBOARD=str(ROOT / 'tests/support/fixtures/wayland_keyboard.py'),
                HAKUSPACE_MEMORY_SAMPLER=str(ROOT / 'tools/profiling/hikai_memory_soak.py'),
                HAKUSPACE_MINI_PROFILE=f'/tmp/haku-mini-{width}-{int(reduced)}',
                HAKUSPACE_REDUCED_MOTION='1' if reduced else '0', HAKUSPACE_MINI_ARTIFACT=f'/tmp/haku-mini-{width}-{int(reduced)}.png')
            for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
                environment.pop(name, None)
            configure = ['wlr-randr', '--output', 'HEADLESS-1', '--custom-mode', f'{width}x{height}',
                         '--output', 'HEADLESS-2', '--custom-mode', '1024x768', '--pos', f'{width},0']
            command = shlex.join(configure) + ' && ' + shlex.join(['quickshell', '-p', str(shell / 'shell.qml'), '--no-color'])
            with subprocess.Popen(['labwc', '-C', str(work / 'labwc'), '-S', shlex.join(['sh', '-c', command])], env=environment,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True) as child:
                try:
                    stdout, stderr = child.communicate(timeout=210 if harness_name == 'handoff.qml' else 105)
                finally:
                    try:
                        os.killpg(child.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    child.wait(timeout=3)
            log = stdout + stderr
            log_path = f'/tmp/haku-{Path(harness_name).stem}-{width}-{int(reduced)}.log'
            Path(log_path).write_text(log)
            self.assertEqual(child.returncode, 0, log[-12000:])
            self.assertIn('HakuMenu Mini passed', log)
            self.assertNotRegex(log, r'ReferenceError|TypeError|Binding loop|Unable to assign|Failed to load|QML.*Error')
            if harness_name in ('hover.qml', 'unpin.qml', 'material.qml'):
                return
            if harness_name == 'handoff.qml':
                self.assertEqual(log.count('Handoff evidence '), 60)
                return
            if harness_name == 'dock.qml':
                self.assertEqual(log.count('Dock reopen evidence '), 10)
                return
            for style in range(3):
                before, after = [json.loads(Path(f'/tmp/haku-mini-{width}-{int(reduced)}-{style}-{stage}.json').read_text())['samples'][-1]
                                 for stage in ('before', 'after')]
                for counter in ('fdCount', 'threadCount', 'childCount'):
                    self.assertLessEqual(after[counter], before[counter] + 1, (style, counter, before, after))

    def test_hover(self):
        """Check surface hover, paused gauge repaint and reduced motion at both output sizes."""
        for width, height in ((1280, 720), (1920, 1080)):
            for reduced in (False, True):
                self.run_mini(width, height, reduced, harness_name='hover.qml')

    def test_unpin_confirmation(self):
        """Reveal an explicit unpin action and keep row-background activation non-destructive."""
        for reduced in (False, True):
            self.run_mini(1280, 720, reduced, harness_name='unpin.qml')

    def test_material_hover(self):
        """Check pointer-reactive material state at both sizes and motion modes."""
        for width, height in ((1280, 720), (1920, 1080)):
            for reduced in (False, True):
                self.run_mini(width, height, reduced, harness_name='material.qml')

    def test_full_hd(self):
        """Check all three hosts, transfers and coexistence at 1920×1080."""
        self.run_mini(1920, 1080)

    def test_hd(self):
        """Check compact layouts at 1280×720."""
        self.run_mini(1280, 720)

    def test_handoff_continuity(self):
        """Keep collector/model/telemetry alive through 20 transfers per host and cleanup failures."""
        self.run_mini(1280, 720, harness_name='handoff.qml')

    def test_dock_reopen(self):
        """Check generic morphs and normal-motion bottom reopen cycles."""
        self.run_mini(1024, 768, harness_name='dock.qml')

    def test_dock_reopen_reduced_motion(self):
        """Check reduced-motion bottom reopen cycles without stale teardown."""
        self.run_mini(1024, 768, True, harness_name='dock.qml')

    def test_handoff_reduced_motion(self):
        """Keep the collector continuous through reduced-motion transfers."""
        self.run_mini(1280, 720, True, harness_name='handoff.qml')

    def test_reduced_motion(self):
        """Verify the same state and ownership contracts with motion disabled."""
        self.run_mini(1280, 720, True)


if __name__ == '__main__':
    unittest.main()
