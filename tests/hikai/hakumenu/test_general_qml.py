#!/usr/bin/env python3
"""Run General service and list integration with real JSON storage in an isolated HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

# Copy only the General view, its service and existing visual dependencies.
ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'src/home/.config/quickshell/hakuspace'


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class GeneralQmlTests(unittest.TestCase):
    """Use the offscreen software renderer; this is a functional API probe, not a GPU benchmark."""

    def run_harness(self, harness_name, marker, reduced=False):
        """Run a General-only harness with actual services and isolated unrelated pages."""
        with tempfile.TemporaryDirectory(prefix='haku-general-qml-') as directory:
            work = Path(directory)
            shell = work / 'shell'
            (shell / 'services').mkdir(parents=True)
            (shell / 'components/hakumenu').mkdir(parents=True)
            shutil.copytree(SOURCE / 'config', shell / 'config')
            shutil.copytree(SOURCE / 'components/motion', shell / 'components/motion')
            for name in ('GeneralList.qml', 'GeneralDivider.qml', 'GeneralItemEditor.qml', 'HakuMenuContent.qml', 'HakuMenuRoot.qml'):
                shutil.copy2(SOURCE / 'components/hakumenu' / name, shell / 'components/hakumenu' / name)
            # Isolate pages compiled by the host but never exercised here.
            page_stub = 'import QtQuick\nItem { property string query: ""; property color rowHoverColor; property color rowSelectedColor; signal highlightedLabelChanged(string label); function moveSelection(delta) {} function activateCurrent() {} '
            (shell / 'components/hakumenu/DrunList.qml').write_text(page_stub + 'signal launched() }\n')
            (shell / 'components/hakumenu/ThemeList.qml').write_text(page_stub + 'property real leftColumnWidth; property real stateColumnWidth; property real columnGap; signal wallpaperRequested(); signal launched(bool closeMenu) }\n')
            (shell / 'components/taskmanager').mkdir()
            (shell / 'components/taskmanager/TaskManagerMini.qml').write_text('import QtQuick\nItem { property bool active; property bool interactionOwned; property bool reducedMotion; property QtObject content: QtObject { property real implicitHeight: 0 }; function forcePrimaryFocus() {} function clearPrimaryFocus() {} }\n')
            (shell / 'components/base').mkdir()
            shutil.copy2(SOURCE / 'components/base/LifecycleLoader.qml', shell / 'components/base/LifecycleLoader.qml')
            (shell / 'components/settings').mkdir()
            for name in ('SettingsActionButton.qml', 'SettingsTooltip.qml'):
                shutil.copy2(SOURCE / 'components/settings' / name, shell / 'components/settings' / name)
            services = ('GeneralMenuService', 'Theme', 'HAnimation')
            for name in services:
                shutil.copy2(SOURCE / f'services/{name}.qml', shell / f'services/{name}.qml')
            stubs = {
                'UiState': '''property string hakuMenuStyle: "topFlare"; property string hakuMenuMode: "general"; property string hakuMenuQuery: ""
                    property string hakuMenuScreenName: "fixture-output"; property string openedPanel: ""; property string openedScreenName: ""
                    function openTaskManagerFromHakuMenu() { openedPanel = "taskManager"; openedScreenName = hakuMenuScreenName; closeHakuMenu() }
                    function openSettings(screenName) { openedPanel = "settings"; openedScreenName = screenName }
                    function setHakuMenuQuery(value) { hakuMenuQuery = value } function setHakuMenuMode(value) { hakuMenuMode = value }
                    function closeHakuMenu() { hakuMenuScreenName = "" } function setHakuMenuSelectionLabel(value) {} function setHakuPanelTab(value) {}''',
                'Env': f'property string binDir: "{work / "bin"}"; property string themeDir: ""',
                'ShellSettingsStore': 'property string colorMode: "dark"; property string surfaceTone: "default"; property int baseRadius: 16',
            }
            for name, properties in stubs.items():
                (shell / f'services/{name}.qml').write_text(f'pragma Singleton\nimport QtQuick\nQtObject {{ {properties} }}\n')
            (shell / 'services/qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n' for name in (*services, *stubs)))
            shutil.copy2(Path(__file__).with_name('harness') / harness_name, shell / 'shell.qml')
            (work / 'bin').mkdir()
            (work / 'bin/general_menu_ctl.py').symlink_to(ROOT / 'src/core/backend/user/general_menu_ctl.py')
            # Replace the static Wi-Fi executable with a harmless local recorder.
            static = work / 'bin/nm-connection-editor'
            static.write_text('#!/bin/sh\nprintf launched > "$HAKU_GENERAL_STATIC_LAUNCHED"\n')
            static.chmod(0o700)
            config = work / 'general.json'
            shutil.copy2(ROOT / 'src/home/hakucfg/config/hakumenu-general.json', config)
            (work / 'runtime').mkdir(mode=0o700)
            environment = {**os.environ, 'HOME': str(work), 'XDG_RUNTIME_DIR': str(work / 'runtime'),
                           'XDG_CONFIG_HOME': str(work / 'config'), 'XDG_CACHE_HOME': str(work / 'cache'),
                           'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                           'QT_SCALE_FACTOR': '1', 'HAKUSPACE_REDUCED_MOTION': '1' if reduced else '0',
                           'HAKUSPACE_GENERAL_MENU_FILE': str(config), 'HAKU_GENERAL_LAUNCHED': str(work / 'launched'),
                           'HAKU_GENERAL_STATIC_LAUNCHED': str(work / 'static-launched'),
                           'HAKU_GENERAL_ADAPTER': str(ROOT / 'src/core/menu/hm_general.sh'),
                           'PATH': str(work / 'bin') + os.pathsep + os.environ['PATH'],
                           'DBUS_SESSION_BUS_ADDRESS': 'unix:path=' + str(work / 'no-session-bus')}
            for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORMTHEME', 'QT_QPA_PLATFORMTHEME_QT6'):
                environment.pop(name, None)
            result = subprocess.run(['quickshell', '-p', str(shell / 'shell.qml'), '--no-color'],
                                    env=environment, capture_output=True, text=True, timeout=30)
            log = result.stdout + result.stderr
            Path('/tmp/haku-' + Path(harness_name).stem + ('-reduced' if reduced else '') + '.log').write_text(log)
            self.assertEqual(result.returncode, 0, log)
            self.assertIn(marker, log)
            self.assertNotRegex(log, r'ReferenceError|TypeError|Binding loop|Unable to assign|Failed to load')
            if harness_name == 'general_menu.qml':
                self.assertEqual((work / 'launched').read_text(), 'edited-launch')
                self.assertEqual((work / 'static-launched').read_text(), 'launched')


    def test_service_crud_conflict_and_list_activation(self):
        """Exercise real async snapshots, mutations, conflict refresh and ID-only launch."""
        self.run_harness('general_menu.qml', 'General menu QML integration passed')

    def test_editor_layout_and_fade(self):
        """Keep actions visible at HD/full-HD, both edges and larger fonts, including reduced motion."""
        for reduced in (False, True):
            with self.subTest(reduced=reduced):
                self.run_harness('general_style.qml', 'General editor style passed', reduced)


if __name__ == '__main__':
    unittest.main()
