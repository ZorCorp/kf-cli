import importlib.util
import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "core", "quartz-html-stub.py")
_spec = importlib.util.spec_from_file_location("quartz_html_stub", SCRIPT)
hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hs)


class TestHtmlStub(unittest.TestCase):
    def test_extract_title_found(self):
        html = "<html><head><title>  My  Deck </title></head><body>x</body></html>"
        self.assertEqual(hs.extract_title(html, "fallback"), "My Deck")

    def test_extract_title_fallback(self):
        self.assertEqual(hs.extract_title("<html><body>no title</body></html>", "foo"), "foo")

    def test_stub_filename_is_collision_safe(self):
        # stub route (foo-embed) must never equal the html route (foo)
        name = hs.stub_filename("foo")
        self.assertEqual(name, "foo-embed.md")
        self.assertNotEqual(os.path.splitext(name)[0], "foo")      # not the html route
        self.assertNotEqual(name, "foo.md")                        # never bare foo.md

    def test_stub_markdown_contents(self):
        md = hs.stub_markdown("我的簡報", "/notes/內蒙古之旅/foo", "foo")
        self.assertIn("tags: [html-embed]", md)
        self.assertIn('title: "我的簡報"', md)
        # link + iframe both point at the extensionless site path
        self.assertIn("(/notes/內蒙古之旅/foo)", md)
        self.assertIn('<iframe src="/notes/內蒙古之旅/foo"', md)

    def test_title_with_quotes_is_yaml_safe(self):
        md = hs.stub_markdown('He said "hi"', "/n/foo", "foo")
        # internal double-quotes escaped so the YAML frontmatter stays valid
        self.assertIn(r'title: "He said \"hi\""', md)

    def test_cli_name_and_body(self):
        name = subprocess.run(
            [sys.executable, SCRIPT, "/dev/null", "/notes/x/foo", "foo", "--name"],
            capture_output=True, text=True,
        ).stdout.strip()
        self.assertEqual(name, "foo-embed.md")
        body = subprocess.run(
            [sys.executable, SCRIPT, "/dev/null", "/notes/x/foo", "foo"],
            capture_output=True, text=True,
        ).stdout
        self.assertIn("html-embed", body)


if __name__ == "__main__":
    unittest.main()
