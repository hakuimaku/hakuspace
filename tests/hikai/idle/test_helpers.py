#!/usr/bin/env python3
"""Check native effect recovery and shared caffeine/audio policy with inert executables."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

# Reuse deployed helpers while substituting only their system action boundaries.
ROOT = Path(__file__).resolve().parents[3]


class IdleHelperTests(unittest.TestCase):
    """Flatten scripts in a private HOME without using host brightness or power."""

    def setUp(self):
        """Prepare deterministic audio output and a recoverable brightness value."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        for source in ("sys/idle_actions.sh", "sys/idle_inhibit.sh", "lib/haku_state.sh"):
            shutil.copy2(ROOT / "src/core" / source, self.bin)
        for name, body in {
            "brightnessctl": '''case "$1" in
    -s) cp "$TEST_ROOT/brightness" "$TEST_ROOT/saved" ;;
    -r) cp "$TEST_ROOT/saved" "$TEST_ROOT/brightness" ;;
    set) [ ! -f "$TEST_ROOT/fail-dim" ] || exit 1; echo "$2" > "$TEST_ROOT/brightness" ;;
esac''',
            "dpms_handler.sh": 'printf "%s\\n" "$1" >> "$TEST_ROOT/dpms"',
            "pactl": 'cat "$TEST_ROOT/audio"',
            "notify-send": 'exit 0',
        }.items():
            script = self.bin / name
            script.write_text("#!/bin/sh\n" + body + "\n")
            script.chmod(0o755)
        (self.root / "brightness").write_text("55%\n")
        (self.root / "audio").write_text("")
        self.env = dict(os.environ, HOME=str(self.root), XDG_RUNTIME_DIR=str(self.runtime),
                        TEST_ROOT=str(self.root), PATH=str(self.bin) + ":" + os.environ["PATH"])

    def run_helper(self, script, *args, code=0):
        """Keep failures visible and limit the runtime of every public helper call."""
        result = subprocess.run([self.bin / script, *args], env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stdout

    def test_effects_restore_once_across_processes(self):
        """Repeated dim preserves the original snapshot and recovery is idempotent."""
        self.run_helper("idle_actions.sh", "dim", "10")
        self.run_helper("idle_actions.sh", "dim", "12")
        self.assertEqual((self.root / "saved").read_text(), "55%\n")
        self.run_helper("idle_actions.sh", "off")
        self.run_helper("idle_actions.sh", "recover")
        self.run_helper("idle_actions.sh", "recover")
        self.assertEqual((self.root / "brightness").read_text(), "55%\n")
        self.assertEqual((self.root / "dpms").read_text().splitlines(), ["off", "on"])
        self.assertFalse((self.runtime / "hakuspace/idle-dimmed").exists())

    def test_failed_dim_retains_recovery_and_rejects_invalid_values(self):
        """A partial action can always restore its snapshot after a shell restart."""
        (self.root / "fail-dim").touch()
        self.run_helper("idle_actions.sh", "dim", "10", code=1)
        self.run_helper("idle_actions.sh", "recover")
        self.assertEqual((self.root / "brightness").read_text(), "55%\n")
        for value in ("0", "101", "a", "1;echo", "1000"):
            self.run_helper("idle_actions.sh", "dim", value, code=2)

    def test_caffeine_without_hypridle_and_audio_grace(self):
        """Manual state remains shared while audio checks can be disabled per request."""
        self.run_helper("idle_inhibit.sh", "--check", code=1)
        self.run_helper("idle_inhibit.sh", "--toggle")
        self.run_helper("idle_inhibit.sh", "--check")
        self.run_helper("idle_inhibit.sh", "--condition", "--no-audio", code=1)
        self.run_helper("idle_inhibit.sh", "--toggle")
        self.run_helper("idle_inhibit.sh", "--condition")

        (self.root / "audio").write_text('Sink Input #1\nmedia.class = "Stream/Output/Audio"\nCorked: no\nMute: no\n')
        status = json.loads(self.run_helper("idle_inhibit.sh", "--status-json"))
        self.assertEqual(status, {"manual": False, "audio": True, "inhibited": True})
        self.run_helper("idle_inhibit.sh", "--condition", code=1)
        self.run_helper("idle_inhibit.sh", "--condition", "--no-audio")
        (self.root / "audio").write_text("")
        self.run_helper("idle_inhibit.sh", "--condition", code=1)
        (self.runtime / "hakuspace/idle-audio-timestamp").write_text(str(int(time.time()) - 6))
        self.run_helper("idle_inhibit.sh", "--condition")


    def test_browser_audio_inhibits_only_while_active_and_unmuted(self):
        """Browser playback follows the same audio policy as every other application."""
        for binary, corked, muted, inhibited in (("zen-bin", "no", "no", True),
                                                ("firefox", "no", "no", True),
                                                ("zen-bin", "yes", "no", False),
                                                ("zen-bin", "no", "yes", False)):
            with self.subTest(binary=binary, corked=corked, muted=muted):
                (self.runtime / "hakuspace/idle-audio-timestamp").unlink(missing_ok=True)
                (self.root / "audio").write_text(
                    f'Sink Input #276\nmedia.class = "Stream/Output/Audio"\n'
                    f'Corked: {corked}\nMute: {muted}\napplication.process.binary = "{binary}"\n')
                status = json.loads(self.run_helper("idle_inhibit.sh", "--status-json"))
                self.assertEqual(status, {"manual": False, "audio": inhibited, "inhibited": inhibited})
                self.run_helper("idle_inhibit.sh", "--condition", code=1 if inhibited else 0)

if __name__ == "__main__":
    unittest.main()
