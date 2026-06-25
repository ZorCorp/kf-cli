#!/bin/bash
# Publish Obsidian note to GitHub Pages (sharehub)
# Handles image copying and path conversion
# Usage: ./publish.sh NOTE_FILE [VAULT_PATH]
# Notes live in notes/ subfolder; images live in images/ at vault root.

set -e  # Exit on error

NOTE_FILE="$1"
VAULT_PATH="${2:-$(pwd)}"

# Read config from vault
CONFIG_FILE="$VAULT_PATH/.claude/config.local.json"

if [[ -f "$CONFIG_FILE" ]]; then
    # Read paths from config
    SHAREHUB_PATH=$(jq -r '.sharehub_repo // empty' "$CONFIG_FILE" | sed "s|^~|$HOME|")
    SHAREHUB_URL=$(jq -r '.sharehub_url // empty' "$CONFIG_FILE")

    if [[ -z "$SHAREHUB_PATH" || "$SHAREHUB_PATH" == "null" ]]; then
        echo "❌ sharehub_repo not configured in .claude/config.local.json"
        echo "   Run /kf-cli:setup to configure"
        exit 1
    fi
else
    echo "❌ Config not found: $CONFIG_FILE"
    echo "   Run /kf-cli:setup first"
    exit 1
fi

# Default URL if not in config
SHAREHUB_URL="${SHAREHUB_URL:-}"
if [[ -z "$SHAREHUB_URL" ]]; then
    echo "❌ SHAREHUB_URL not set and no sharehub_url in .claude/config.local.json"
    echo "   Run /kf-cli:setup to configure your publishing target"
    exit 1
fi

# Check if using custom domain (no path prefix needed) or GitHub Pages subdirectory
if [[ "$SHAREHUB_URL" =~ github\.io/([^/]+) ]]; then
    # GitHub Pages: extract repo name for path prefix
    REPO_NAME="${BASH_REMATCH[1]}"
    IMAGE_PREFIX="/$REPO_NAME"
else
    # Custom domain: images at root
    REPO_NAME=""
    IMAGE_PREFIX=""
fi

echo "📂 Vault: $VAULT_PATH"
echo "📤 Sharehub: $SHAREHUB_PATH"
echo "🌐 URL: $SHAREHUB_URL"
echo ""

# Add .md extension if not provided
if [[ ! "$NOTE_FILE" =~ \.md$ ]]; then
    NOTE_FILE="${NOTE_FILE}.md"
fi

# ── Note lookup: check vault root, then notes/ subfolder ──────────────────────
if [[ -f "$VAULT_PATH/$NOTE_FILE" ]]; then
    : # found at root (e.g. user passed full path like notes/my-note.md)
elif [[ -f "$VAULT_PATH/notes/$NOTE_FILE" ]]; then
    NOTE_FILE="notes/$NOTE_FILE"
    echo "ℹ️  Found note in notes/ subfolder"
else
    # Fallback: search vault recursively (handles KFE/, HK-K12-AI-Training/, etc.)
    FOUND=$(find "$VAULT_PATH" -maxdepth 4 -name "$NOTE_FILE" -not -path "*/.git/*" 2>/dev/null | head -1)
    if [[ -n "$FOUND" ]]; then
        NOTE_FILE="${FOUND#$VAULT_PATH/}"
        echo "ℹ️  Found note at: $NOTE_FILE"
    else
        echo "❌ Error: File not found: $NOTE_FILE"
        echo "   Searched vault recursively (maxdepth 4)"
        exit 1
    fi
fi

# Check if sharehub exists
if [[ ! -d "$SHAREHUB_PATH" ]]; then
    echo "❌ Sharehub repo not found at: $SHAREHUB_PATH"
    echo "   Clone it first or update .claude/config.local.json"
    exit 1
fi

echo "✅ Found note: $NOTE_FILE"
echo ""

# ── Strip notes/ prefix for sharehub destination ──────────────────────────────
# Vault: notes/my-note.md → Sharehub: documents/my-note.md (flat, no subfolder)
DEST_NOTE_FILE="${NOTE_FILE#notes/}"

# ── Extract and copy referenced images ────────────────────────────────────────
cd "$VAULT_PATH"

