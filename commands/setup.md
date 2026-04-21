---
description: Setup wizard for KnowledgeFactory CLI plugin
argument-hint: [--enable-short-commands] (optional: enable /capture instead of /kf-cli:capture)
allowed-tools:
  - Bash(*)
  - Read(*)
  - Write(*)
---

## Context

- **Current Directory:** `$PWD`
- **Plugin Location:** `~/.claude/plugins/marketplaces/kf-cli/`
- **Arguments:** `$ARGUMENTS`

## Task

Run the setup wizard to configure KnowledgeFactory CLI for this vault.

## Step 1: Verify Environment

```bash
echo "🔧 KnowledgeFactory CLI Setup Wizard"
echo "====================================="
echo ""

VAULT_PATH="$(pwd)"

# Check we're in an Obsidian vault
if [[ ! -d ".obsidian" ]]; then
    echo "⚠️  Warning: No .obsidian folder found. Are you in an Obsidian vault?"
    echo "   Current directory: $VAULT_PATH"
    echo ""
fi

# Check plugin is installed
PLUGIN_DIR=$(find "$HOME/.claude/plugins" -maxdepth 6 -path "*/kf-cli/commands" -type d 2>/dev/null | head -1 | sed "s|/commands$||")
if [[ -z "$PLUGIN_DIR" ]]; then
    echo "❌ kf-cli plugin not found"
    echo "   Install with: /plugin install kf-cli"
    exit 1
fi

echo "✅ kf-cli plugin found"
echo "📂 Vault path: $VAULT_PATH"
echo ""
```

## Step 2: Check Dependencies

```bash
echo "📦 Checking dependencies..."
echo ""

# Required
command -v git >/dev/null && echo "✅ git" || echo "❌ git (required - brew install git)"
command -v python3 >/dev/null && echo "✅ python3" || echo "❌ python3 (required)"
command -v jq >/dev/null && echo "✅ jq" || echo "❌ jq (required - brew install jq)"

# CLI-specific (no Docker needed!)
command -v yt-dlp >/dev/null && echo "✅ yt-dlp (YouTube metadata)" || echo "❌ yt-dlp (required - brew install yt-dlp)"
command -v gh >/dev/null && echo "✅ gh (GitHub CLI)" || echo "❌ gh (required - brew install gh)"

# Optional but recommended
command -v uvx >/dev/null && echo "✅ uvx (YouTube transcripts)" || echo "⚠️  uvx (optional - brew install uv)"

echo ""
echo "ℹ️  No Docker required! kf-cli uses native CLI tools."
echo ""
```

## Step 3: Check obsidian-cli

```bash
echo "🖥️  Checking obsidian-cli..."
echo ""

if command -v obsidian-cli >/dev/null 2>&1; then
    OBS_CLI_VERSION=$(obsidian-cli --version 2>/dev/null || echo "unknown")
    echo "✅ obsidian-cli ($OBS_CLI_VERSION)"
else
    echo "❌ obsidian-cli not found"
    echo "   Install: npm install -g obsidian-cli"
    echo "   Required for: /kf-cli:semantic-search"
fi

echo ""
```

## Step 4: Scaffold Vault Layout

Create the standard vault directories and seed a starter `CLAUDE.md` + `wiki/_master-index.md` if they don't already exist. **Non-destructive** — nothing is overwritten; existing files are preserved.

