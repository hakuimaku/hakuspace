#!/usr/bin/env python3
"""Run the production note overlay with isolated storage and Qt input events."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

# Resolve production QML and the colocated event harness.
SOURCE = Path(__file__).resolve().parents[2] / "src/home/.config/quickshell/hakuspace"
HARNESS = Path(__file__).with_name("temp_note_overlay_harness.qml")


class TempNoteOverlayTest(unittest.TestCase):
    """Exercise shared state, drag constraints and close/save/reset behavior."""

    @unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY"), "A Wayland compositor is required")
    def test_overlay_lifecycle(self):
        """Run a transient Wayland surface without touching the user's notes."""
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)  # Hold the isolated QML tree and runtime.
            (fixture / "runtime").mkdir(mode=0o700)
            (fixture / "services").mkdir()
            (fixture / "components").mkdir()
            for name in ("UiState", "Theme", "HAnimation"):
                shutil.copy2(SOURCE / f"services/{name}.qml", fixture / f"services/{name}.qml")
            (fixture / "services/qmldir").write_text(
                "".join(f"singleton {name} 1.0 {name}.qml\n"
                        for name in ("UiState", "Theme", "HAnimation", "TextStore", "Env", "FlareEdges")))
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
            environment = dict(os.environ, XDG_RUNTIME_DIR=str(fixture / "runtime"),
                               WAYLAND_DISPLAY=str(Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ["WAYLAND_DISPLAY"]),
                               QT_QPA_PLATFORM="wayland", QT_QUICK_BACKEND="software",
                               QT_IM_MODULE="compose")  # Isolate runtime files and input methods.
            for name in ("DISPLAY", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(name, None)
            result = subprocess.run(["quickshell", "-p", str(fixture / "shell.qml"), "--no-color"],
                                    env=environment, capture_output=True, text=True, timeout=12)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Temp Note overlay passed", result.stdout + result.stderr)
            self.assertNotRegex(result.stdout + result.stderr, r"ReferenceError|TypeError|Binding loop|Unable to assign")


if __name__ == "__main__":
    unittest.main()
