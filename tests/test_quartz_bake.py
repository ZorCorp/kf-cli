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


class TestDataviewTable(unittest.TestCase):
    def test_table_renders_itinerary_rows_sorted(self):
        query = (
            'TABLE WITHOUT ID file.link as "項目", date as "日期", '
            'start as "開始", end as "結束", place as "地點"\n'
            'FROM "notes/內蒙古之旅"\nWHERE itinerary\nSORT date ASC, start ASC'
        )
        out = qb.bake_dataview(query, FIX)
        self.assertIsNotNone(out)
        lines = [l for l in out.splitlines() if l.strip()]
        # header + separator + 2 itinerary rows (參考.md excluded, no itinerary flag)
        self.assertEqual(lines[0], "| 項目 | 日期 | 開始 | 結束 | 地點 |")
        self.assertEqual(lines[1], "| --- | --- | --- | --- | --- |")
        self.assertEqual(len(lines), 4)
        # sorted by date ASC → 機票 (09-05) before 莫日格勒河 (09-13)
        self.assertIn("[[機票]]", lines[2])
        self.assertEqual(lines[2], "| [[機票]] | 2026-09-05 | 12:05 | 16:40 | 香港 → 海拉爾 |")
        # missing `end` on 莫日格勒河 → empty cell
        self.assertEqual(lines[3], "| [[莫日格勒河]] | 2026-09-13 | 10:00 |  | 海拉爾 |")

    def test_table_unparseable_returns_none(self):
        # dateformat(...) predicate is beyond the minimal engine
        query = (
            'TABLE WITHOUT ID file.link as "項目"\nFROM "notes/內蒙古之旅"\n'
            'WHERE itinerary AND dateformat(date, "yyyy-MM-dd") = dateformat(date(today), "yyyy-MM-dd")\n'
            'SORT start ASC'
        )
        self.assertIsNone(qb.bake_dataview(query, FIX))


class TestDataviewTask(unittest.TestCase):
    def test_task_groups_incomplete_by_file(self):
        out = qb.bake_dataview('TASK FROM "notes/內蒙古之旅"\nWHERE !completed', FIX)
        self.assertIsNotNone(out)
        self.assertIn("**[[機票]]**", out)
        self.assertIn("- [ ] 買機票", out)
        self.assertNotIn("訂座位", out)      # completed -> excluded
        self.assertIn("**[[莫日格勒河]]**", out)
        self.assertIn("- [ ] 帶相機", out)


if __name__ == "__main__":
    unittest.main()
