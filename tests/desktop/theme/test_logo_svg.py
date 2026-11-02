#!/usr/bin/env python3
"""Targeted unit tests for HakuSpace SVG logo generator and assets."""

import hashlib
import subprocess
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
BUILD_SCRIPT = REPO_ROOT / "scripts/build_logo_svg.py"
ASSETS_DIR = REPO_ROOT / "assets"
WHITE_SVG = ASSETS_DIR / "logo-white.svg"
BLACK_SVG = ASSETS_DIR / "logo-black.svg"


class TestHakuSpaceLogoSvg(unittest.TestCase):
    def test_build_script_exists_and_executable(self):
        self.assertTrue(BUILD_SCRIPT.is_file(), f"Missing build script: {BUILD_SCRIPT}")

    def test_build_check_flag(self):
        result = subprocess.run(
            [sys_exec := "/usr/bin/python3", str(BUILD_SCRIPT), "--check"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, f"--check failed: {result.stderr}")
        self.assertIn("Verification passed", result.stdout)

    def test_build_determinism(self):
        hash_black_1 = hashlib.sha256(BLACK_SVG.read_bytes()).hexdigest()
        hash_white_1 = hashlib.sha256(WHITE_SVG.read_bytes()).hexdigest()

        # Re-run build
        result = subprocess.run(
            ["/usr/bin/python3", str(BUILD_SCRIPT)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, f"Build rerun failed: {result.stderr}")

        hash_black_2 = hashlib.sha256(BLACK_SVG.read_bytes()).hexdigest()
        hash_white_2 = hashlib.sha256(WHITE_SVG.read_bytes()).hexdigest()

        self.assertEqual(hash_black_1, hash_black_2, "Black SVG hash changed across runs")
        self.assertEqual(hash_white_1, hash_white_2, "White SVG hash changed across runs")

    def test_xml_structure_and_contract(self):
        tree_w = ET.parse(WHITE_SVG)
        tree_b = ET.parse(BLACK_SVG)

        root_w = tree_w.getroot()
        root_b = tree_b.getroot()

        self.assertEqual(root_w.tag, "{http://www.w3.org/2000/svg}svg")
        self.assertEqual(root_b.tag, "{http://www.w3.org/2000/svg}svg")

        self.assertEqual(root_w.attrib.get("viewBox"), "0 0 1024 1024")
        self.assertEqual(root_b.attrib.get("viewBox"), "0 0 1024 1024")

        self.assertEqual(root_w.attrib.get("fill"), "none")
        self.assertEqual(root_b.attrib.get("fill"), "none")

        # No forbidden elements
        forbidden = {"image", "filter", "linearGradient", "radialGradient", "mask"}
        for root in (root_w, root_b):
            for elem in root.iter():
                tag_local = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
                self.assertNotIn(tag_local, forbidden, f"Forbidden tag <{tag_local}> found")
                for attr_name, attr_val in elem.attrib.items():
                    self.assertNotIn("base64", attr_val)
                    self.assertNotIn("data:image", attr_val)

        # Paths geometry equality
        paths_w = root_w.findall("{http://www.w3.org/2000/svg}path")
        paths_b = root_b.findall("{http://www.w3.org/2000/svg}path")
        self.assertEqual(len(paths_w), len(paths_b))
        self.assertEqual(len(paths_w), 4)

        for pw, pb in zip(paths_w, paths_b):
            self.assertEqual(pw.attrib["d"], pb.attrib["d"])
            self.assertEqual(pw.attrib["stroke-width"], pb.attrib["stroke-width"])
            self.assertEqual(pw.attrib["stroke-linecap"], "round")
            self.assertEqual(pb.attrib["stroke-linecap"], "round")
            self.assertEqual(pw.attrib["stroke-linejoin"], "round")
            self.assertEqual(pb.attrib["stroke-linejoin"], "round")
            self.assertEqual(pw.attrib["stroke"], "#FFFFFF")
            self.assertEqual(pb.attrib["stroke"], "#000000")

    def test_git_whitespace(self):
        res = subprocess.run(
            ["git", "diff", "--check", str(BUILD_SCRIPT), str(WHITE_SVG), str(BLACK_SVG)],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, f"git diff --check reported whitespace issues: {res.stdout}")


if __name__ == "__main__":
    unittest.main()
