#!/usr/bin/env python3
"""Check the Temp Note shortcut without contacting the desktop or notifications."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

# Exercise the utility through its real backend library.
ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "src/core/util/temp_note.sh"


class TempNoteShortcutTest(unittest.TestCase):
    """Keep backend state, IPC and notification commands in a disposable HOME."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.state = self.home / ".local/state/hakuspace/state"
        self.state.mkdir(parents=True)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), XDG_RUNTIME_DIR=str(self.home / "runtime"),
                        PATH=str(self.bin) + ":" + os.environ["PATH"])
        for name in ("qs", "notify-send"):
            stub = self.bin / name
            stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HOME/' + name
                            + '.args"\nexit "${TEMP_NOTE_TEST_EXIT:-0}"\n')
            stub.chmod(0o755)

    def run_shortcut(self, backend):
        """Set the real backend selector before invoking the public command."""
        (self.state / "shell_backend").write_text(backend + "\n")
        return subprocess.run([str(SCRIPT)], env=self.env, capture_output=True, text=True)

    def test_hikai_only_toggles_temp_note(self):
        """The shortcut never invokes Navigation or a launcher command."""
        result = self.run_shortcut("hikai")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "qs.args").read_text().splitlines(),
                         ["-c", "hakuspace", "ipc", "call", "tempNote", "toggle"])
        self.assertFalse((self.home / "notify-send.args").exists())

    def test_classic_notifies_without_ipc(self):
        """Classic reports the unsupported action without opening shell panels."""
        result = self.run_shortcut("classic")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "notify-send.args").read_text().splitlines(),
                         ["Temp Note", "Temp Note is not supported in Classic mode."])
        self.assertFalse((self.home / "qs.args").exists())

    def test_ipc_failure_is_reported(self):
        """An unavailable shell must not silently report a successful toggle."""
        self.env["TEMP_NOTE_TEST_EXIT"] = "1"
        self.assertNotEqual(self.run_shortcut("hikai").returncode, 0)


if __name__ == "__main__":
    unittest.main()
