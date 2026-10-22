#!/usr/bin/env python3
"""Send real keyboard events to the disposable Wayland menu test session."""
import array
import os
from pathlib import Path
import socket
import struct
import sys
import time

from wayland_pointer_fixture import receive, send, string


# Compile the standard US layout in the compositor without external input tools.
KEYMAP = b'''xkb_keymap {
    xkb_keycodes { include "evdev+aliases(qwerty)" };
    xkb_types { include "complete" };
    xkb_compatibility { include "complete" };
    xkb_symbols { include "pc+us+inet(evdev)" };
};\0'''
KEYS = dict(zip('abcdefghijklmnopqrstuvwxyz',
                (30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50,
                 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44)))
KEYS.update({' ': 57, '>': 52, '~': 41})
# Standard XKB bits for Shift, Control and Alt.
MODIFIER_MASK = 1 | 4 | 8


def main():
    """Bind the private seat, publish a keymap and consume key/text requests."""
    display = Path(os.environ['WAYLAND_DISPLAY'])
    if not display.is_absolute():
        display = Path(os.environ['XDG_RUNTIME_DIR']) / display
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(str(display))
        send(connection, 1, 1, struct.pack('=I', 2))
        send(connection, 1, 0, struct.pack('=I', 3))
        globals = {}
        while True:
            object_id, opcode, payload = receive(connection)
            if object_id == 3 and opcode == 0:
                break
            if object_id == 2 and opcode == 0:
                name, length = struct.unpack_from('=II', payload)
                globals[payload[8:8 + length - 1].decode()] = name
        send(connection, 2, 0, struct.pack('=I', globals['zwp_virtual_keyboard_manager_v1'])
             + string('zwp_virtual_keyboard_manager_v1') + struct.pack('=II', 1, 4))
        send(connection, 2, 0, struct.pack('=I', globals['wl_seat'])
             + string('wl_seat') + struct.pack('=II', 1, 5))
        send(connection, 4, 0, struct.pack('=II', 5, 6))
        descriptor = os.memfd_create('hakumenu-keymap')
        try:
            os.write(descriptor, KEYMAP)
            connection.sendmsg([struct.pack('=IIII', 6, 16 << 16, 1, len(KEYMAP))],
                               [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [descriptor]))])
        finally:
            os.close(descriptor)
        send(connection, 1, 0, struct.pack('=I', 7))
        while receive(connection)[0] != 7:
            pass

        # Every request releases modifiers after its key to avoid cross-test state.
        def tap(code, modifiers=0):
            if not (0 <= code <= 255 and modifiers >= 0 and (modifiers & ~MODIFIER_MASK) == 0):
                raise ValueError('invalid keyboard fixture key or modifiers')
            timestamp = int(time.monotonic() * 1000) & 0xffffffff
            send(connection, 6, 2, struct.pack('=IIII', modifiers, 0, 0, 0))
            for pressed in (1, 0):
                send(connection, 6, 1, struct.pack('=III', timestamp, code, pressed))
            send(connection, 6, 2, struct.pack('=IIII', 0, 0, 0, 0))

        for line in sys.stdin:
            command, value = line.rstrip('\n').split(' ', 1)
            if command == 'text':
                for char in value:
                    tap(KEYS[char.lower()], int(char.isupper() or char in '>~'))
            elif command == 'key':
                tap(*map(int, value.split()))
            elif command == 'alt-tab':
                # Keep Alt physically held across Tab and release without a pause.
                alt, shift, alt_first = map(int, value.split())
                if alt not in (56, 100) or shift not in (0, 1) or alt_first not in (0, 1):
                    raise ValueError('invalid Alt-Tab chord')
                timestamp = int(time.monotonic() * 1000) & 0xffffffff
                send(connection, 6, 2, struct.pack('=IIII', shift, 0, 0, 0))
                send(connection, 6, 1, struct.pack('=III', timestamp, alt, 1))
                send(connection, 6, 2, struct.pack('=IIII', 8 | shift, 0, 0, 0))
                send(connection, 6, 1, struct.pack('=III', timestamp, 15, 1))
                for code in ((alt, 15) if alt_first else (15, alt)):
                    send(connection, 6, 1, struct.pack('=III', timestamp, code, 0))
                send(connection, 6, 2, struct.pack('=IIII', 0, 0, 0, 0))
            else:
                raise ValueError('unknown keyboard fixture command')


if __name__ == '__main__':
    main()
