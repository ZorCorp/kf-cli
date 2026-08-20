#!/bin/bash
# Publish Obsidian note(s) to a Quartz v5 digital garden.
# Preserves the notes/ layer (unlike publish.sh's flat documents/).
# Usage: quartz-publish.sh <note.md | folder/ | file.html> [VAULT_PATH] [--yes] [--dry-run|--list]
#   --yes            skip the interactive read -p confirm (used by the command-file
#                    layer, which runs its OWN pre-publish confirm first).
#   --dry-run|--list resolve + print EXACTLY what WOULD publish (md + html + stubs),
#                    make NO changes, exit 0. This feeds the command-file confirm gate.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$1"; shift || true
INPUT="${INPUT#@}"   # strip a leading @ (Claude Code file-reference prefix, e.g. @notes/foo.md)

# Flags may appear in any order after INPUT; the first non-flag arg is VAULT_PATH.
VAULT_PATH=""
ASSUME_YES="no"
DRY_RUN="no"
for arg in "$@"; do
    case "$arg" in
        --yes)            ASSUME_YES="yes" ;;
        --dry-run|--list) DRY_RUN="yes" ;;
        *)                [[ -z "$VAULT_PATH" ]] && VAULT_PATH="$arg" ;;
    esac
done
VAULT_PATH="${VAULT_PATH:-$(pwd)}"
# normalize an absolute path inside the vault to a vault-relative one
case "$INPUT" in "$VAULT_PATH"/*) INPUT="${INPUT#$VAULT_PATH/}";; esac

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_FILE="$VAULT_PATH/.claude/config.local.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config not found: $CONFIG_FILE — run /kf-cli:setup"; exit 1
fi
QUARTZ_REPO=$(jq -r '.quartz_repo // empty' "$CONFIG_FILE" | sed "s|^~|$HOME|")
QUARTZ_URL=$(jq -r '.quartz_url // empty' "$CONFIG_FILE")
if [[ -z "$QUARTZ_REPO" || -z "$QUARTZ_URL" ]]; then
    echo "❌ quartz_repo / quartz_url not configured. Run /kf-cli:setup to add a garden."
    exit 1
fi
if [[ ! -d "$QUARTZ_REPO/.git" || ! -f "$QUARTZ_REPO/quartz.config.yaml" ]]; then
    echo "❌ $QUARTZ_REPO is not a Quartz git checkout"; exit 1
fi

echo "📂 Vault:  $VAULT_PATH"
echo "🌱 Garden: $QUARTZ_REPO → $QUARTZ_URL"
echo ""

# ── Resolve input to a list of source files (absolute paths under vault) ───────
declare -a MD_FILES=()
declare -a HTML_FILES=()
SRC_FOLDER=""   # vault folder for bake sibling lookups

resolve_one() {
    local f="$1"
    if [[ -f "$VAULT_PATH/$f" ]]; then echo "$VAULT_PATH/$f"; return; fi
    if [[ -f "$VAULT_PATH/notes/$f" ]]; then echo "$VAULT_PATH/notes/$f"; return; fi
    local found
    found=$(find "$VAULT_PATH" -maxdepth 4 -name "$f" -not -path "*/.git/*" 2>/dev/null | head -1)
    [[ -n "$found" ]] && echo "$found"
}

if [[ -d "$VAULT_PATH/$INPUT" || -d "$INPUT" ]]; then
    # Folder input
    FOLDER_ABS="$VAULT_PATH/$INPUT"; [[ -d "$INPUT" ]] && FOLDER_ABS="$INPUT"
    FOLDER_ABS="${FOLDER_ABS%/}"
    SRC_FOLDER="$FOLDER_ABS"
    while IFS= read -r m; do MD_FILES+=("$m"); done < <(find "$FOLDER_ABS" -maxdepth 1 -name '*.md' | sort)
    while IFS= read -r h; do HTML_FILES+=("$h"); done < <(find "$FOLDER_ABS" -maxdepth 1 -name '*.html' | sort)
else
    # Single file
    [[ ! "$INPUT" =~ \.(md|html)$ ]] && INPUT="${INPUT}.md"
    ONE=$(resolve_one "$INPUT")
    [[ -z "$ONE" ]] && { echo "❌ Not found: $INPUT"; exit 1; }
    SRC_FOLDER="$(dirname "$ONE")"
    [[ "$ONE" =~ \.html$ ]] && HTML_FILES+=("$ONE") || MD_FILES+=("$ONE")
fi

if (( ${#MD_FILES[@]} + ${#HTML_FILES[@]} == 0 )); then
    echo "❌ No .md or .html files to publish"; exit 1
fi

# ── Refuse access: private ─────────────────────────────────────────────────────
declare -a PRIVATE=()
for m in "${MD_FILES[@]}"; do
    if grep -qiE '^access:[[:space:]]*private' "$m"; then PRIVATE+=("$m"); fi
done
if (( ${#PRIVATE[@]} > 0 )); then
    echo "🚫 Refusing to publish — these notes are marked 'access: private':"
    for p in "${PRIVATE[@]}"; do echo "   • ${p#$VAULT_PATH/}"; done
    echo "   Quartz has no access control and the garden is PUBLIC. Remove the flag or exclude these notes."
    exit 1
fi

# ── Dry-run confirm (PUBLIC repo) ──────────────────────────────────────────────
rel() { echo "${1#$VAULT_PATH/}"; }
echo "📋 Will publish to the PUBLIC garden ($QUARTZ_URL):"
for m in "${MD_FILES[@]}";   do echo "   md   → content/$(rel "$m")"; done
for h in "${HTML_FILES[@]}"; do
    hrel="$(rel "$h")"
    hbase="$(basename "${hrel%.html}")"
    hstub=$(python3 "$SCRIPT_DIR/quartz-html-stub.py" "$h" "/static/embeds/$hrel" "$hbase" --name 2>/dev/null)
    echo "   html → quartz/static/embeds/$hrel (served text/html at /static/embeds/$hrel)"
    echo "   stub → content/$(dirname "$hrel")/$hstub (indexed embed → /static/embeds/$hrel)"
done
echo ""

# --dry-run / --list: report only, change nothing, exit before any copy/push.
if [[ "$DRY_RUN" == "yes" ]]; then
    echo "DRY_RUN=yes — no files copied, nothing pushed."
    exit 0
fi

if [[ "$ASSUME_YES" != "yes" ]]; then
    read -r -p "Publish these ${#MD_FILES[@]} note(s) + ${#HTML_FILES[@]} html file(s)? [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }
fi

# ── Image extraction (reuse publish.sh idiom) ──────────────────────────────────
extract_images() {  # $1 = md file
    python3 -c "
import re,sys
c=open(sys.argv[1],encoding='utf-8').read()
exts=r'\.(?:jpg|jpeg|png|gif|svg|webp)'
seen=set()
for m in re.finditer(r'!\[[^\]]*\]\(([^)]+'+exts+r')\)',c,re.I):
    p=m.group(1)
    if p not in seen and not p.startswith('http'): seen.add(p); print(p)
for m in re.finditer(r'!\[\[([^\]]+'+exts+r')\]\]',c,re.I):
    p=m.group(1)
    if p not in seen and not p.startswith('http'): seen.add(p); print(p)
" "$1" 2>/dev/null || true
}

copy_image() {  # $1 = image ref as written in note
    local ref="$1" clean src dest
    clean="${ref#./}"; clean="${clean#../}"      # normalize ./ ../
    src="$VAULT_PATH/$clean"
    dest="$QUARTZ_REPO/content/$clean"           # content/images/...
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; echo "   📸 $clean"
    else
        echo "   ⚠️  image not found: $clean"
    fi
}

# ── Copy markdown preserving notes/ layer, then bake the COPY ───────────────────
for m in "${MD_FILES[@]}"; do
    relpath="$(rel "$m")"                          # e.g. notes/內蒙古之旅/00-行程總覽.md
    dest="$QUARTZ_REPO/content/$relpath"
    mkdir -p "$(dirname "$dest")"
    cp "$m" "$dest"
    echo "✅ note → content/$relpath"
    while IFS= read -r img; do [[ -n "$img" ]] && copy_image "$img"; done < <(extract_images "$m")
    # Bake the COPY, reading siblings/geojson from the VAULT source folder
    python3 "$SCRIPT_DIR/quartz-bake.py" "$dest" "$(dirname "$m")" || echo "   ⚠️  bake skipped"
done

# ── HTML: raw file → garden static dir (served as text/html) + indexed stub ─────
# Quartz strips the extension off a content/*.html and GitHub Pages then serves it
# as application/octet-stream (downloads, no inline render). Files under
# quartz/static/ are copied to the build VERBATIM (extension kept) and served at
# /static/… with the correct content-type by extension, so the deck renders. The
# indexed <base>-embed.md stub stays under content/ (that is what makes the deck
# appear in Explorer/search); its link + iframe point at the /static/embeds/… URL.
QUARTZ_STATIC_SUBDIR="embeds"   # under quartz/static/ ; served at /static/embeds/…
for h in "${HTML_FILES[@]}"; do
    relpath="$(rel "$h")"                               # notes/X/foo.html
    static_rel="$QUARTZ_STATIC_SUBDIR/$relpath"         # embeds/notes/X/foo.html
    static_dest="$QUARTZ_REPO/quartz/static/$static_rel"
    mkdir -p "$(dirname "$static_dest")"
    cp "$h" "$static_dest"
    echo "✅ html → quartz/static/$static_rel (served text/html at /static/$static_rel)"
    base="$(basename "${relpath%.html}")"
    static_url="/static/$static_rel"                    # /static/embeds/notes/X/foo.html
    stub_name=$(python3 "$SCRIPT_DIR/quartz-html-stub.py" "$h" "$static_url" "$base" --name)
    stub="$QUARTZ_REPO/content/$(dirname "$relpath")/$stub_name"
    mkdir -p "$(dirname "$stub")"
    python3 "$SCRIPT_DIR/quartz-html-stub.py" "$h" "$static_url" "$base" > "$stub"
    echo "   ↳ indexed stub → content/$(dirname "$relpath")/$stub_name (embeds $static_url)"
done

# ── Git add / commit / push origin v5 (handle non-fast-forward) ────────────────
cd "$QUARTZ_REPO"
git add -A
if git diff --cached --quiet; then
    echo "ℹ️  Nothing changed — already up to date."; exit 0
fi
git commit -m "publish: ${#MD_FILES[@]} note(s), ${#HTML_FILES[@]} html

🤖 Generated with Claude Code" >/dev/null
echo "🚀 Pushing to origin v5..."
git pull --rebase origin v5 >/dev/null 2>&1 || true
git push origin v5

# ── Verify first markdown page (or, for html-only, the first stub page) URL ─────
# For html the raw file now lives under /static/ (not a content route); the
# indexed <base>-embed stub IS a content page, so verifying it proves the build ran.
if (( ${#MD_FILES[@]} > 0 )); then
    first_rel="$(rel "${MD_FILES[0]}")"           # notes/X/Y.md
    url_path="${first_rel%.md}"
else
    first_rel="$(rel "${HTML_FILES[0]}")"         # notes/X/foo.html
    hbase="$(basename "${first_rel%.html}")"
    url_path="$(dirname "$first_rel")/${hbase}-embed"   # notes/X/foo-embed (stub route)
fi
echo ""
bash "$SCRIPT_DIR/quartz-verify.sh" "$url_path" "$VAULT_PATH"
