#!/bin/bash
# index-note.sh — deterministic wiki indexer for kf-cli
#
# Modes:
#   Hook (stdin JSON):    bash index-note.sh
#   Direct call:          bash index-note.sh /path/to/note.md
#   Orphan cleanup:       bash index-note.sh --validate /path/to/vault

set -euo pipefail

# ── Mode detection ────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--validate" ]]; then
    MODE="validate"
    VAULT_PATH="${2:-}"
elif [[ -n "${1:-}" ]]; then
    MODE="direct"
    FILE_PATH="$1"
else
    MODE="hook"
    INPUT=$(cat)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
fi

# ── Validate mode: remove orphaned wiki links ─────────────────────────────────

if [[ "$MODE" == "validate" ]]; then
    [[ -z "$VAULT_PATH" ]] && exit 0
    python3 - "$VAULT_PATH" << 'PYEOF'
import os, re, glob, sys

vault_path = sys.argv[1]
wiki_dir = os.path.join(vault_path, 'wiki')
notes_dir = os.path.join(vault_path, 'notes')

if not os.path.isdir(wiki_dir):
    sys.exit(0)

for wiki_file in glob.glob(os.path.join(wiki_dir, '**/*.md'), recursive=True):
    with open(wiki_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    changed = False
    for line in lines:
        m = re.search(r'\[\[notes/([^|#\]]+)', line)
        if m:
            note_name = m.group(1).strip()
            if not note_name.endswith('.md'):
                note_name += '.md'
            if not os.path.exists(os.path.join(notes_dir, note_name)):
                changed = True
                continue
        new_lines.append(line)

    if changed:
        with open(wiki_file, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"[kf-cli] cleaned orphans in {os.path.relpath(wiki_file, vault_path)}")
PYEOF
    exit 0
fi

# ── Normal mode ───────────────────────────────────────────────────────────────

[[ -z "${FILE_PATH:-}" ]] && exit 0

# Only process notes/*.md files
[[ "$FILE_PATH" != */notes/*.md ]] && exit 0

# Infer vault path from file path (notes are always at $VAULT/notes/)
VAULT_PATH="$(dirname "$(dirname "$FILE_PATH")")"
CLAUDE_MD="$VAULT_PATH/CLAUDE.md"

[[ ! -f "$FILE_PATH" ]] && exit 0
[[ ! -f "$CLAUDE_MD" ]] && exit 0

FILENAME=$(basename "$FILE_PATH" .md)

python3 - "$FILE_PATH" "$VAULT_PATH" "$CLAUDE_MD" "$FILENAME" << 'PYEOF'
import re, os, sys

file_path  = sys.argv[1]
vault_path = sys.argv[2]
claude_md_path = sys.argv[3]
filename   = sys.argv[4]

# ── Parse note frontmatter ────────────────────────────────────────────────────
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

fm_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not fm_match:
    sys.exit(0)

fm = fm_match.group(1)

# Title
title_m = re.search(r'^title:\s*["\']?(.+?)["\']?\s*$', fm, re.MULTILINE)
title = title_m.group(1).strip('"\'') if title_m else filename

# Tags — handle both [tag1, tag2] and list format
tags = []
inline_m = re.search(r'^tags:\s*\[([^\]]+)\]', fm, re.MULTILINE)
if inline_m:
    tags = [t.strip().strip('"\'') for t in inline_m.group(1).split(',')]
else:
    in_tags = False
    for line in fm.split('\n'):
        if re.match(r'^tags:\s*$', line):
            in_tags = True
            continue
        if in_tags:
            item = re.match(r'^\s*-\s+(.+)', line)
            if item:
                tags.append(item.group(1).strip().strip('"\''))
            elif line and not line.startswith(' '):
                break

if not tags:
    sys.exit(0)

# ── Parse Tag → Topic mapping from CLAUDE.md ─────────────────────────────────
with open(claude_md_path, 'r', encoding='utf-8') as f:
    claude_content = f.read()

table_m = re.search(
    r'## Tag.*?Topic Mapping\n+\|.*?\n\|[-| :]+\n((?:\|.*\n?)+)',
    claude_content, re.IGNORECASE
)
if not table_m:
    sys.exit(0)

mapping = []  # list of (set_of_tags, wiki_rel_path)
for row in table_m.group(1).strip().split('\n'):
    parts = [p.strip() for p in row.split('|')]
    if len(parts) >= 3 and parts[1] and parts[2]:
        row_tags = {t.strip() for t in parts[1].split(',')}
        mapping.append((row_tags, parts[2]))

# ── Match note tags to wiki files ─────────────────────────────────────────────
note_tags = set(tags)
matched = []
for row_tags, wiki_rel in mapping:
    if note_tags & row_tags and wiki_rel not in matched:
        matched.append(wiki_rel)

if not matched:
    sys.exit(0)

# ── Append entry to each matched wiki file ────────────────────────────────────
entry = f"- [[notes/{filename}|{title}]] — "

for wiki_rel in matched:
    wiki_path = os.path.join(vault_path, wiki_rel)
    wiki_dir  = os.path.dirname(wiki_path)

    if not os.path.exists(wiki_path):
        os.makedirs(wiki_dir, exist_ok=True)
        topic = os.path.basename(wiki_dir)
        with open(wiki_path, 'w', encoding='utf-8') as f:
            f.write(f"# {topic}\n\n## Notes\n\n")

    with open(wiki_path, 'r', encoding='utf-8') as f:
        wiki_content = f.read()

    # Idempotent: skip if already indexed
    if f"notes/{filename}" in wiki_content:
        continue

    # Append under ## Notes or at end
    if '## Notes' in wiki_content:
        wiki_content = wiki_content.rstrip('\n') + f"\n{entry}\n"
    else:
        wiki_content = wiki_content.rstrip('\n') + f"\n\n## Notes\n\n{entry}\n"

    with open(wiki_path, 'w', encoding='utf-8') as f:
        f.write(wiki_content)

    print(f"[kf-cli] indexed {filename} → {wiki_rel}")
PYEOF

exit 0