```bash
echo "🏗️  Checking vault layout..."
echo ""

# Re-derive in case this block runs in a fresh shell
VAULT_PATH="${VAULT_PATH:-$(pwd)}"
PLUGIN_DIR=$(find "$HOME/.claude/plugins" -maxdepth 6 -path "*/kf-cli/commands" -type d 2>/dev/null | head -1 | sed "s|/commands$||")
SKELETON="$PLUGIN_DIR/templates/vault-skeleton"

# Standard vault subdirectories — created only if missing
CREATED_DIRS=()
for d in notes wiki raw output images Templates; do
    if [[ ! -d "$VAULT_PATH/$d" ]]; then
        mkdir -p "$VAULT_PATH/$d"
        CREATED_DIRS+=("$d")
    fi
done

if (( ${#CREATED_DIRS[@]} > 0 )); then
    echo "✅ Created directories: ${CREATED_DIRS[*]}"
else
    echo "ℹ All standard vault directories already present"
fi

# Seed CLAUDE.md — NEVER overwrite
if [[ -f "$VAULT_PATH/CLAUDE.md" ]]; then
    echo "ℹ CLAUDE.md already exists — preserved"
elif [[ -f "$SKELETON/CLAUDE.md" ]]; then
    cp "$SKELETON/CLAUDE.md" "$VAULT_PATH/CLAUDE.md"
    echo "✅ Seeded CLAUDE.md (Capture → Wiki Rule + Tag → Topic mapping — edit to match your topics)"
fi

# Seed wiki/_master-index.md — NEVER overwrite
if [[ -f "$VAULT_PATH/wiki/_master-index.md" ]]; then
    echo "ℹ wiki/_master-index.md already exists — preserved"
elif [[ -f "$SKELETON/wiki/_master-index.md" ]]; then
    cp "$SKELETON/wiki/_master-index.md" "$VAULT_PATH/wiki/_master-index.md"
    echo "✅ Seeded wiki/_master-index.md"
fi

echo ""
```

## Step 5: Configure Sharehub (Publishing)

```bash
echo "📤 Configuring publishing setup..."
echo ""

# Check existing config
EXISTING_SHAREHUB=""
if [[ -f ".claude/config.local.json" ]]; then
    EXISTING_SHAREHUB=$(jq -r '.sharehub_repo // empty' .claude/config.local.json | sed "s|^~|$HOME|")
fi

# Default paths to check
DEFAULT_PATHS=(
    "$EXISTING_SHAREHUB"
    "$HOME/Dev/sharehub"
    "$HOME/sharehub"
    "$HOME/Documents/sharehub"
)

SHAREHUB_PATH=""
for path in "${DEFAULT_PATHS[@]}"; do
    if [[ -n "$path" && -d "$path" && -d "$path/.git" ]]; then
        SHAREHUB_PATH="$path"
        break
    fi
done

if [[ -n "$SHAREHUB_PATH" ]]; then
    echo "✅ Sharehub repo found at: $SHAREHUB_PATH"
    REMOTE=$(cd "$SHAREHUB_PATH" && git remote get-url origin 2>/dev/null || echo "none")
    echo "   Remote: $REMOTE"

    # Get URL: prefer _config.yml url field, fall back to github.io
    if [[ -f "$SHAREHUB_PATH/_config.yml" ]]; then
        CONFIG_URL=$(grep -E "^url:" "$SHAREHUB_PATH/_config.yml" | sed "s/url:[[:space:]]*//;s/["''']//g" | tr -d '[:space:]')
        if [[ -n "$CONFIG_URL" ]]; then
            SHAREHUB_URL="$CONFIG_URL"
            echo "   Pages URL: $SHAREHUB_URL (from _config.yml)"
        fi
    fi
    if [[ -z "$SHAREHUB_URL" ]] && [[ "$REMOTE" =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        SHAREHUB_URL="https://${OWNER}.github.io/${REPO}"
        echo "   Pages URL: $SHAREHUB_URL (from remote)"
    fi
else
    echo "⚠️  Sharehub repo not found in common locations"
    echo ""
    echo "   Please provide your sharehub repo path:"
    echo "   (or press Enter to skip publishing setup)"
fi

echo ""
```

## Step 6: Create Vault Configuration

```bash
echo "⚙️  Creating configuration..."
echo ""

mkdir -p .claude

# Set defaults if not discovered
SHAREHUB_URL="${SHAREHUB_URL:-}"
SHAREHUB_PATH="${SHAREHUB_PATH:-}"

# Convert to ~ notation for config
SHAREHUB_PATH_CONFIG="${SHAREHUB_PATH/#$HOME/~}"

# Create or update config
cat > .claude/config.local.json << EOF
{
  "vault_path": "$VAULT_PATH",
  "sharehub_url": "$SHAREHUB_URL",
  "sharehub_repo": "$SHAREHUB_PATH_CONFIG",
  "enable_short_commands": false
}
EOF

echo "✅ Created .claude/config.local.json"
echo "   vault_path: $VAULT_PATH"
echo "   sharehub_url: $SHAREHUB_URL"
echo "   sharehub_repo: $SHAREHUB_PATH_CONFIG"
```