# Find all local image references — standard markdown AND Obsidian wikilinks
IMAGE_PATHS=$(python3 -c "
import re, sys
content = open(sys.argv[1]).read()
exts = r'\.(?:jpg|jpeg|png|gif|svg|webp)'
seen = set()
for m in re.finditer(r'!\[[^\]]*\]\(([^)]+' + exts + r')\)', content, re.IGNORECASE):
    p = m.group(1)
    if p not in seen: seen.add(p); print(p)
for m in re.finditer(r'!\[\[([^\]]+' + exts + r')\]\]', content, re.IGNORECASE):
    p = m.group(1)
    if p not in seen: seen.add(p); print(p)
" "$NOTE_FILE" 2>/dev/null || true)

if [[ -n "$IMAGE_PATHS" ]]; then
    echo "📸 Found images to copy:"
    echo "$IMAGE_PATHS"
    echo ""

    # Copy each image to sharehub
    while IFS= read -r IMG_PATH; do
        # Skip if empty or URL (http/https)
        if [[ -z "$IMG_PATH" ]] || [[ "$IMG_PATH" =~ ^https?:// ]]; then
            continue
        fi

        # Normalize path:
        # ./images/foo.png  → images/foo.png
        # ../images/foo.png → images/foo.png  (notes/ is one level deep)
        CLEAN_PATH="${IMG_PATH#./}"    # strip leading ./
        CLEAN_PATH="${CLEAN_PATH#../}" # strip leading ../ (from notes/ subfolder)

        # Source path in vault (images/ is at vault root)
        SRC="$VAULT_PATH/$CLEAN_PATH"

        # Destination in sharehub (preserve subdirectory structure, e.g. images/pai-article/)
        DEST="$SHAREHUB_PATH/$CLEAN_PATH"
        DEST_DIR=$(dirname "$DEST")

        if [[ -f "$SRC" ]]; then
            mkdir -p "$DEST_DIR"
            cp "$SRC" "$DEST"
            echo "  ✅ Copied: $CLEAN_PATH"
        else
            echo "  ⚠️  Not found: $SRC"
        fi
    done <<< "$IMAGE_PATHS"
    echo ""
else
    echo "ℹ️  No local images found in note"
    echo ""
fi

# ── Read note content ──────────────────────────────────────────────────────────
NOTE_CONTENT=$(cat "$NOTE_FILE")

# ── Convert image paths for GitHub Pages ──────────────────────────────────────
# ./images/file.jpg  → /images/file.jpg  (custom domain)
# ../images/file.jpg → /images/file.jpg  (from notes/ subfolder)
# GitHub Pages adds repo prefix automatically via IMAGE_PREFIX
CONVERT_SCRIPT=$(mktemp)
cat > "$CONVERT_SCRIPT" << 'PYEOF'
import sys, re, os

content = sys.stdin.read()
image_prefix = sys.argv[1] if len(sys.argv) > 1 else ''
exts = r'\.(jpg|jpeg|png|gif|svg|webp)'

def normalize_path(path):
    if path.startswith('../'):
        path = path[3:]
    elif path.startswith('./'):
        path = path[2:]
    return path

def convert_img(m):
    alt = m.group(1)
    path = m.group(2)
    if path.startswith('http://') or path.startswith('https://') or path.startswith('/'):
        return m.group(0)
    path = normalize_path(path)
    return f'![{alt}]({image_prefix}/{path})'

def convert_wiki_img(m):
    path = m.group(1)
    if path.startswith('http://') or path.startswith('https://') or path.startswith('/'):
        return m.group(0)
    path = normalize_path(path)
    alt = os.path.basename(path)
    return f'![{alt}]({image_prefix}/{path})'

content = re.sub(r'!\[([^\]]*)\]\(([^)]+' + exts + r')\)', convert_img, content, flags=re.IGNORECASE)
content = re.sub(r'!\[\[([^\]]+' + exts + r')\]\]', convert_wiki_img, content, flags=re.IGNORECASE)
print(content, end='')
PYEOF
CONVERTED_CONTENT=$(echo "$NOTE_CONTENT" | python3 "$CONVERT_SCRIPT" "$IMAGE_PREFIX")
rm -f "$CONVERT_SCRIPT"

echo "📝 Image path conversion complete"
echo ""

# ── Write converted note to sharehub ──────────────────────────────────────────
# notes/ prefix stripped — sharehub publishes flat under documents/
DEST_NOTE="$SHAREHUB_PATH/documents/$DEST_NOTE_FILE"
DEST_DIR=$(dirname "$DEST_NOTE")
mkdir -p "$DEST_DIR"
echo "$CONVERTED_CONTENT" > "$DEST_NOTE"

echo "✅ Copied note to: documents/$DEST_NOTE_FILE"
echo ""

# ── Git operations ─────────────────────────────────────────────────────────────
cd "$SHAREHUB_PATH"

echo "📋 Git status:"
git status --short
echo ""

# Add all changes (document + images)
git add "documents/$DEST_NOTE_FILE"
git add images/ 2>/dev/null || true

# Get note title from frontmatter for commit message
NOTE_TITLE=$(grep -m1 '^title:' "documents/$DEST_NOTE_FILE" | sed 's/title: *["'"'"']*//;s/["'"'"']*$//' || echo "$DEST_NOTE_FILE")

# Commit
git commit -m "Publish: $NOTE_TITLE

- Published documents/$DEST_NOTE_FILE
- Copied associated images
- Converted image paths for GitHub Pages

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to GitHub
echo "🚀 Pushing to GitHub..."
git push origin main

echo ""
echo "⏳ Waiting for GitHub Pages deployment..."

# Build the published URL (uses flat dest name, not notes/ prefix)
PUBLISHED_URL="$SHAREHUB_URL/documents/${DEST_NOTE_FILE%.md}.html"

# Verify page is reachable (retry up to 18 times = 90 seconds)
MAX_RETRIES=18
RETRY_DELAY=5
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$PUBLISHED_URL" 2>/dev/null || echo "000")

    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo ""
        echo "✅ Published successfully!"
        echo ""
        echo "📄 URL: $PUBLISHED_URL"
        echo ""

        # Run post-publish verification
        VERIFY_SCRIPT="$(dirname "$0")/verify-publish.sh"
        if [[ -f "$VERIFY_SCRIPT" ]]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            bash "$VERIFY_SCRIPT" "$DEST_NOTE_FILE" "$VAULT_PATH"
        fi

        exit 0
    fi

    echo "  Attempt $RETRY_COUNT/$MAX_RETRIES - Status: $HTTP_STATUS (waiting ${RETRY_DELAY}s...)"
    sleep $RETRY_DELAY
done

# Page not yet reachable after all retries
echo ""
echo "⚠️  Published but page not yet reachable (GitHub Pages may still be deploying)"
echo ""
echo "📄 URL: $PUBLISHED_URL"
echo "⏱️  Check again in a minute"
echo ""

exit 0
