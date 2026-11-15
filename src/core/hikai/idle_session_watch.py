#!/usr/bin/env python3
"""Bridge the current logind session and hold a sleep delay until native lock is secure."""
import json
import os
import signal
import sys

from gi.repository import Gio, GLib, GLibUnix

# Restrict session lock signals to this login, never another user's session.
BUS_NAME = "org.freedesktop.login1"
MANAGER_PATH = "/org/freedesktop/login1"
MANAGER_IFACE = BUS_NAME + ".Manager"
SESSION_IFACE = BUS_NAME + ".Session"


class SessionWatch:
    """Own one delay fd and a bounded stdin acknowledgment channel."""

    def __init__(self, connection, emit):
        """Resolve the caller's session before subscribing to its lock signals."""
        self.connection = connection
        self.emit = emit
        self.delay_fd = None
        self.sleeping = False
        self.sleep_serial = 0
        self.input_buffer = b""
        session_id = os.environ.get("XDG_SESSION_ID")
        method = "GetSession" if session_id else "GetSessionByPID"
        params = GLib.Variant("(s)", (session_id,)) if session_id else GLib.Variant("(u)", (os.getpid(),))
        self.session_path = self.call(MANAGER_PATH, MANAGER_IFACE, method, params, "(o)").unpack()[0]
        self.subscriptions = []

    def subscribe(self):
        """Subscribe only while the sleep delay fd is already held."""
        if self.subscriptions:
            return
        self.subscriptions = [
            self.connection.signal_subscribe(BUS_NAME, SESSION_IFACE, None, self.session_path,
                                        None, Gio.DBusSignalFlags.NONE, self.on_session),
            self.connection.signal_subscribe(BUS_NAME, MANAGER_IFACE, "PrepareForSleep", MANAGER_PATH,
                                        None, Gio.DBusSignalFlags.NONE, self.on_sleep),
        ]

    def call(self, path, interface, method, params, reply_type):
        """Bound synchronous setup calls so a disconnected logind cannot stall startup."""
        return self.connection.call_sync(BUS_NAME, path, interface, method, params,
                                         GLib.VariantType.new(reply_type), Gio.DBusCallFlags.NONE, 3000, None)

    def acquire_delay(self):
        """Retain the Unix fd returned by logind until the secure acknowledgment."""
        if self.delay_fd is not None:
            return
        reply, descriptors = self.connection.call_with_unix_fd_list_sync(
            BUS_NAME, MANAGER_PATH, MANAGER_IFACE, "Inhibit",
            GLib.Variant("(ssss)", ("sleep", "HakuSpace", "Secure the native session lock", "delay")),
            GLib.VariantType.new("(h)"), Gio.DBusCallFlags.NONE, 3000, None, None)
        self.delay_fd = descriptors.get(reply.unpack()[0])

    def release_delay(self):
        """Release exactly the fd owned by this bridge."""
        if self.delay_fd is not None:
            os.close(self.delay_fd)
            self.delay_fd = None

    def start(self):
        """Publish readiness only after the delay inhibitor has been acquired."""
        self.acquire_delay()
        self.subscribe()
        preparing = self.call(MANAGER_PATH, "org.freedesktop.DBus.Properties", "Get",
                              GLib.Variant("(ss)", (MANAGER_IFACE, "PreparingForSleep")), "(v)").unpack()[0]
        self.emit({"event": "ready"})
        if preparing:
            self.prepare_sleep(True)

    def on_session(self, connection, sender, path, interface, name, parameters):
        """Forward lock requests; unlock is informational and cannot authenticate."""
        if name in ("Lock", "Unlock"):
            self.emit({"event": name.lower()})

    def prepare_sleep(self, sleeping):
        """Rearm before publishing wake and identify each sleep transaction."""
        if sleeping == self.sleeping:
            return
        self.acquire_delay()
        if sleeping:
            self.sleep_serial += 1
        self.sleeping = sleeping
        self.emit({"event": "prepare-sleep", "sleeping": sleeping, "serial": self.sleep_serial})

    def on_sleep(self, connection, sender, path, interface, name, parameters):
        """Treat inhibitor reacquisition failure as a bridge failure requiring restart."""
        try:
            self.prepare_sleep(parameters.unpack()[0])
        except (GLib.Error, OSError) as error:
            print(f"idle-session-watch: {error}", file=sys.stderr)
            self.emit({"event": "error"})
            self.close()

    def acknowledge(self, line):
        """Ignore stale acknowledgments from an earlier sleep or wake transaction."""
        if self.sleeping and line == f"secure {self.sleep_serial}".encode():
            self.release_delay()

    def close(self):
        """Unsubscribe before closing the owned delay fd."""
        for subscription in self.subscriptions:
            self.connection.signal_unsubscribe(subscription)
        self.subscriptions = []
        self.release_delay()


def main():
    """Run one streamed event process until its owning shell closes the pipe."""
    loop = GLib.MainLoop()
    connection = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    watch = SessionWatch(connection, lambda event: print(json.dumps(event), flush=True))

    def read_ack(fd, condition):
        """Read bounded chunks without blocking on an incomplete line."""
        chunk = os.read(fd, 128)
        if not chunk:
            loop.quit()
            return False
        watch.input_buffer += chunk
        while b"\n" in watch.input_buffer:
            line, watch.input_buffer = watch.input_buffer.split(b"\n", 1)
            watch.acknowledge(line)
        if len(watch.input_buffer) > 128:
            loop.quit()
            return False
        return True

    def disconnected(*args):
        """Restart through the QML owner if the logind bus name changes."""
        loop.quit()

    def stop():
        """Release the inhibitor through the normal cleanup path on SIGTERM."""
        loop.quit()
        return False

    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, read_ack)
    connection.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                                "/org/freedesktop/DBus", BUS_NAME, Gio.DBusSignalFlags.NONE, disconnected)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
    try:
        watch.start()
        loop.run()
    finally:
        watch.close()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (GLib.Error, OSError, ValueError) as error:
        print(f"idle-session-watch: {error}", file=sys.stderr)
        sys.exit(1)
