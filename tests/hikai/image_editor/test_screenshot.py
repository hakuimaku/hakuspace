#!/usr/bin/env python3
"""Check screenshot hints and capture-failure behavior without a live desktop."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

# Exercise the existing capture entrypoint with local process fixtures.
SCRIPT = Path(__file__).resolve().parents[3] / 'src/core/util/screenshot.sh'


class ScreenshotTests(unittest.TestCase):
    """Keep paths with spaces intact from capture through notification metadata."""

    def test_hints_and_failed_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root/'bin'; tools.mkdir()
            home = root/'home'; home.mkdir()
            captured = root/'captured'; clipboard = root/'clipboard'; hints = root/'hints'
            scripts = {
                'grim': '#!/bin/bash\n[[ ${FAIL_CAPTURE:-0} == 0 ]] || exit 1\nprintf image > "${@: -1}"\nprintf "%s" "${@: -1}" > "$CAPTURED"\n',
                'wl-copy': '#!/bin/sh\ncat > "$CLIPBOARD"\n',
                'notify-send': '#!/bin/sh\nprintf "%s\\0" "$@" > "$HINTS"\n',
            }
            for name, body in scripts.items():
                (tools/name).write_text(body); (tools/name).chmod(0o755)
            environment = {**os.environ,'HOME':str(home),'PATH':str(tools)+os.pathsep+os.environ['PATH'],
                           'SCREENSHOT_DIR':str(root/'screenshots with space'),'CAPTURED':str(captured),'CLIPBOARD':str(clipboard),'HINTS':str(hints)}
            result = subprocess.run(['bash',str(SCRIPT),'--fullscreen'],env=environment,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            path = captured.read_text()
            self.assertEqual(clipboard.read_bytes(),b'image')
            self.assertIn(b'string:x-hakuspace-kind:screenshot',hints.read_bytes().split(b'\0'))
            self.assertIn(('string:x-hakuspace-path:'+path).encode(),hints.read_bytes().split(b'\0'))
            hints.unlink(); clipboard.unlink()
            result = subprocess.run(['bash',str(SCRIPT),'--fullscreen'],env=environment|{'FAIL_CAPTURE':'1'},capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertFalse(hints.exists()); self.assertFalse(clipboard.exists())


if __name__ == '__main__':
    unittest.main()
