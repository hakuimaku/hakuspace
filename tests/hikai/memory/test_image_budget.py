#!/usr/bin/env python3
"""Guard bounded decoding for user-content Image objects in Hikai components."""
from pathlib import Path
import re
import unittest

# IconImage bounds its backing Image to actualSize in Quickshell.Widgets.
COMPONENTS = Path(__file__).resolve().parents[3] / "src/home/.config/quickshell/hakuspace/components"


def image_blocks(source):
    """Find Image bodies while ignoring braces inside strings and comments."""
    tokens = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                    lambda match: " " * len(match[0]), source)
    for match in re.finditer(r'\bImage\s*\{', tokens):
        depth = 1
        end = match.end()
        while end < len(tokens) and depth:
            depth += (tokens[end] == "{") - (tokens[end] == "}")
            end += 1
        yield tokens[match.end():end - 1]


class ImageBudget(unittest.TestCase):
    """Require explicit decode bounds on dynamically sourced raster images."""

    def test_dynamic_images_are_bounded(self):
        checked = 0
        for path in COMPONENTS.rglob("*.qml"):
            for block in image_blocks(path.read_text()):
                checked += 1
                self.assertTrue(re.search(r'\bsourceSize\s*:', block)
                                or (re.search(r'\bsourceSize\.width\s*:', block)
                                    and re.search(r'\bsourceSize\.height\s*:', block)), str(path))
        self.assertGreaterEqual(checked, 8)

    def test_scanner(self):
        self.assertEqual(len(list(image_blocks('Image { source: "brace}.png"; onStatusChanged: { if (true) {} } }'))), 1)
        self.assertEqual(list(image_blocks('// Image {}\nIconImage {}')), [])


if __name__ == "__main__":
    unittest.main()
