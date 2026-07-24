import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts", "core"))
FIX = os.path.join(HERE, "fixtures", "quartz-bake", "內蒙古之旅")
FC = os.path.join(HERE, "fixtures", "quartz-bake", "_fc")

import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location(
    "quartz_bake", os.path.join(HERE, "..", "scripts", "core", "quartz-bake.py")
)
qb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qb)


class TestHelpers(unittest.TestCase):
    def test_parse_frontmatter_basic(self):
        text = open(os.path.join(FIX, "機票.md")).read()
        fm = qb.parse_frontmatter(text)
        self.assertEqual(fm.get("title"), "機票香港往海拉爾")
        self.assertEqual(fm.get("start"), "12:05")
        self.assertEqual(fm.get("itinerary"), "true")
        self.assertEqual(fm.get("location"), "49.2050,119.8250")

    def test_parse_frontmatter_none(self):
        self.assertEqual(qb.parse_frontmatter("no frontmatter here"), {})

    def test_find_fenced_blocks(self):
        md = open(os.path.join(FIX, "00-dash.md")).read()
        langs = [b[2] for b in qb.find_fenced_blocks(md)]
        self.assertEqual(langs, ["mapview", "dataview", "dataview", "dataview"])


if __name__ == "__main__":
    unittest.main()
