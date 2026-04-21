#!/usr/bin/env bash
# install.sh — kf-cli installer for ~/.agents/skills/kf-cli/
#
# Single source of truth: `~/.agents/skills/kf-cli/` holds the real files.
# Each detected AI tool (Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot)
# gets a link from its skills directory pointing to the canonical location.
# Manage one place, every tool sees the update.
#
# Link type per platform:
#   * Linux / macOS: POSIX symlink (`ln -sfn`)
#   * Windows (Git Bash / MSYS): NTFS junction (`mklink /J`) — works without
#     admin rights or Developer Mode
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ZorCorp/kf-cli/master/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --update
#   curl -fsSL .../install.sh | bash -s -- --uninstall
#   curl -fsSL .../install.sh | bash -s -- --no-link       # skip the symlink step
#   curl -fsSL .../install.sh | bash -s -- --force-link    # symlink even if tool dir absent
#
# Advanced: override the source tarball (e.g. to test a feature branch)
#   REPO_TARBALL=https://github.com/ZorCorp/kf-cli/archive/refs/heads/my-branch.tar.gz \
#     bash install.sh

set -euo pipefail

REPO_TARBALL="${REPO_TARBALL:-https://github.com/ZorCorp/kf-cli/archive/refs/heads/master.tar.gz}"
INSTALL_DIR="$HOME/.agents/skills/kf-cli"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$HOME/.agents/skills/kf-cli.bak-$TIMESTAMP"
STAGING=""
DO_LINK=1
FORCE_LINK=0

# Tools to symlink into, in "name:target_path" form.
# Target path is the per-tool skills dir; it will become a symlink → $INSTALL_DIR.
LINK_TARGETS=(
    "claude-code:$HOME/.claude/skills/kf-cli"
    "codex:$HOME/.codex/skills/kf-cli"
    "gemini-cli:$HOME/.gemini/skills/kf-cli"
    "cursor:$HOME/.cursor/skills/kf-cli"
    "github-copilot:$HOME/.copilot/skills/kf-cli"
)

cleanup() {
    if [[ -n "$STAGING" && -d "$STAGING" ]]; then
        rm -rf "$STAGING"
    fi
}
trap cleanup EXIT

MODE="install"
for arg in "$@"; do
    case "$arg" in
        --update)      MODE="update" ;;
        --uninstall)   MODE="uninstall" ;;
        --no-link)     DO_LINK=0 ;;
        --force-link)  FORCE_LINK=1 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

is_windows() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# Create a directory link that survives on Windows without Dev Mode.
# On Windows Git Bash, `ln -s` silently falls back to copying unless
# MSYS=winsymlinks:nativestrict + Dev Mode. Use `mklink /J` (NTFS junction)
# instead — works on any Windows with no special privileges.
# We pipe the command into `cmd` via stdin to avoid MSYS path mangling
# of the `/c` flag and backslash escapes.
make_dir_link() {
    local src="$1" dst="$2"
    if is_windows; then
        local src_win dst_win
        src_win="$(cygpath -w "$src" 2>/dev/null || echo "$src")"
        dst_win="$(cygpath -w "$dst" 2>/dev/null || echo "$dst")"
        echo "mklink /J \"$dst_win\" \"$src_win\"" | cmd >/dev/null 2>&1
        # Verify the link landed (set -e tolerated because we return explicitly)
        if [[ -e "$dst" ]]; then
            return 0
        else
            return 1
        fi
    else
        ln -sfn "$src" "$dst"
    fi
}

# Git Bash [[ -L ]] recognizes NTFS junctions as symlinks, so a unified test works.
is_dir_link() {
    [[ -L "$1" ]]
}

# Best-effort identify whether a link points into our kf-cli install dir.
# We accept the link as "ours" if its readlink target's basename is `kf-cli`
# and it lives under an `.agents/skills/` path — this handles Git Bash
# returning POSIX paths (e.g. `/tmp/...`) where $INSTALL_DIR is Windows-style.
link_points_to_ours() {
    local path="$1"
    [[ -L "$path" ]] || return 1
    local resolved; resolved="$(readlink "$path" 2>/dev/null || true)"
    [[ -z "$resolved" ]] && return 1
    # Direct match (Unix / same-path-style)
    if [[ "$resolved" == "$INSTALL_DIR" ]]; then
        return 0
    fi
    # Windows: $INSTALL_DIR may be C:/... while readlink returns /c/... or /tmp/...
    # Compare by stable suffix.
    [[ "$resolved" == *"/.agents/skills/kf-cli" ]]
}

# Remove a directory link (symlink OR Windows junction).
remove_dir_link() {
    local path="$1"
    # Git Bash handles junction removal via `rm -f` successfully in practice,
    # but fall back to `rmdir` via cmd if that fails.
    rm -f "$path" 2>/dev/null || true
    if [[ -e "$path" ]] && is_windows; then
        local path_win; path_win="$(cygpath -w "$path" 2>/dev/null || echo "$path")"
        echo "rmdir \"$path_win\"" | cmd >/dev/null 2>&1 || true
    fi
}

