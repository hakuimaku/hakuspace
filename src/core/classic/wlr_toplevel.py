#!/usr/bin/env python3
"""Minimal pure-Python Wayland client for zwlr_foreign_toplevel_manager_v1."""

from dataclasses import dataclass, field
import os
from pathlib import Path
import socket
import struct
import sys

WL_DISPLAY_ID = 1
WL_DISPLAY_SYNC = 0
WL_DISPLAY_GET_REGISTRY = 1
WL_DISPLAY_EVT_ERROR = 0
WL_DISPLAY_EVT_DELETE_ID = 1

WL_REGISTRY_BIND = 0
WL_REGISTRY_EVT_GLOBAL = 0
WL_REGISTRY_EVT_GLOBAL_REMOVE = 1

WL_CALLBACK_EVT_DONE = 0

ZWLR_TOPLEVEL_MANAGER_STOP = 0
ZWLR_TOPLEVEL_MANAGER_EVT_TOPLEVEL = 0
ZWLR_TOPLEVEL_MANAGER_EVT_FINISHED = 1

ZWLR_TOPLEVEL_HANDLE_SET_MINIMIZED = 2
ZWLR_TOPLEVEL_HANDLE_UNSET_MINIMIZED = 3
ZWLR_TOPLEVEL_HANDLE_ACTIVATE = 4
ZWLR_TOPLEVEL_HANDLE_CLOSE = 5
ZWLR_TOPLEVEL_HANDLE_DESTROY = 7

ZWLR_TOPLEVEL_HANDLE_EVT_TITLE = 0
ZWLR_TOPLEVEL_HANDLE_EVT_APP_ID = 1
ZWLR_TOPLEVEL_HANDLE_EVT_OUTPUT_ENTER = 2
ZWLR_TOPLEVEL_HANDLE_EVT_OUTPUT_LEAVE = 3
ZWLR_TOPLEVEL_HANDLE_EVT_STATE = 4
ZWLR_TOPLEVEL_HANDLE_EVT_DONE = 5
ZWLR_TOPLEVEL_HANDLE_EVT_CLOSED = 6
ZWLR_TOPLEVEL_HANDLE_EVT_PARENT = 7

STATE_MAXIMIZED = 0
STATE_MINIMIZED = 1
STATE_ACTIVATED = 2
STATE_FULLSCREEN = 3


class WaylandProtocolError(RuntimeError):
    """Raised when the Wayland compositor closes the connection or reports an error."""


@dataclass
class ToplevelInfo:
    """Atomic state snapshot of one compositor toplevel window."""

    handle_id: int
    app_id: str = ""
    title: str = ""
    activated: bool = False
    minimized: bool = False
    maximized: bool = False
    fullscreen: bool = False
    outputs: set[int] = field(default_factory=set)
    ready: bool = False


def pack_string(text):
    """Encode a Wayland string argument (4-byte length + NUL + 4-byte padding)."""
    if text is None:
        return struct.pack("=I", 0)
    raw = text.encode("utf-8") + b"\x00"
    pad = (-len(raw)) & 3
    return struct.pack("=I", len(raw)) + raw + (b"\x00" * pad)


def pack_message(object_id, opcode, payload=b""):
    """Encode one Wayland wire message with 8-byte header."""
    size = 8 + len(payload)
    if size > 0xFFFF:
        raise ValueError(f"Wayland message too large: {size}")
    return struct.pack("=II", object_id, (size << 16) | (opcode & 0xFFFF)) + payload


def unpack_string(buf, offset):
    """Decode a Wayland string starting at offset and return (value, next_offset)."""
    (length,) = struct.unpack_from("=I", buf, offset)
    offset += 4
    if length == 0:
        return "", offset
    raw = bytes(buf[offset : offset + length])
    aligned = (length + 3) & ~3
    return raw.rstrip(b"\x00").decode("utf-8", errors="replace"), offset + aligned


def unpack_uint32_array(buf, offset):
    """Decode a Wayland uint32 wl_array starting at offset."""
    (byte_len,) = struct.unpack_from("=I", buf, offset)
    offset += 4
    count = byte_len // 4
    values = struct.unpack_from(f"={count}I", buf, offset) if count else ()
    aligned = (byte_len + 3) & ~3
    return values, offset + aligned