## Step 7: Enable Short Commands (Optional)

```bash
if [[ "$ARGUMENTS" == *"--enable-short-commands"* ]]; then
    echo ""
    echo "📝 Enabling short commands..."

    # Locate plugin commands dir — try all known cache layouts
    PLUGIN_COMMANDS=""
    for candidate in \
        "$HOME/.claude/plugins/marketplaces/kf-cli/commands" \
        "$HOME/.claude/plugins/marketplaces/zorskill/plugins/kf-cli/commands" \
        "$HOME/.claude/plugins/cache/zorskill/plugins/kf-cli/commands" \
        "$HOME/.claude/plugins/cache/claude-plugins-official/kf-cli/commands"; do
        if [[ -d "$candidate" ]]; then
            PLUGIN_COMMANDS="$candidate"
            break
        fi
    done
    # Fall back to find if none of the above matched
    if [[ -z "$PLUGIN_COMMANDS" ]]; then
        PLUGIN_COMMANDS=$(find "$HOME/.claude/plugins" -maxdepth 7 -path "*/kf-cli/commands" -type d 2>/dev/null | head -1)
    fi

    if [[ -z "$PLUGIN_COMMANDS" ]]; then
        echo "❌ Could not locate kf-cli commands directory"
        echo "   Searched: $HOME/.claude/plugins"
        echo "   Try: /plugin install kf-cli first"
        exit 1
    fi
    echo "   Plugin commands: $PLUGIN_COMMANDS"

    VAULT_COMMANDS=".claude/commands"
    mkdir -p "$VAULT_COMMANDS"

    # Copy each command
    COPIED=0
    for cmd in capture.md youtube-note.md idea.md gitingest.md study-guide.md publish.md semantic-search.md share.md; do
        if [[ -f "$PLUGIN_COMMANDS/$cmd" ]]; then
            cp "$PLUGIN_COMMANDS/$cmd" "$VAULT_COMMANDS/$cmd"
            echo "  ✅ /${cmd%.md}"
            COPIED=$((COPIED + 1))
        fi
    done
    if (( COPIED == 0 )); then
        echo "❌ No command files found in $PLUGIN_COMMANDS"
        exit 1
    fi

    # Update config
    jq '.enable_short_commands = true' .claude/config.local.json > .claude/config.local.json.tmp
    mv .claude/config.local.json.tmp .claude/config.local.json

    echo ""
    echo "✅ Short commands enabled!"
    echo "   You can now use /capture instead of /kf-cli:capture"
    echo ""
    echo "⚠️  Run /reload-plugins to activate the short commands"
else
    echo ""
    echo "ℹ️  Using plugin-prefixed commands (default)"
    echo "   Example: /kf-cli:capture, /kf-cli:idea"
    echo ""
    echo "   To enable short commands, run:"
    echo "   /kf-cli:setup --enable-short-commands"
fi
```

## Step 8: Summary

```bash
echo ""
echo "========================================"
echo "🎉 KnowledgeFactory CLI Setup Complete!"
echo "========================================"
echo ""
echo "Available Commands:"
echo "  /kf-cli:capture        - Universal content capture"
echo "  /kf-cli:youtube-note   - YouTube video with transcript"
echo "  /kf-cli:idea           - Quick idea capture"
echo "  /kf-cli:gitingest      - GitHub repository analysis"
echo "  /kf-cli:study-guide    - Generate study materials"
echo "  /kf-cli:publish        - Publish to GitHub Pages"
echo "  /kf-cli:share          - Generate shareable URL"
echo "  /kf-cli:semantic-search - Search vault by meaning"
echo ""
echo "Key features:"
echo "  ✅ No Docker required"
echo "  ✅ Direct filesystem access (faster)"
echo "  ✅ Uses native CLI tools (yt-dlp, gh, curl, obsidian-cli)"
echo "  ✅ Simpler architecture"
echo ""
echo "Configuration Files:"
echo "  ~/.claude/plugins/marketplaces/kf-cli/  (plugin)"
echo "  .claude/config.local.json                (vault config)"
echo ""
echo "Need help? https://github.com/ZorCorp/kf-cli"
echo ""
```

## Re-running Setup

Run `/kf-cli:setup` again to:
- Update configuration
- Enable/disable short commands
- Check dependencies and plugins