link_to_tools() {
    local canonical="$INSTALL_DIR"
    echo ""
    echo "Linking skill to detected AI tools:"
    local linked=0 skipped=0
    for entry in "${LINK_TARGETS[@]}"; do
        local name="${entry%%:*}"
        local target="${entry#*:}"
        local parent; parent="$(dirname "$target")"
        # Only link if the tool's config dir already exists — unless --force-link
        if [[ ! -d "$parent" && "$FORCE_LINK" != "1" ]]; then
            continue
        fi
        mkdir -p "$parent"
        if is_dir_link "$target"; then
            remove_dir_link "$target"
        elif [[ -e "$target" ]]; then
            echo "  ⚠ $name: $target exists and is not a symlink — skipped (use --force-link to override)"
            skipped=$((skipped + 1))
            continue
        fi
        make_dir_link "$canonical" "$target"
        echo "  ✓ $name → $target"
        linked=$((linked + 1))
    done
    if (( linked == 0 && skipped == 0 )); then
        echo "  (no AI tools detected — canonical copy at $canonical still works for any framework that reads ~/.agents/skills/)"
    fi
}

unlink_tools() {
    local removed=0
    for entry in "${LINK_TARGETS[@]}"; do
        local target="${entry#*:}"
        if link_points_to_ours "$target"; then
            remove_dir_link "$target"
            echo "  ✓ removed link $target"
            removed=$((removed + 1))
        fi
    done
    if (( removed == 0 )); then
        echo "  (no kf-cli links found)"
    fi
}

uninstall() {
    echo "Removing kf-cli symlinks:"
    unlink_tools
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "✓ Removed $INSTALL_DIR"
    else
        echo "Nothing to uninstall at $INSTALL_DIR"
    fi
    # preserve the most recent .bak-* (do not touch backups)
}

fetch_and_extract() {
    local dest="$1"
    mkdir -p "$dest"
    if ! curl -fsSL "$REPO_TARBALL" | tar -xz --strip-components=1 -C "$dest"; then
        echo "❌ Failed to fetch or extract $REPO_TARBALL" >&2
        exit 1
    fi
    # Defensive: ensure bundled scripts are executable even if the tarball
    # didn't preserve the mode bits.
    if [[ -d "$dest/scripts" ]]; then
        find "$dest/scripts" -type f -name "*.sh" -exec chmod +x {} \;
    fi
}

check_deps() {
    local missing_required=0
    for tool in yt-dlp gh jq curl tar; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required=1
            case "$tool" in
                yt-dlp) echo "⚠ yt-dlp not found — install: brew install yt-dlp" ;;
                gh)     echo "⚠ gh not found — install: brew install gh" ;;
                jq)     echo "⚠ jq not found — install: brew install jq" ;;
                curl)   echo "⚠ curl not found — install via your system package manager" ;;
                tar)    echo "⚠ tar not found — install via your system package manager" ;;
            esac
        fi
    done
    # uvx is optional — only YouTube transcript capture needs it
    if ! command -v uvx >/dev/null 2>&1; then
        echo "ℹ uvx not found (optional — required for YouTube transcripts): brew install uv"
    fi
    return $missing_required
}

prune_backups() {
    # Keep the most recent backup only
    local parent="$HOME/.agents/skills"
    local pattern="$parent/kf-cli.bak-"
    local -a olds
    # shellcheck disable=SC2207
    olds=($(ls -dt "$pattern"* 2>/dev/null | tail -n +2))
    if (( ${#olds[@]} > 0 )); then
        rm -rf "${olds[@]}"
    fi
}

print_next_steps() {
    cat <<'EOS'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Restart your agent so it picks up the new skill.
     • Claude Code / Codex / Gemini CLI / Cursor / Copilot: already linked via
       symlink above — just restart the agent.
     • OpenClaw: openclaw gateway restart

2. Authenticate gh once if you haven't (needed for /kf-cli:gitingest):
     gh auth login

3. Configure your vault + publishing target:
     cd /path/to/your/obsidian/vault
     export KF_VAULT_PATH="$PWD"
     # then from an agent turn:
     /kf-cli:setup

4. Verify the install:
     head -5 ~/.agents/skills/kf-cli/SKILL.md
     # should print "name: kf-cli" in the frontmatter

EOS
}

case "$MODE" in
    uninstall)
        uninstall
        exit 0
        ;;
    install|update)
        mkdir -p "$HOME/.agents/skills"
        if [[ -d "$INSTALL_DIR" ]]; then
            STAGING="$(mktemp -d)"
            fetch_and_extract "$STAGING"
            if diff -qr "$INSTALL_DIR" "$STAGING" >/dev/null 2>&1; then
                echo "✓ Already up-to-date at $INSTALL_DIR"
            else
                mv "$INSTALL_DIR" "$BACKUP_DIR"
                mv "$STAGING" "$INSTALL_DIR"
                STAGING=""   # mv consumed it — don't re-cleanup
                echo "✓ Installed to $INSTALL_DIR (previous version backed up to $BACKUP_DIR)"
                prune_backups
            fi
        else
            fetch_and_extract "$INSTALL_DIR"
            echo "✓ Installed to $INSTALL_DIR"
        fi
        # check_deps returns non-zero when required tools are missing. The `|| echo ...`
        # is load-bearing under `set -euo pipefail`: without it the script would abort
        # here instead of printing the next-steps block below. Do not "simplify" by
        # removing the `||` — the non-zero return is intentional and informational.
        check_deps || echo "   (install skills that need missing tools will fail until the warnings above are fixed)"
        if [[ "$DO_LINK" == "1" ]]; then
            link_to_tools
        else
            echo ""
            echo "(--no-link: skipped symlink step; canonical copy at $INSTALL_DIR)"
        fi
        print_next_steps
        ;;
esac
