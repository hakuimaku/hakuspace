#!/usr/bin/env python3
"""Run the production note overlay with isolated storage and Qt input events."""
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
import unittest

# Resolve production QML and the colocated event harness.
SOURCE = Path(__file__).resolve().parents[2] / "src/home/.config/quickshell/hakuspace"
HARNESS = Path(__file__).with_name("temp_note_overlay_harness.qml")


class TempNoteOverlayTest(unittest.TestCase):
    """Exercise note lifecycle and keyboard handoff to normal application windows."""

    @unittest.skipUnless(shutil.which("labwc") and shutil.which("quickshell"),
                         "Labwc and Quickshell are required")
    def test_overlay_lifecycle(self):
        """Run note and application surfaces in a private software-rendered session."""
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)  # Hold the isolated QML tree and runtime.
            (fixture / "runtime").mkdir(mode=0o700)
            shutil.copytree(SOURCE / "config", fixture / "config")
            (fixture / "services").mkdir()
            (fixture / "components").mkdir()
            for name in ("UiState", "Theme", "HAnimation", "ShellTransitionState"):
                shutil.copy2(SOURCE / f"services/{name}.qml", fixture / f"services/{name}.qml")
            (fixture / "services/qmldir").write_text(
                "".join(f"singleton {name} 1.0 {name}.qml\n"
                        for name in ("UiState", "Theme", "HAnimation", "ShellTransitionState", "TextStore",
                                     "Env", "FlareEdges", "ChromeLayout", "ScreenGeometry", "ShellSettingsStore")))
            # Keep unrelated shell topology and preferences outside this note fixture.
            for name, properties in {
                "ChromeLayout": 'property bool dockbarActive: false; property bool taskbarMode: false',
                "ScreenGeometry": 'property real leftInset: 4',
                "ShellSettingsStore": 'property string colorMode: "dark"; '
                                      'property string surfaceTone: "default"; property int baseRadius: 16',
            }.items():
                (fixture / f"services/{name}.qml").write_text(
                    f'pragma Singleton\nimport QtQuick\nQtObject {{ {properties} }}\n')
            (fixture / "services/Env.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { property string themeDir: "" }\n')
            (fixture / "services/FlareEdges.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { property real thickness: 4 }\n')
            (fixture / "services/TextStore.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string scratchDraft: "persisted note"
    property string flushedText: ""
    property int flushes: 0
    function setScratchDraft(text) { scratchDraft = text }
    function flushScratch() { flushedText = scratchDraft; flushes++ }
}
''')
            for name in ("editor", "sidebar", "motion", "flare"):
                shutil.copytree(SOURCE / "components" / name, fixture / "components" / name)
            shutil.copy2(SOURCE / "components/TempNoteOverlay.qml", fixture / "components/TempNoteOverlay.qml")
            shutil.copy2(HARNESS, fixture / "shell.qml")
            # Run input probes only against a disposable software-rendered compositor.
            (fixture / "labwc").mkdir()
            (fixture / "labwc/rc.xml").write_text("<labwc_config/>\n")
            environment = dict(os.environ, XDG_RUNTIME_DIR=str(fixture / "runtime"),
                               XDG_CONFIG_HOME=str(fixture / "config-home"),
                               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(fixture / "no-session-bus"),
                               WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="2", WLR_RENDERER="pixman",
                               TEMP_NOTE_TEST_INPUT_DIR=str(SOURCE.parents[4] / "tests/support/fixtures"),
                               QT_QPA_PLATFORM="wayland", QT_QUICK_BACKEND="software",
                               QT_IM_MODULE="compose")  # Isolate runtime files and input methods.
            for name in ("DISPLAY", "WAYLAND_DISPLAY", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(name, None)
            with subprocess.Popen(["labwc", "-C", str(fixture / "labwc"),
                                   "-S", shlex.join(["quickshell", "-p", str(fixture / "shell.qml"), "--no-color"])],
                                  env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, start_new_session=True) as process:
                try:
                    stdout, stderr = process.communicate(timeout=12)
                finally:
                    # Reap the compositor and input helpers even after a failed assertion.
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=3)
            self.assertEqual(process.returncode, 0, stdout + stderr)
            self.assertIn("Temp Note overlay passed", stdout + stderr)
            self.assertNotRegex(stdout + stderr, r"ReferenceError|TypeError|Binding loop|Unable to assign")


if __name__ == "__main__":
    unittest.main()
