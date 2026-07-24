#!/usr/bin/env python3
"""Bake pass for kf-cli:quartz.

Transforms dataview / mapview fenced blocks in a Quartz content COPY into static
markdown / HTML. Best-effort: anything unparseable is left untouched and a
warning is emitted. Sibling frontmatter and geojson are read from the VAULT
SOURCE FOLDER (arg 2), never from the copy destination.

Usage: quartz-bake.py <baked_copy_md_path> <vault_source_folder>
"""
import glob
import json
import os
import re
import sys


def parse_frontmatter(text):
    """Minimal flat-YAML frontmatter parser. key: value pairs only."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
        if not mm:
            continue  # nested list items / multi-line — ignored (best-effort)
        key, val = mm.group(1), mm.group(2).strip()
        val = val.strip('"').strip("'")
        fm[key] = val
    return fm


def find_fenced_blocks(md):
    """Return list of (start, end, lang, body) for ```lang ... ``` blocks."""
    blocks = []
    for m in re.finditer(r"```([A-Za-z0-9_-]*)\n(.*?)```", md, re.DOTALL):
        blocks.append((m.start(), m.end(), m.group(1), m.group(2)))
    return blocks


def _sibling_notes(folder):
    """(basename_no_ext, frontmatter, full_text) for every *.md in folder."""
    out = []
    for p in sorted(glob.glob(os.path.join(folder, "*.md"))):
        text = open(p, encoding="utf-8").read()
        stem = os.path.splitext(os.path.basename(p))[0]
        out.append((stem, parse_frontmatter(text), text))
    return out
