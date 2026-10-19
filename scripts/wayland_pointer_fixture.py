#!/usr/bin/env python3
"""Deliver stdin pointer events to an isolated Wayland compositor for Dock tests."""
import os
from pathlib import Path
import socket
import struct
import sys
import time


# Encode native Wayland strings with their terminating byte and four-byte padding.
def string(value):
    encoded = value.encode() + b'\0'
    return struct.pack('=I', len(encoded)) + encoded + b'\0' * (-len(encoded) % 4)


# Frame a request using the native Wayland object/opcode header.
def send(connection, object_id, opcode, payload=b''):
    connection.sendall(struct.pack('=II', object_id, ((len(payload) + 8) << 16) | opcode) + payload)


# Read complete messages even when the stream splits a header or payload.
def receive(connection):
    def exact(size):
        data = b''
        while len(data) < size:
            part = connection.recv(size - len(data))
            if not part:
                raise RuntimeError('Wayland compositor disconnected')
            data += part
        return data
    object_id, header = struct.unpack('=II', exact(8))
    size, opcode = header >> 16, header & 0xffff
    if size < 8:
        raise RuntimeError('invalid Wayland message')
    payload = exact(size - 8)
    if object_id == 1 and opcode == 0:
        raise RuntimeError('Wayland protocol error: ' + repr(payload))
    return object_id, opcode, payload


# Bind the virtual-pointer manager and first output advertised by the private compositor.
def main():
    display = Path(os.environ['WAYLAND_DISPLAY'])
    if not display.is_absolute():
        display = Path(os.environ['XDG_RUNTIME_DIR']) / display
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(str(display))
        send(connection, 1, 1, struct.pack('=I', 2))
        send(connection, 1, 0, struct.pack('=I', 3))
        globals = {}
        outputs = []
        while True:
            object_id, opcode, payload = receive(connection)
            if object_id == 3 and opcode == 0:
                break
            if object_id == 2 and opcode == 0:
                name, length = struct.unpack_from('=II', payload)
                interface = payload[8:8 + length - 1].decode()
                version = struct.unpack_from('=I', payload, 8 + ((length + 3) & ~3))[0]
                globals.setdefault(interface, (name, version))
                if interface == 'wl_output':
                    outputs.append((name, version))
        manager, version = globals['zwlr_virtual_pointer_manager_v1']
        if version < 2:
            raise RuntimeError('output-mapped virtual pointers require protocol version 2')
        send(connection, 2, 0, struct.pack('=I', manager) + string('zwlr_virtual_pointer_manager_v1') + struct.pack('=II', 2, 4))
        # Named mapping stays stable when output-manager commits reorder globals.
        requested_output = os.environ.get('HAKUSPACE_TEST_POINTER_OUTPUT')
        if requested_output:
            for index, (name, output_version) in enumerate(outputs):
                if output_version < 4:
                    raise RuntimeError('named output mapping requires wl_output version 4')
                send(connection, 2, 0, struct.pack('=I', name) + string('wl_output') + struct.pack('=II', 4, 5 + index))
            sync_id = 5 + len(outputs)
            send(connection, 1, 0, struct.pack('=I', sync_id))
            output_id = None
            while True:
                object_id, opcode, payload = receive(connection)
                if object_id == sync_id and opcode == 0:
                    break
                if 5 <= object_id < 5 + len(outputs) and opcode == 4:
                    length = struct.unpack_from('=I', payload)[0]
                    if payload[4:4 + length - 1].decode() == requested_output:
                        output_id = object_id
            if output_id is None:
                raise RuntimeError('requested pointer output not found: ' + requested_output)
            pointer_id = sync_id + 1
        else:
            output, _ = globals['wl_output']
            output_id = 5
            pointer_id = 6
            send(connection, 2, 0, struct.pack('=I', output) + string('wl_output') + struct.pack('=II', 1, output_id))
        send(connection, 4, 2, struct.pack('=III', 0, output_id, pointer_id))
        send(connection, 1, 0, struct.pack('=I', pointer_id + 1))
        while receive(connection)[0] != pointer_id + 1:
            pass
        # Each line moves the pointer and optionally clicks a Linux input button code.
        for line in sys.stdin:
            x, y, width, height, button = map(int, line.split())
            if not (0 <= x < width and 0 <= y < height and button in (0, 272, 273, 274)):
                raise ValueError('invalid pointer fixture coordinates or button')
            timestamp = int(time.monotonic() * 1000) & 0xffffffff
            send(connection, pointer_id, 1, struct.pack('=IIIII', timestamp, x, y, width, height))
            send(connection, pointer_id, 4)
            if button:
                for state in (1, 0):
                    send(connection, pointer_id, 2, struct.pack('=III', timestamp, button, state))
                    send(connection, pointer_id, 4)


if __name__ == '__main__':
    main()
