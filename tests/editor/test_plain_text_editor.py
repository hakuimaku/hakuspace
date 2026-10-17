#!/usr/bin/env python3
"""Exercise the real QML editor with Qt input-method and keyboard events."""
import os
from pathlib import Path
import shutil
import tempfile
import unittest

# Use an isolated Qt window without the desktop theme or a running input daemon.
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
os.environ["QT_IM_MODULE"] = "compose"
os.environ.pop("QT_QPA_PLATFORMTHEME", None)
os.environ.pop("QT_QPA_PLATFORMTHEME_QT6", None)

from PySide6.QtCore import QCoreApplication, QMetaObject, Qt, QUrl
from PySide6.QtGui import QGuiApplication, QInputMethodEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

# Locate production components independently of the caller's working directory.
SOURCE = Path(__file__).resolve().parents[2] / "src/home/.config/quickshell/hakuspace"


class PlainTextEditorTest(unittest.TestCase):
    """Check composition, owner synchronization and existing editor commands."""

    @classmethod
    def setUpClass(cls):
        """Load production editor code with a side-effect-free theme fixture."""
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.directory = tempfile.TemporaryDirectory()
        cls.fixture = Path(cls.directory.name)
        (cls.fixture / "components/editor").mkdir(parents=True)
        (cls.fixture / "services").mkdir()
        for name in ("PlainTextEditor.qml", "PlainTextEditOps.js"):
            shutil.copy2(SOURCE / "components/editor" / name, cls.fixture / "components/editor" / name)
        (cls.fixture / "services/qmldir").write_text("singleton Theme 1.0 Theme.qml\n")
        (cls.fixture / "services/Theme.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string fontFamily: "sans-serif"
    property int fontSize: 14
    property color fg: "white"
    property color accent: "blue"
    property color onAccentColor: "black"
    property color fgMuted: "gray"
}
''')
        (cls.fixture / "main.qml").write_text('''import QtQuick
