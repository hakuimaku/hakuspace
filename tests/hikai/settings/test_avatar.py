#!/usr/bin/env python3
"""Check avatar replacement failures against disposable user data."""
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

# The production controller accepts the same PNG format produced by the crop canvas.
CONTROLLER = Path(__file__).resolve().parents[3] / "src/core/backend/user/avatar_ctl.sh"


def png(color):
    """Build a tiny valid PNG without requiring an imaging library."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\0" + color)) + chunk(b"IEND", b""))


class AvatarTests(unittest.TestCase):
    """Exercise atomic same-format writes and failures before commit."""

    def test_failed_source_and_replacement_preserve_current(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            store = root / "user"
            first, second = root / "first.png", root / "second.png"
            first.write_bytes(png(b"\x10\x20\x30"))
            second.write_bytes(png(b"\x30\x20\x10"))
            environment = {**os.environ, "HAKUSPACE_USER_DIR": str(store)}

            def call(*args):
                return subprocess.run([str(CONTROLLER), *args], env=environment, text=True, capture_output=True)

            self.assertEqual(call("set", str(first)).returncode, 0)
            current = Path(call("current").stdout.strip())
            self.assertEqual(current.read_bytes(), first.read_bytes())
            self.assertNotEqual(call("set", str(root / "missing.png")).returncode, 0)
            self.assertEqual(current.read_bytes(), first.read_bytes())
            bad = root / "bad.png"
            bad.write_text("unsupported image")
            self.assertNotEqual(call("set", str(bad)).returncode, 0)
            self.assertEqual(current.read_bytes(), first.read_bytes())
            (store / "avatar.path").chmod(0o644)
            self.assertEqual(call("set", str(second)).returncode, 0)
            self.assertEqual((store / "avatar.path").stat().st_mode & 0o777, 0o600)
            self.assertEqual(current.read_bytes(), second.read_bytes())
            self.assertEqual(current.stat().st_mode & 0o777, 0o600)
            self.assertEqual((store / "avatar.path").read_text(), "avatar.png\n")
            self.assertFalse(list(store.glob(".avatar*")))
            external_manifest = root / "external-manifest"
            external_manifest.write_text("avatar.png\n")
            (store / "avatar.path").unlink()
            (store / "avatar.path").symlink_to(external_manifest)
            self.assertNotEqual(call("set", str(first)).returncode, 0)
            self.assertEqual(current.read_bytes(), second.read_bytes())
            self.assertTrue((store / "avatar.path").is_symlink())
            self.assertEqual(external_manifest.read_text(), "avatar.png\n")

    def test_failed_copy_preserves_same_format_avatar(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            store = root / "user"
            store.mkdir()
            current = store / "avatar.png"
            current.write_bytes(png(b"\x10\x20\x30"))
            (store / "avatar.path").write_text("avatar.png\n")
            source = root / "new.png"
            source.write_bytes(png(b"\x30\x20\x10"))
            tools = root / "bin"
            tools.mkdir()
            (tools / "cp").write_text("#!/bin/sh\nexit 1\n")
            (tools / "cp").chmod(0o755)
            environment = {**os.environ, "HAKUSPACE_USER_DIR": str(store), "PATH": str(tools) + os.pathsep + os.environ["PATH"]}
            result = subprocess.run([str(CONTROLLER), "set", str(source)], env=environment, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(current.read_bytes(), png(b"\x10\x20\x30"))
            self.assertEqual((store / "avatar.path").read_text(), "avatar.png\n")

    def test_failed_manifest_commit_keeps_previous_format(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            store = root / "user"
            store.mkdir()
            previous = store / "avatar.jpg"
            previous.write_bytes(png(b"\x10\x20\x30"))
            (store / "avatar.path").write_text("avatar.jpg\n")
            source = root / "new.png"
            source.write_bytes(png(b"\x30\x20\x10"))
            tools = root / "bin"
            tools.mkdir()
            (tools / "mv").write_text('#!/bin/sh\ncase "$*" in *".avatar.path.tmp."*) exit 1 ;; esac\nexec /usr/bin/mv "$@"\n')
            (tools / "mv").chmod(0o755)
            environment = {**os.environ, "HAKUSPACE_USER_DIR": str(store), "PATH": str(tools) + os.pathsep + os.environ["PATH"]}
            result = subprocess.run([str(CONTROLLER), "set", str(source)], env=environment, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(previous.read_bytes(), png(b"\x10\x20\x30"))
            self.assertEqual((store / "avatar.path").read_text(), "avatar.jpg\n")
            self.assertFalse((store / "avatar.png").exists())
            self.assertFalse(list(store.glob(".avatar*")))


if __name__ == "__main__":
    unittest.main()
