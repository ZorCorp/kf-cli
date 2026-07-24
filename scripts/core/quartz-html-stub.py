#!/usr/bin/env python3
"""Generate an indexed companion stub for a raw HTML file published to Quartz.

Quartz serves content/*.html byte-identical at its extensionless URL but does NOT
add it to the content index (invisible to Explorer/search/graph). This stub — an
ordinary indexed .md next to the html — surfaces it: it links to the raw page and
embeds it in an <iframe>. The stub route (<base>-embed) never collides with the
html route (<base>).

Usage: quartz-html-stub.py <html_path> <site_path> <base> [--name]
  default  -> prints the stub markdown body
  --name   -> prints the collision-safe stub filename (<base>-embed.md)
"""
import re
import sys


def extract_title(html_text, fallback):
    m = re.search(r"<title[^>]*>(.*?)</title>", html_text, re.IGNORECASE | re.DOTALL)
    if not m:
        return fallback
    title = re.sub(r"\s+", " ", m.group(1)).strip()
    return title or fallback


def stub_filename(base):
    # <base>-embed.md — route "<base>-embed" never equals the html route "<base>"
    return "%s-embed.md" % base


def stub_markdown(title, site_path, base):
    safe_title = title.replace('"', '\\"')
    return (
        "---\n"
        'title: "%s"\n'
        "tags: [html-embed]\n"
        "---\n"
        "\n"
        "原始檔全屏開啟：[%s](%s)\n"
        "\n"
        '<iframe src="%s" style="width:100%%;height:80vh;border:none"></iframe>\n'
        % (safe_title, base, site_path, site_path)
    )


def main(argv):
    if len(argv) < 4:
        sys.stderr.write("usage: quartz-html-stub.py <html_path> <site_path> <base> [--name]\n")
        return 2
    html_path, site_path, base = argv[1], argv[2], argv[3]
    if "--name" in argv[4:]:
        sys.stdout.write(stub_filename(base) + "\n")
        return 0
    try:
        html_text = open(html_path, encoding="utf-8", errors="ignore").read()
    except OSError:
        html_text = ""
    title = extract_title(html_text, base)
    sys.stdout.write(stub_markdown(title, site_path, base))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
