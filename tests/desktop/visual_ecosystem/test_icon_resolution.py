"""Managed discovery and legacy-state safety without touching host assets."""
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

# Exercise the same resolver used by source-tree and deployed controllers.
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'src/core/theme'))
import appearance_icons as app


class IconResolutionTests(unittest.TestCase):
    def setUp(self):
        """Provide private user and system roots with a custom XDG data directory."""
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.xdg = self.home / 'data/icons'
        self.legacy = self.home / '.icons'
        self.system = self.home / 'system/icons'
        environment = patch.dict(os.environ, HOME=str(self.home), HAKU_ICON_DIR='',
                                 XDG_DATA_HOME=str(self.home / 'data'), XDG_STATE_HOME=str(self.home / 'state'))
        environment.start()
        self.addCleanup(environment.stop)
        system_roots = patch.object(app, 'SYSTEM_ROOTS', (self.system,))
        system_roots.start()
        self.addCleanup(system_roots.stop)

    def pair(self, root):
        """Create the exact managed family metadata required by the resolver."""
        for name, mode in app.VARIANTS.items():
            path = root / name
            path.mkdir(parents=True)
            (path / 'index.theme').write_text(f'[Icon Theme]\nName={name}\n')
            (path / '.hikaide-symbols.json').write_text(json.dumps({
                'family': 'Hikaide-Symbols', 'version': 2, 'variant': mode}))
        return root / 'Hikaide-Symbols'

    def test_xdg_priority_and_explicit_override(self):
        """Discovery and target enumeration share a deterministic root order."""
        legacy = self.pair(self.legacy)
        self.assertEqual(app.resolve(legacy.name, 'auto')['directory'], str(legacy))
        xdg = self.pair(self.xdg)
        result = app.resolve(xdg.name, 'auto')
        self.assertEqual(result['directory'], str(xdg))
        self.assertEqual(len(result['targets']), 4)
        with patch.dict(os.environ, HAKU_ICON_DIR=str(self.legacy)):
            result = app.resolve(xdg.name, 'auto')
            self.assertEqual(result['directory'], str(legacy))
            self.assertEqual(len(result['targets']), 2)

    def test_system_install_is_discovered_without_write_targets(self):
        """System copies can be activated even when owned by the current UID."""
        theme = self.pair(self.system)
        before = {path: path.read_bytes() for path in theme.parent.rglob('*') if path.is_file()}
        result = app.resolve(theme.name, 'auto')
        self.assertEqual(result['directory'], str(theme))
        self.assertEqual(result['policy'], 'not-applicable')
        self.assertEqual(result['targets'], [])
        self.assertEqual(before, {path: path.read_bytes() for path in before})
        self.assertFalse((self.home / 'state').exists())

    def test_unowned_or_unwritable_install_has_no_write_targets(self):
        """A managed marker never overrides filesystem ownership or writability."""
        theme = self.pair(self.xdg)
        with patch.object(app.os, 'getuid', return_value=os.getuid() + 1):
            self.assertEqual(app.resolve(theme.name, 'auto')['targets'], [])
        with patch.object(app.os, 'access', return_value=False):
            self.assertEqual(app.resolve(theme.name, 'auto')['targets'], [])

    def test_invalid_name_version_family_and_variant_are_rejected(self):
        """Both theme identity and exact managed metadata authorize mutation."""
        theme = self.pair(self.xdg)
        marker = theme / '.hikaide-symbols.json'
        valid = marker.read_text()
        for data in ('{', '[]', valid.replace('2', '3'), valid.replace('dark', 'light'), valid.replace('Hikaide-Symbols', 'Other')):
            with self.subTest(data=data):
                marker.write_text(data)
                self.assertEqual(app.resolve(theme.name, 'auto')['targets'], [])
        marker.write_text(valid)
        (theme / 'index.theme').write_text('[Icon Theme]\nName=Other\n')
        self.assertEqual(app.resolve(theme.name, 'auto')['targets'], [])
        self.assertIsNone(app.icon_directory('../Hikaide-Symbols'))

    def test_legacy_cleanup_removes_empty_parent_and_preserves_unverified_paths(self):
        """Migration requires exact theme, path, backend and hashed entry identity."""
        theme = self.pair(self.xdg)
        state_root = self.home / 'state/icon-accent'
        key = theme.name + '-' + hashlib.sha256(str(theme).encode()).hexdigest()[:16]
        entry = state_root / key
        entry.mkdir(parents=True)
        state = dict(theme=theme.name, location=str(theme), backend='kde-colorscheme', files={})
        state_file = entry / 'state.json'
        state_file.write_text(json.dumps(dict(state, backend='unverified')))
        app.cleanup_legacy_state()
        self.assertTrue(state_file.exists())
        state_file.write_text(json.dumps(state))
        outside = self.home / 'outside-state'
        outside.mkdir()
        (state_root / 'Hikaide-Symbols-unsafe').symlink_to(outside)
        app.cleanup_legacy_state()
        self.assertFalse(entry.exists())
        self.assertTrue(outside.exists())
        (state_root / 'Hikaide-Symbols-unsafe').unlink()
        app.cleanup_legacy_state()
        self.assertFalse(state_root.exists())
        app.cleanup_legacy_state()


if __name__ == '__main__':
    unittest.main()
