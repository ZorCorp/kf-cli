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


def _parse_columns(spec):
    """'file.link as "項目", date as "日期"' -> [(expr, alias), ...]."""
    cols = []
    for part in _split_top_commas(spec):
        part = part.strip()
        m = re.match(r'^(.*?)\s+as\s+"([^"]*)"$', part, re.IGNORECASE)
        if m:
            cols.append((m.group(1).strip(), m.group(2)))
        else:
            cols.append((part, part))
    return cols


def _split_top_commas(s):
    """Split on commas not inside quotes/parens."""
    out, depth, buf, q = [], 0, "", None
    for ch in s:
        if q:
            buf += ch
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
            buf += ch
        elif ch in "([":
            depth += 1
            buf += ch
        elif ch in ")]":
            depth -= 1
            buf += ch
        elif ch == "," and depth == 0:
            out.append(buf)
            buf = ""
        else:
            buf += ch
    if buf.strip():
        out.append(buf)
    return out


def _cell(expr, stem, fm):
    if expr == "file.link":
        return "[[%s]]" % stem
    return fm.get(expr, "") or ""


def bake_dataview(query, folder):
    q = query.strip()
    head = q.splitlines()[0].strip()
    if head.upper().startswith("TABLE"):
        return _bake_table(q, folder)
    if head.upper().startswith("TASK"):
        return _bake_task(q, folder)
    return None


def _bake_table(q, folder):
    # TABLE [WITHOUT ID] <cols>  FROM "..."  [WHERE <flag>]  [SORT <specs>]
    m = re.match(r"^TABLE\s+(?:WITHOUT\s+ID\s+)?(.*?)\s+FROM\b", q,
                 re.IGNORECASE | re.DOTALL)
    if not m:
        return None
    cols = _parse_columns(m.group(1).replace("\n", " "))
    where = re.search(r"\bWHERE\s+(.+?)(?:\bSORT\b|$)", q, re.IGNORECASE | re.DOTALL)
    sort = re.search(r"\bSORT\s+(.+)$", q, re.IGNORECASE | re.DOTALL)

    # WHERE must be a single bare frontmatter flag (e.g. `itinerary`). Anything
    # with operators/functions/AND → unparseable.
    flag = None
    if where:
        w = where.group(1).strip()
        if re.match(r"^[A-Za-z0-9_]+$", w):
            flag = w
        else:
            return None  # graceful degradation

    rows = []
    for stem, fm, _ in _sibling_notes(folder):
        if flag and (fm.get(flag, "").lower() not in ("true", "yes", "1")):
            continue
        rows.append((stem, fm))

    if sort:
        for key_spec in reversed(_split_top_commas(sort.group(1))):
            parts = key_spec.split()
            field = parts[0]
            desc = len(parts) > 1 and parts[1].upper() == "DESC"
            if field == "file.link":
                rows.sort(key=lambda r: r[0], reverse=desc)
            else:
                rows.sort(key=lambda r: r[1].get(field, ""), reverse=desc)

    header = "| " + " | ".join(a for _, a in cols) + " |"
    sep = "| " + " | ".join("---" for _ in cols) + " |"
    body = [
        "| " + " | ".join(_cell(e, stem, fm) for e, _ in cols) + " |"
        for stem, fm in rows
    ]
    return "\n".join([header, sep] + body)


def _bake_task(q, folder):
    m = re.search(r"\bWHERE\s+(.+)$", q, re.IGNORECASE | re.DOTALL)
    incomplete_only = bool(m and m.group(1).strip() == "!completed")
    groups = []
    for stem, _, text in _sibling_notes(folder):
        items = []
        for line in text.splitlines():
            mm = re.match(r"^\s*-\s+\[( |x|X)\]\s+(.*)$", line)
            if not mm:
                continue
            done = mm.group(1).lower() == "x"
            if incomplete_only and done:
                continue
            items.append("- [%s] %s" % ("x" if done else " ", mm.group(2)))
        if items:
            groups.append("**[[%s]]**\n%s" % (stem, "\n".join(items)))
    return "\n\n".join(groups)
