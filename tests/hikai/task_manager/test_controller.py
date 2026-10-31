#!/usr/bin/env python3
"""Control only disposable children and mock permission failures."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

# Import the controller alongside its stat parser.
ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT / 'src/core/backend/system'
sys.path.insert(0, str(BACKEND))
import task_manager_ctl as ctl


class ControllerTest(unittest.TestCase):
    """Verify signal policy and identity checks without touching desktop processes."""

    def child(self):
        """Ensure every disposable child is reaped after its test."""
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        def cleanup():
            if child.poll() is None:
                child.kill()
            child.wait(timeout=3)
        self.addCleanup(cleanup)
        return child

    def test_term_and_kill(self):
        """Explicit TERM and KILL reach the selected disposable process."""
        for name, code in (('TERM', -15), ('KILL', -9)):
            child = self.child()
            status, result = ctl.control('status', child.pid)
            self.assertEqual(result, 0)
            value, result = ctl.control('signal', child.pid, name, status['startTime'])
            self.assertEqual(value['status'], 'sent')
            self.assertEqual(result, 0)
            self.assertEqual(child.wait(timeout=3), code)
            self.assertEqual(ctl.control('signal', child.pid, name)[0]['status'], 'alreadyExited')

    def test_reused_identity_is_not_signalled(self):
        """A stale selection is treated as an exited process."""
        child = self.child()
        self.assertEqual(ctl.control('signal', child.pid, 'KILL', -1)[0]['status'], 'alreadyExited')
        self.assertIsNone(child.poll())

    def test_invalid_requests(self):
        """Reject process groups, PID zero and signals outside the allowlist."""
        for pid in (0, -1):
            self.assertEqual(ctl.control('signal', pid, 'TERM')[1], 2)
        self.assertEqual(ctl.control('signal', 1, 'STOP')[1], 2)
        result = subprocess.run([sys.executable, str(BACKEND / 'task_manager_ctl.py'), 'signal', 'bad', 'TERM'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)['status'], 'invalidPid')

    def test_permission_denied(self):
        """Report kernel permission failures without an escalation path."""
        with patch.object(ctl.os, 'pidfd_open', side_effect=PermissionError):
            value, code = ctl.control('signal', 1, 'TERM')
        self.assertEqual(value['status'], 'permissionDenied')
        self.assertEqual(code, 1)


if __name__ == '__main__':
    unittest.main()
