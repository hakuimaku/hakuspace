#!/usr/bin/env python3
"""Check desktop discovery metadata without changing raw list output."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BACKEND = Path(__file__).resolve().parents[1] / "src/core/backend/desktop/shortcut_ctl.sh"
FACADE = Path(__file__).resolve().parents[1] / "src/core/facade/gen_shortcut.sh"


class ShortcutMetadataTest(unittest.TestCase):
    def test_structured_list_and_raw_compatibility(self):
        with tempfile.TemporaryDirectory() as tmp:
            apps = Path(tmp) / "apps"
            apps.mkdir()
            app = apps / "quote.desktop"
            app.write_text('[Desktop Entry]\nName=Quote "App"\nCategories=Utility;\nIcon=quote-app\n', encoding="utf-8")
            hidden = apps / "hidden.desktop"
            hidden.write_text('[Desktop Entry]\nName=Hidden\nNoDisplay=true\n', encoding="utf-8")
            env = {**os.environ, "HAKUSPACE_SHORTCUT_SEARCH_DIRS": str(apps)}
            raw = subprocess.check_output([BACKEND, "list"], env=env, text=True).splitlines()
            structured = json.loads(subprocess.check_output([BACKEND, "list-json"], env=env, text=True))
            self.assertEqual(set(raw), {str(app), str(hidden)})
            self.assertEqual(structured, [{"name": 'Quote "App"', "path": str(app),
                                           "categories": "Utility;", "icon": "quote-app"}])

    def test_menu_routes_by_backend(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            app_dir = Path(tmp) / "apps"
            bin_dir = Path(tmp) / "bin"
            home.mkdir()
            app_dir.mkdir()
            bin_dir.mkdir()
            (app_dir / "test.desktop").write_text("[Desktop Entry]\nName=Test\n", encoding="utf-8")
            for name in ("rofi", "qs"):
                script = bin_dir / name
                script.write_text("#!/bin/sh\nprintf '%s\\n' \"$0 $*\" >> \"$CALL_LOG\"\n", encoding="utf-8")
                script.chmod(0o755)
            log = Path(tmp) / "calls"
            env = {**os.environ, "HOME": str(home), "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                   "CALL_LOG": str(log), "HAKUSPACE_SHORTCUT_SEARCH_DIRS": str(app_dir),
                   "XDG_RUNTIME_DIR": str(Path(tmp) / "runtime")}
            subprocess.run([FACADE, "--menu"], env=env, check=True, capture_output=True, text=True)
            self.assertIn("rofi -dmenu", log.read_text())
            state = home / ".local/state/hakuspace/state/shell_backend"
            state.write_text("hikai\n")
            log.write_text("")
            subprocess.run([FACADE, "--menu"], env=env, check=True, capture_output=True, text=True)
            self.assertIn("qs -c hakuspace ipc call actionMenu openDefault shortcut", log.read_text())
            self.assertNotIn("rofi", log.read_text())

    def test_headless_facade_compatibility(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            apps = root / "apps"
            desktop = root / "Desktop"
            apps.mkdir()
            app = apps / "sample.desktop"
            app.write_text("[Desktop Entry]\nType=Application\nName=Sample\nExec=true\n", encoding="utf-8")
            env = {**os.environ, "HAKUSPACE_SHORTCUT_SEARCH_DIRS": str(apps),
                   "HAKUSPACE_SHORTCUT_DESKTOP_DIR": str(desktop)}

            def call(*args):
                return subprocess.check_output([FACADE, *args], env=env, text=True)

            self.assertEqual(call("--list").strip(), str(app))
            self.assertIn("Total matching applications found: 1", call("--query", "sample"))
            call("--add", str(app))
            self.assertEqual((desktop / app.name).read_text(), app.read_text())
            call("--create", "Created", "/usr/bin/true")
            self.assertIn("Name=Created", (desktop / "Created.desktop").read_text())
            call("Legacy", "/usr/bin/true")
            self.assertIn("Name=Legacy", (desktop / "Legacy.desktop").read_text())


if __name__ == "__main__":
    unittest.main()
