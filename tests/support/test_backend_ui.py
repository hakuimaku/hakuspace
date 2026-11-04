#!/usr/bin/env python3
"""Keep compatibility-data recognition distinct from executable UI references."""
import importlib.util
from pathlib import Path
import unittest

# Load the checker without running any backend modules.
ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('backend_ui', ROOT / 'tools/checks/backend_ui.py')
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class BackendUiTests(unittest.TestCase):
    """Exercise both legitimate legacy data and forbidden UI dependencies."""

    def test_legacy_comparison_is_data(self):
        for source in (
            "legacy = value['argv'] == ['rofi', '-show', 'drun']",
            "label = ''; legacy = value['argv'] == ['rofi', '-show', 'drun']",
            "legacy = (value['argv'] == [\n    'rofi', '-show', 'drun'])",
        ):
            with self.subTest(source=source):
                self.assertEqual(checker.check_text('backend.py', source), [])

    def test_ui_calls_and_noncompatibility_references_fail(self):
        for source in (
            "subprocess.run(['rofi', '-show', 'drun'])",
            "launcher = 'rofi'",
            "subprocess.run(['sh', '-c', 'rofi -dmenu'])",
            "subprocess.run(['haku_pick.sh'])",
            "command('picker open')",
            "other = value['other'] == ['rofi', '-show', 'drun']",
            "legacy = value['argv'] == ['rofi', '-show', 'drun']; subprocess.run(['rofi'])",
        ):
            with self.subTest(source=source):
                self.assertEqual(len(checker.check_text('backend.py', source)), 1)

    def test_shell_guard_is_retained(self):
        self.assertTrue(checker.check_text('backend.sh', 'exec rofi -show drun'))
        self.assertTrue(checker.check_text('backend.sh', 'haku_pick.sh'))
        self.assertTrue(checker.check_text('backend.sh', 'picker open'))
        self.assertEqual(checker.check_text('backend.sh', 'printf "%s\\n" "$value"'), [])

    def test_current_general_backend_has_no_ui_dependency(self):
        path = ROOT / 'src/core/backend/user/general_menu_ctl.py'
        self.assertEqual(checker.check_text(str(path.relative_to(ROOT)), path.read_text()), [])


if __name__ == '__main__':
    unittest.main()
