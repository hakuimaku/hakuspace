#!/usr/bin/env python3
"""Exercise delay-fd lifetime and session event handling without the host system bus."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from gi.repository import GLib

# Load the real bridge while replacing only its D-Bus boundary.
SPEC = importlib.util.spec_from_file_location("idle_session_watch", Path(__file__).resolve().parents[3] / "src/core/backend/system/idle_session_watch.py")
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class LogindBridgeTests(unittest.TestCase):
    """Verify secure acknowledgments close only the current transaction's delay fd."""

    def setUp(self):
        """Use real pipe fds with an inert Gio-shaped connection."""
        self.events = []
        self.connection = Mock()
        self.connection.call_sync.return_value = GLib.Variant("(o)", ("/org/freedesktop/login1/session/test",))
        self.connection.signal_subscribe.side_effect = (1, 2)
        with patch.dict(os.environ, XDG_SESSION_ID="test"):
            self.watch = bridge.SessionWatch(self.connection, self.events.append)
        self.addCleanup(self.watch.close)

    def supply_fd(self):
        """Provide a descriptor that becomes invalid only on explicit release."""
        read_fd, write_fd = os.pipe()
        os.close(write_fd)
        descriptors = Mock()
        descriptors.get.return_value = read_fd
        self.connection.call_with_unix_fd_list_sync.return_value = (GLib.Variant("(h)", (0,)), descriptors)
        return read_fd

    def test_secure_ack_and_resume_rearm(self):
        """Delay survives wrong/stale acknowledgments and rearms after every wake."""
        first = self.supply_fd()
        self.watch.acquire_delay()
        self.watch.prepare_sleep(True)
        for ack in (b"secure", b"secure 0", b"unlock"):
            self.watch.acknowledge(ack)
            os.fstat(first)
        self.watch.acknowledge(b"secure 1")
        with self.assertRaises(OSError):
            os.fstat(first)
        second = self.supply_fd()
        self.watch.prepare_sleep(False)
        self.watch.prepare_sleep(True)
        self.watch.acknowledge(b"secure 1")
        os.fstat(second)
        self.watch.acknowledge(b"secure 2")
        with self.assertRaises(OSError):
            os.fstat(second)
        self.assertEqual([event["sleeping"] for event in self.events], [True, False, True])

    def test_session_signals_and_readiness(self):
        """Publish readiness after Inhibit and forward only session Lock/Unlock."""
        self.supply_fd()
        self.connection.call_sync.return_value = GLib.Variant("(v)", (GLib.Variant("b", True),))
        self.watch.start()
        for name in ("Lock", "Unlock", "Other"):
            self.watch.on_session(None, None, None, None, name, None)
        self.assertEqual([event["event"] for event in self.events], ["ready", "prepare-sleep", "lock", "unlock"])
        self.assertEqual(self.connection.signal_subscribe.call_args_list[0].args[3], "/org/freedesktop/login1/session/test")


if __name__ == "__main__":
    unittest.main()