import "components/editor"
Item {
    id: fixture
    width: 460; height: 330
    property string ownerText: "initial"
    property int escaped: 0
    Keys.onEscapePressed: fixture.escaped++
    PlainTextEditor {
        objectName: "editor"
        anchors.fill: parent
        text: fixture.ownerText
        onTextEdited: newText => fixture.ownerText = newText
    }
}
''')

    @classmethod
    def tearDownClass(cls):
        """Remove the temporary component tree."""
        cls.directory.cleanup()

    def setUp(self):
        """Create a fresh editor and record its public signals."""
        self.view = QQuickView()
        self.view.setSource(QUrl.fromLocalFile(str(self.fixture / "main.qml")))
        self.assertEqual(self.view.status(), QQuickView.Status.Ready, str(self.view.errors()))
        self.root = self.view.rootObject()
        self.editor = self.root.findChild(type(self.root), "editor")
        self.view.show()
        QMetaObject.invokeMethod(self.editor, "forceEditorFocus")
        self.app.processEvents()
        self.area = self.view.activeFocusItem()
        self.assertIsNotNone(self.area)
        self.edits = []
        self.actions = []
        self.editor.textEdited.connect(self.edits.append)
        self.editor.escapeRequested.connect(lambda: self.actions.append("escape"))
        self.editor.saveRequested.connect(lambda: self.actions.append("save"))
        self.editor.leftBoundaryRequested.connect(lambda: self.actions.append("left"))

    def tearDown(self):
        """Release focus and destroy the test window."""
        self.view.close()
        self.view.deleteLater()
        QCoreApplication.sendPostedEvents(None, 0)

    def owner_text(self, text):
        """Update the value bound by a consumer without treating it as typing."""
        self.root.setProperty("ownerText", text)

    def preedit(self, text):
        """Deliver native preedit directly to the actual Qt TextArea."""
        QCoreApplication.sendEvent(self.area, QInputMethodEvent(text, []))

    def commit(self, text=""):
        """Finish composition and let deferred reconciliation run."""
        event = QInputMethodEvent()  # Carry the input method's committed text.
        event.setCommitString(text)
        QCoreApplication.sendEvent(self.area, event)
        self.app.processEvents()

    def test_vietnamese_commits(self):
        """Publish only final committed text with and without code shortcuts."""
        for code_mode in (False, True):
            self.editor.setProperty("codeEditingEnabled", code_mode)
            for text in ("ă", "â", "ê", "ô", "ơ", "ư", "đ", "Tiếng Việt",
                         "trường", "người", "Nguyễn", "hòa bình"):
                with self.subTest(code_mode=code_mode, text=text):
                    self.owner_text("")
                    self.edits.clear()
                    self.preedit(text)
                    self.assertTrue(self.editor.property("imeComposing"))
                    self.assertEqual(self.edits, [])
                    self.assertEqual(self.root.property("ownerText"), "")
                    self.commit(text)
                    self.assertFalse(self.editor.property("imeComposing"))
                    self.assertEqual(self.edits, [text])
                    self.assertEqual(self.area.property("text"), text)

    def test_latest_external_update_survives_composition(self):
        """Keep preedit intact and apply the latest owner replacement silently."""
        self.preedit("người")
        self.owner_text("first external update")
        self.owner_text("latest external update")
        self.assertEqual(self.area.property("text"), "initial")
        self.assertEqual(self.area.property("preeditText"), "người")
        self.assertEqual(self.edits, [])
        self.commit("người")
        self.assertEqual(self.area.property("text"), "latest external update")
        self.assertEqual(self.root.property("ownerText"), "latest external update")
        self.assertEqual(self.edits, [])
        self.owner_text("later update")
        self.assertEqual(self.area.property("text"), "later update")

    def test_commit_with_continuing_preedit(self):
        """Do not publish partial commits while a later syllable is composing."""
        self.owner_text("")
        self.preedit("ng")
        event = QInputMethodEvent("ười", [])  # Continue preedit after a partial commit.
        event.setCommitString("ng")
        QCoreApplication.sendEvent(self.area, event)
        self.app.processEvents()
        self.assertEqual(self.edits, [])
        self.assertTrue(self.editor.property("imeComposing"))
        self.commit("ười")
        self.assertEqual(self.edits, ["người"])

    def test_external_update_after_cancel_and_restart(self):
        """Keep queued owner state through a restarted input-method session."""
        self.preedit("ư")
        self.owner_text("new document")
        self.preedit("")
        self.preedit("ơ")
        self.app.processEvents()
        self.assertEqual(self.area.property("text"), "initial")
        self.assertEqual(self.area.property("preeditText"), "ơ")
        self.commit()
        self.assertEqual(self.area.property("text"), "new document")
        self.assertEqual(self.edits, [])

    def test_selection_replacement_and_cancellation(self):
        """Keep selection replacement and IME cancellation out of interim saves."""
        self.owner_text("old text")
        QMetaObject.invokeMethod(self.area, "selectAll")
        self.preedit("Tiếng")
        self.assertEqual(self.edits, [])
        self.commit("Tiếng Việt")
        self.assertEqual(self.edits, ["Tiếng Việt"])
        self.preedit("x")
        self.commit()
        self.assertEqual(self.edits, ["Tiếng Việt"])

    def test_shortcuts_defer_during_composition(self):
        """Do not emit editor actions or run line commands during preedit."""
        self.editor.setProperty("codeEditingEnabled", True)
        self.editor.setProperty("leftBoundaryNavigationEnabled", True)
        for key, modifiers in (
            (Qt.Key.Key_Tab, Qt.KeyboardModifier.NoModifier),
            (Qt.Key.Key_Backtab, Qt.KeyboardModifier.ShiftModifier),
            (Qt.Key.Key_Left, Qt.KeyboardModifier.NoModifier),
            (Qt.Key.Key_Escape, Qt.KeyboardModifier.NoModifier),
            (Qt.Key.Key_Return, Qt.KeyboardModifier.NoModifier),
            (Qt.Key.Key_Enter, Qt.KeyboardModifier.NoModifier),
            (Qt.Key.Key_S, Qt.KeyboardModifier.ControlModifier),
            (Qt.Key.Key_Z, Qt.KeyboardModifier.ControlModifier),
            (Qt.Key.Key_Z, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier),
            (Qt.Key.Key_Y, Qt.KeyboardModifier.ControlModifier),
            (Qt.Key.Key_Slash, Qt.KeyboardModifier.ControlModifier),
            (Qt.Key.Key_K, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier),
            (Qt.Key.Key_Up, Qt.KeyboardModifier.AltModifier),
            (Qt.Key.Key_Down, Qt.KeyboardModifier.AltModifier),
            (Qt.Key.Key_Up, Qt.KeyboardModifier.AltModifier | Qt.KeyboardModifier.ShiftModifier),
            (Qt.Key.Key_Down, Qt.KeyboardModifier.AltModifier | Qt.KeyboardModifier.ShiftModifier),
            (Qt.Key.Key_L, Qt.KeyboardModifier.ControlModifier),
        ):
            with self.subTest(key=key, modifiers=modifiers):
                self.owner_text("line")
                self.area.setProperty("cursorPosition", 0)
                self.preedit("ư")
                QTest.keyClick(self.view, key, modifiers)
                self.assertEqual(self.actions, [])
                self.assertEqual(self.root.property("escaped"), 0)
                self.commit()

    def test_existing_shortcuts_and_clipboard(self):
        """Retain normal save, close, indentation, undo, redo and paste behavior."""
        self.editor.setProperty("codeEditingEnabled", True)
        self.owner_text("line")
        self.area.setProperty("cursorPosition", 0)
        QTest.keyClick(self.view, Qt.Key.Key_Tab)
        self.assertEqual(self.area.property("text"), "    line")
        QTest.keyClick(self.view, Qt.Key.Key_Z, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(self.area.property("text"), "line")
        QTest.keyClick(self.view, Qt.Key.Key_Z,
                       Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier)
        self.assertEqual(self.area.property("text"), "    line")
        QTest.keyClick(self.view, Qt.Key.Key_S, Qt.KeyboardModifier.ControlModifier)
        QTest.keyClick(self.view, Qt.Key.Key_Escape)
        self.assertEqual(self.actions, ["save", "escape"])
        self.app.clipboard().setText("người")
        QTest.keyClick(self.view, Qt.Key.Key_V, Qt.KeyboardModifier.ControlModifier)
        self.app.processEvents()
        self.assertIn("người", self.root.property("ownerText"))

    def test_save_and_close_publish_pending_text(self):
        """Deliver typed content to its owner before save or close callbacks."""
        self.owner_text("")
        QTest.keyClick(self.view, Qt.Key.Key_A)
        QTest.keyClick(self.view, Qt.Key.Key_S, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(self.root.property("ownerText"), "a")
        QTest.keyClick(self.view, Qt.Key.Key_B)
        QTest.keyClick(self.view, Qt.Key.Key_Escape)
        self.assertEqual(self.root.property("ownerText"), "ab")
        self.assertEqual(self.actions, ["save", "escape"])


if __name__ == "__main__":
    unittest.main()