def wayland_socket_path(wayland_display=None, runtime_dir=None):
    """Resolve the Wayland compositor Unix socket path."""
    display = wayland_display or os.environ.get("WAYLAND_DISPLAY") or "wayland-0"
    candidate = Path(display)
    if candidate.is_absolute():
        return candidate
    base = runtime_dir or os.environ.get("XDG_RUNTIME_DIR")
    if not base:
        raise WaylandProtocolError("XDG_RUNTIME_DIR is not set")
    return Path(base) / display


class WlrToplevelClient:
    """Event-driven client for zwlr_foreign_toplevel_manager_v1 over Wayland socket."""

    def __init__(self, on_change=None, on_disconnect=None):
        self.on_change = on_change
        self.on_disconnect = on_disconnect
        self._sock = None
        self._rx_buf = bytearray()
        self._next_id = 2
        self._registry_id = None
        self._manager_id = None
        self._seat_id = None
        self._sync_callbacks = set()
        self._objects = {WL_DISPLAY_ID: "wl_display"}
        self._pending = {}
        self.toplevels = {}
        self._dirty = False
        self._closed = False

    def _alloc_id(self, iface):
        obj_id = self._next_id
        self._next_id += 1
        self._objects[obj_id] = iface
        return obj_id

    def _send(self, object_id, opcode, payload=b""):
        if self._sock is None:
            return
        self._sock.sendall(pack_message(object_id, opcode, payload))

    def fileno(self):
        """Return socket file descriptor for GLib/selector event integration."""
        return -1 if self._sock is None else self._sock.fileno()

    @property
    def manager_bound(self):
        return self._manager_id is not None

    @property
    def seat_bound(self):
        return self._seat_id is not None

    def connect(self, wayland_display=None, runtime_dir=None, timeout=2.0):
        """Connect to Wayland, discover globals, and sync initial toplevel state."""
        sock_path = wayland_socket_path(wayland_display, runtime_dir)
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect(str(sock_path))
        self._sock = sock

        self._registry_id = self._alloc_id("wl_registry")
        self._send(WL_DISPLAY_ID, WL_DISPLAY_GET_REGISTRY, struct.pack("=I", self._registry_id))
        self._roundtrip()
        # A second roundtrip delivers initial toplevels emitted right after binding manager.
        if self._manager_id is not None:
            self._roundtrip()
        sock.setblocking(False)

    def _roundtrip(self):
        cb_id = self._alloc_id("wl_callback")
        self._sync_callbacks.add(cb_id)
        self._send(WL_DISPLAY_ID, WL_DISPLAY_SYNC, struct.pack("=I", cb_id))
        while cb_id in self._sync_callbacks:
            self._recv_once(blocking=True)
            self._drain_messages(emit=False)
        if self._dirty:
            self._dirty = False

    def _recv_once(self, blocking=False):
        if self._sock is None:
            return False
        if blocking:
            self._sock.setblocking(True)
        try:
            data, ancdata, _, _ = self._sock.recvmsg(65536, socket.CMSG_SPACE(64))
        except BlockingIOError:
            return False
        finally:
            if blocking and self._sock is not None:
                self._sock.setblocking(False)

        for cmsg_level, cmsg_type, cmsg_data in ancdata:
            if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                count = len(cmsg_data) // 4
                for fd in struct.unpack_from(f"={count}i", cmsg_data):
                    try:
                        os.close(fd)
                    except OSError:
                        pass

        if not data:
            raise WaylandProtocolError("Wayland socket closed by compositor")
        self._rx_buf.extend(data)
        return True

    def read_and_dispatch(self):
        """Read available non-blocking Wayland events and dispatch callbacks."""
        if self._closed or self._sock is None:
            return False
        try:
            while self._recv_once(blocking=False):
                pass
            self._drain_messages(emit=True)
            return True
        except (OSError, WaylandProtocolError) as err:
            self.close_client()
            if self.on_disconnect:
                self.on_disconnect(err)
            return False

    def feed_bytes(self, data, emit=True):
        """Feed raw wire bytes directly (used by unit tests)."""
        self._rx_buf.extend(data)
        self._drain_messages(emit=emit)

    def _drain_messages(self, emit=True):
        buf = self._rx_buf
        pos = 0
        total = len(buf)
        while pos + 8 <= total:
            obj_id, word = struct.unpack_from("=II", buf, pos)
            size = word >> 16
            opcode = word & 0xFFFF
            if size < 8 or size % 4 != 0:
                raise WaylandProtocolError(f"Malformed Wayland message size={size}")
            if pos + size > total:
                break
            payload = bytes(buf[pos + 8 : pos + size])
            pos += size
            self._dispatch_event(obj_id, opcode, payload)
        if pos:
            del buf[:pos]
        if emit and self._dirty:
            self._dirty = False
            if self.on_change:
                self.on_change(self.list_toplevels())

    def _dispatch_event(self, obj_id, opcode, payload):
        iface = self._objects.get(obj_id)
        if iface == "wl_display":
            if opcode == WL_DISPLAY_EVT_ERROR:
                err_obj, code = struct.unpack_from("=II", payload, 0)
                msg, _ = unpack_string(payload, 8)
                raise WaylandProtocolError(f"wl_display error obj={err_obj} code={code}: {msg}")
            if opcode == WL_DISPLAY_EVT_DELETE_ID:
                (deleted_id,) = struct.unpack_from("=I", payload, 0)
                self._objects.pop(deleted_id, None)
        elif iface == "wl_callback":
            if opcode == WL_CALLBACK_EVT_DONE:
                self._sync_callbacks.discard(obj_id)
                self._objects.pop(obj_id, None)
        elif iface == "wl_registry":
            if opcode == WL_REGISTRY_EVT_GLOBAL:
                (name,) = struct.unpack_from("=I", payload, 0)
                interface, next_off = unpack_string(payload, 4)
                (version,) = struct.unpack_from("=I", payload, next_off)
                self._handle_global(name, interface, version)
            elif opcode == WL_REGISTRY_EVT_GLOBAL_REMOVE:
                pass
        elif iface == "zwlr_foreign_toplevel_manager_v1":
            if opcode == ZWLR_TOPLEVEL_MANAGER_EVT_TOPLEVEL:
                (handle_id,) = struct.unpack_from("=I", payload, 0)
                self._objects[handle_id] = "zwlr_foreign_toplevel_handle_v1"
                self._pending[handle_id] = ToplevelInfo(handle_id=handle_id)
            elif opcode == ZWLR_TOPLEVEL_MANAGER_EVT_FINISHED:
                self._objects.pop(obj_id, None)
                if obj_id == self._manager_id:
                    self._manager_id = None
        elif iface == "zwlr_foreign_toplevel_handle_v1":
            self._handle_toplevel_event(obj_id, opcode, payload)

    def _handle_global(self, name, interface, version):
        if interface == "zwlr_foreign_toplevel_manager_v1" and self._manager_id is None:
            bind_ver = min(version, 3)
            self._manager_id = self._alloc_id("zwlr_foreign_toplevel_manager_v1")
            payload = struct.pack("=I", name) + pack_string(interface) + struct.pack("=II", bind_ver, self._manager_id)
            self._send(self._registry_id, WL_REGISTRY_BIND, payload)
        elif interface == "wl_seat" and self._seat_id is None:
            bind_ver = min(version, 1)
            self._seat_id = self._alloc_id("wl_seat")
            payload = struct.pack("=I", name) + pack_string(interface) + struct.pack("=II", bind_ver, self._seat_id)
            self._send(self._registry_id, WL_REGISTRY_BIND, payload)

    def _handle_toplevel_event(self, handle_id, opcode, payload):
        pending = self._pending.get(handle_id)
        if pending is None:
            existing = self.toplevels.get(handle_id)
            if existing is None:
                return
            pending = ToplevelInfo(
                handle_id=existing.handle_id,
                app_id=existing.app_id,
                title=existing.title,
                activated=existing.activated,
                minimized=existing.minimized,
                maximized=existing.maximized,
                fullscreen=existing.fullscreen,
                outputs=set(existing.outputs),
                ready=existing.ready,
            )
            self._pending[handle_id] = pending

        if opcode == ZWLR_TOPLEVEL_HANDLE_EVT_TITLE:
            pending.title, _ = unpack_string(payload, 0)
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_APP_ID:
            pending.app_id, _ = unpack_string(payload, 0)
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_OUTPUT_ENTER:
            (output_id,) = struct.unpack_from("=I", payload, 0)
            pending.outputs.add(output_id)
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_OUTPUT_LEAVE:
            (output_id,) = struct.unpack_from("=I", payload, 0)
            pending.outputs.discard(output_id)
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_STATE:
            states, _ = unpack_uint32_array(payload, 0)
            state_set = set(states)
            pending.maximized = STATE_MAXIMIZED in state_set
            pending.minimized = STATE_MINIMIZED in state_set
            pending.activated = STATE_ACTIVATED in state_set
            pending.fullscreen = STATE_FULLSCREEN in state_set
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_DONE:
            pending.ready = True
            self.toplevels[handle_id] = self._pending.pop(handle_id)
            self._dirty = True
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_CLOSED:
            self._pending.pop(handle_id, None)
            if handle_id in self.toplevels:
                self.toplevels.pop(handle_id, None)
                self._dirty = True
            try:
                self._send(handle_id, ZWLR_TOPLEVEL_HANDLE_DESTROY)
            except OSError:
                pass
            self._objects.pop(handle_id, None)
        elif opcode == ZWLR_TOPLEVEL_HANDLE_EVT_PARENT:
            pass

    def list_toplevels(self):
        """Return ready toplevel snapshots in insertion order."""
        return [item for item in self.toplevels.values() if item.ready]

    def activate(self, handle_id):
        """Unminimize if needed and activate a toplevel window on the bound wl_seat."""
        info = self.toplevels.get(handle_id)
        if info is None or self._seat_id is None:
            return False
        if info.minimized:
            self._send(handle_id, ZWLR_TOPLEVEL_HANDLE_UNSET_MINIMIZED)
        self._send(handle_id, ZWLR_TOPLEVEL_HANDLE_ACTIVATE, struct.pack("=I", self._seat_id))
        return True

    def set_minimized(self, handle_id, minimized=True):
        """Minimize or unminimize a toplevel window."""
        if handle_id not in self.toplevels:
            return False
        opcode = (
            ZWLR_TOPLEVEL_HANDLE_SET_MINIMIZED
            if minimized
            else ZWLR_TOPLEVEL_HANDLE_UNSET_MINIMIZED
        )
        self._send(handle_id, opcode)
        return True

    def close(self, handle_id):
        """Request closing a toplevel window."""
        if handle_id not in self.toplevels:
            return False
        self._send(handle_id, ZWLR_TOPLEVEL_HANDLE_CLOSE)
        return True

    def close_client(self):
        """Stop manager and close the Wayland socket cleanly."""
        if self._closed:
            return
        self._closed = True
        if self._sock is not None:
            if self._manager_id is not None:
                try:
                    self._send(self._manager_id, ZWLR_TOPLEVEL_MANAGER_STOP)
                except OSError:
                    pass
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None


def main():
    import json

    args = sys.argv[1:]
    client = WlrToplevelClient()
    client.connect()
    try:
        if args and args[0] == "--activate" and len(args) == 2:
            ok = client.activate(int(args[1]))
            print("ok" if ok else "not-found")
            return 0 if ok else 1
        if args and args[0] == "--close" and len(args) == 2:
            ok = client.close(int(args[1]))
            print("ok" if ok else "not-found")
            return 0 if ok else 1
        rows = [
            {
                "handle_id": item.handle_id,
                "app_id": item.app_id,
                "title": item.title,
                "activated": item.activated,
                "minimized": item.minimized,
                "maximized": item.maximized,
                "fullscreen": item.fullscreen,
            }
            for item in client.list_toplevels()
        ]
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0
    finally:
        client.close_client()


if __name__ == "__main__":
    sys.exit(main())
