#!/usr/bin/env python3
"""Exercise shared Waybar shortcuts with isolated Classic and Hikai backends."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

# Run the public facade while replacing every process-lifecycle command.
ROOT = Path(__file__).resolve().parents[3]
FACADE = ROOT / "src/core/facade/waybar_manager.sh"


class ChromeToggleTests(unittest.TestCase):
    """Keep state and fake Waybar processes inside a disposable HOME."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.state = self.home / ".local/state/hakuspace/state"
        self.state.mkdir(parents=True)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.running = self.home / "waybar-running"
        self.addCleanup(self.running.unlink, missing_ok=True)
        for name, body in {"pgrep": 'test -f "$WAYBAR_TEST_RUNNING"',
                           "pkill": 'rm -f "$WAYBAR_TEST_RUNNING"',
                           "waybar": 'touch "$WAYBAR_TEST_RUNNING"\n'
                                     'echo "Bar configured (width: 1920, height: 28) for output: fixture"\n'
                                     'while test -f "$WAYBAR_TEST_RUNNING"; do sleep 0.05; done'}.items():
            script = self.bin / name
            script.write_text("#!/bin/sh\n" + body + "\n")
            script.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.home), "PATH": str(self.bin) + ":" + os.environ["PATH"],
                    "XDG_RUNTIME_DIR": str(self.home / "runtime"),
                    "WAYBAR_TEST_RUNNING": str(self.running)}
        self.preference = self.state / "[desktop].waybar.requested"
        (self.state / "[desktop].taskbar.requested").write_text("1\n")

    def toggle(self):
        """Invoke the same public command as compositor keybindings."""
        subprocess.run(["bash", str(FACADE), "--toggle"], env=self.env, check=True,
                       capture_output=True, text=True)

    def test_hikai_never_mutates_classic_or_taskbar_preferences(self):
        """Two Hikai toggles preserve even missing or malformed Classic state."""
        (self.state / "[shell].backend").write_text("hikai\n")
        for content in (None, "0\n", "1\n", "legacy preference\n"):
            if content is None:
                self.preference.unlink(missing_ok=True)
            else:
                self.preference.write_text(content)
            self.toggle()
            self.toggle()
            self.assertEqual(self.preference.read_text() if self.preference.exists() else None, content)
            self.assertFalse((self.state / "[desktop].waybar.mode").exists())
            self.assertEqual((self.state / "[desktop].taskbar.requested").read_text(), "1\n")
            self.assertFalse(self.running.exists())

    def test_classic_shortcut_still_stops_and_starts_waybar(self):
        """Returning to Classic restores the existing process and preference toggle."""
        (self.state / "[shell].backend").write_text("classic\n")
        config = self.home / ".config/waybar"
        config.mkdir(parents=True)
        (config / "config").touch()
        (config / "style.css").touch()
        self.running.touch()
        self.preference.write_text("1\n")
        self.toggle()
        self.assertFalse(self.running.exists())
        self.assertEqual(self.preference.read_text(), "0\n")
        self.toggle()
        self.assertTrue(self.running.exists())
        self.assertEqual(self.preference.read_text(), "1\n")
        self.assertEqual((self.state / "[desktop].taskbar.requested").read_text(), "1\n")


if __name__ == "__main__":
    unittest.main()
