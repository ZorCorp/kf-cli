#!/usr/bin/env python3
"""Bake pass for kf-cli:quartz.

Transforms dataview / mapview fenced blocks in a Quartz content COPY into static
markdown / HTML. Best-effort: anything unparseable is left untouched and a
warning is emitted. Sibling frontmatter and geojson are read from the VAULT
SOURCE FOLDER (arg 2), never from the copy destination.

Usage: quartz-bake.py <baked_copy_md_path> <vault_source_folder>
"""
import glob
import hashlib
import json
import os
import re
import sys
import unicodedata


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


def _parse_location(val):
    """'lat,lng' string OR [lat,lng] array text -> (lat, lng) floats or None."""
    if not val:
        return None
    nums = re.findall(r"-?\d+\.?\d*", val)
    if len(nums) < 2:
        return None
    return float(nums[0]), float(nums[1])


def _geojson_linestrings(folder):
    """Yield coordinate lists (each [[lng,lat],...]) from every geojson in folder.

    Handles a bare Feature AND a FeatureCollection.
    """
    for p in sorted(glob.glob(os.path.join(folder, "*.geojson"))):
        try:
            gj = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        feats = gj.get("features", [gj] if gj.get("type") == "Feature" else [])
        for f in feats:
            geom = f.get("geometry", {}) if isinstance(f, dict) else {}
            if geom.get("type") == "LineString":
                yield geom.get("coordinates", [])


def bake_mapview(cfg_json, folder):
    try:
        cfg = json.loads(cfg_json)
    except Exception:
        return None
    lat = cfg.get("centerLat", 0)
    lng = cfg.get("centerLng", 0)
    zoom = cfg.get("mapZoom", 5)
    # Deterministic div id: stable across republishes (unlike per-process hash()).
    # NFC-normalize first so a CJK folder path hashes identically whether it
    # arrives as NFD (macOS find/glob) or NFC (command-line arg).
    _fid = unicodedata.normalize("NFC", folder)
    mid = "kfmap-" + hashlib.md5(_fid.encode("utf-8")).hexdigest()[:8]

    markers = []
    for stem, fm, _ in _sibling_notes(folder):
        loc = _parse_location(fm.get("location", ""))
        if not loc:
            continue
        title = fm.get("title", stem)
        # popup links to the note's Quartz page (relative extensionless)
        popup = '<a href="%s">%s</a>' % (stem, title)
        markers.append(
            'L.marker([%s, %s]).addTo(m).bindPopup(%s);'
            % (loc[0], loc[1], json.dumps(popup))
        )

    polylines = []
    for coords in _geojson_linestrings(folder):
        swapped = [[c[1], c[0]] for c in coords if len(c) >= 2]  # [lng,lat]->[lat,lng]
        if swapped:
            polylines.append(
                'L.polyline(%s, {color:"#284b63"}).addTo(m);' % json.dumps(swapped)
            )

    return (
        '<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>\n'
        '<div id="%s" style="height:400px;margin:1rem 0;"></div>\n'
        '<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>\n'
        '<script>\n'
        '(function(){\n'
        '  var m = L.map("%s").setView([%s, %s], %s);\n'
        '  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",'
        '{attribution:"© OpenStreetMap"}).addTo(m);\n'
        '  %s\n'
        '  %s\n'
        '})();\n'
        '</script>' % (
            mid, mid, lat, lng, zoom,
            "\n  ".join(markers),
            "\n  ".join(polylines),
        )
    )


def transform(md, folder):
    """Rewrite dataview/mapview blocks. Returns (new_md, warnings)."""
    warnings = []
    # Process right-to-left so earlier indices stay valid after replacement.
    for start, end, lang, body in reversed(find_fenced_blocks(md)):
        repl = None
        if lang == "dataview":
            repl = bake_dataview(body, folder)
        elif lang == "mapview":
            repl = bake_mapview(body.strip(), folder)
        else:
            continue
        if repl is None:
            warnings.append("unparseable %s block left untouched" % lang)
            continue
        md = md[:start] + repl + md[end:]
    return md, warnings


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: quartz-bake.py <baked_md> <vault_source_folder>\n")
        return 2
    baked_md, folder = argv[1], argv[2]
    text = open(baked_md, encoding="utf-8").read()
    new_text, warnings = transform(text, folder)
    for w in warnings:
        sys.stderr.write("WARN: %s\n" % w)
    if new_text != text:
        open(baked_md, "w", encoding="utf-8").write(new_text)
    return 0  # best-effort: never fail the publish


if __name__ == "__main__":
    sys.exit(main(sys.argv))
