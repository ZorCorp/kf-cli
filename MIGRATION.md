# Migrating from kf-claude to kf-cli

A guide for switching from the MCP/Docker-based `kf-claude` plugin to the native CLI-based `kf-cli` plugin.

## 1. Why Migrate

| | kf-claude | kf-cli |
|---|---|---|
| **Runtime** | MCP Docker container | Native CLI tools |
| **Docker required** | Yes | No |
| **Startup overhead** | Container spin-up per call | None |
| **External dependencies** | MCP server running | Standard CLI tools |
| **Offline capability** | Limited (needs MCP server) | Full (except web fetches) |

**Bottom line:** kf-cli is faster, simpler, and has no Docker dependency. Same functionality, fewer moving parts.

## 2. Prerequisites

Install these CLI tools before using kf-cli. All are available via Homebrew on macOS.

```bash
# Required
brew install yt-dlp    # YouTube metadata extraction
brew install gh        # GitHub API access
brew install jq        # JSON parsing
brew install uv        # Provides uvx for YouTube transcripts

# Verify installations
yt-dlp --version
gh auth status
jq --version
uvx --version

# These should already be available on macOS
python3 --version
git --version
curl --version
```

**GitHub CLI authentication** (if not already set up):

```bash
gh auth login
```

## 3. Quick Start

kf-cli installs as a separate Claude Code plugin. No changes to your existing kf-claude setup are needed.

```bash
# Test with a simple command
/kf-cli:idea Test idea to verify kf-cli is working

# Try YouTube capture
/kf-cli:watch https://youtube.com/watch?v=VIDEO_ID

# Try GitHub analysis
/kf-cli:gitingest https://github.com/owner/repo
```

If commands work, you're done. Start using `/kf-cli:` instead of `/kf-claude:`.

## 4. Command Mapping

Every kf-claude command has a 1:1 equivalent in kf-cli. Just change the prefix.

| kf-claude | kf-cli | Notes |
|---|---|---|
| `/kf-claude:capture` | `/kf-cli:capture` | Same routing logic |
| `/kf-claude:youtube-note` | `/kf-cli:youtube-note` | Uses yt-dlp + uvx instead of MCP get_video_info/get_transcript |
| (none) | `/kf-cli:watch` | New learning-focused YouTube workflow; no kf-claude equivalent |
| `/kf-claude:gitingest` | `/kf-cli:gitingest` | Uses `gh api` instead of MCP GitHub tools |
| `/kf-claude:article` | `/kf-cli:article` | Uses WebFetch/curl instead of MCP fetch |
| `/kf-claude:idea` | `/kf-cli:idea` | Uses Write tool instead of MCP obsidian_* |
| `/kf-claude:study-guide` | `/kf-cli:study-guide` | Uses WebFetch/curl instead of MCP fetch |
| `/kf-claude:publish` | `/kf-cli:publish` | Uses publish.sh script |
| `/kf-claude:share` | `/kf-cli:share` | Uses Python zlib + base64 |
| `/kf-claude:semantic-search` | `/kf-cli:semantic-search` | Uses curl to Local REST API |
| `/kf-claude:bulk-auto-tag` | `/kf-cli:bulk-auto-tag` | Uses Glob + Read + Edit tools |
| `/kf-claude:setup` | `/kf-cli:setup` | Verifies CLI tool installations |

### Tool Replacement Reference

| MCP/Docker Tool | CLI Replacement |
|---|---|
| `mcp__MCP_DOCKER__obsidian_*` (create, get, list) | `Write(*)`, `Read(*)`, `Glob(*)` |
| `mcp__MCP_DOCKER__get_video_info` | `yt-dlp --dump-json --no-download` |
| `mcp__MCP_DOCKER__get_transcript` | `scripts/core/fetch-youtube-transcript.sh` (uvx) |
| `mcp__MCP_DOCKER__get_file_contents` | `gh api /repos/{owner}/{repo}/contents/{path}` |
| `mcp__MCP_DOCKER__list_commits` | `gh api /repos/{owner}/{repo}/commits` |
| `mcp__MCP_DOCKER__search_code` | `gh api /search/code` |
| `mcp__MCP_DOCKER__firecrawl_scrape` / `fetch` | `WebFetch` or `curl` |
| `mcp__MCP_DOCKER__create_or_update_file` | `Write(*)` |
| `mcp__MCP_DOCKER__push_files` | `git push` via Bash |

## 5. Coexistence

Both plugins can run simultaneously. There are no conflicts.

- Commands are namespaced: `/kf-claude:youtube-note` and `/kf-cli:youtube-note` are independent
- Both write to the same vault path (resolved from `$KF_VAULT_PATH`, default `$HOME/Documents/Obsidian/myrag`)
- Both use the same templates and tag taxonomy
- You can mix and match commands from either plugin in the same session

This means you can migrate gradually -- use kf-cli for most tasks and fall back to kf-claude if needed.

## 6. Known Differences

**Speed**: kf-cli commands are faster because they skip Docker container overhead and MCP protocol negotiation.

**YouTube transcripts**: kf-claude uses `mcp__MCP_DOCKER__get_transcript` (Docker-hosted API). kf-cli uses `uvx youtube_transcript_api` via a bundled shell script. Both produce the same output.

**GitHub access**: kf-claude uses MCP GitHub tools which have their own auth. kf-cli uses `gh` CLI which uses your local GitHub auth (`gh auth login`). If you have private repo access via `gh`, kf-cli will too.

**File operations**: kf-claude writes files through MCP Obsidian tools. kf-cli uses Claude Code's native `Write`/`Read`/`Edit` tools, which are direct filesystem operations -- no intermediary.

**Web content**: kf-claude uses MCP fetch or Firecrawl. kf-cli uses `WebFetch` (Claude Code built-in) with `curl` as fallback.

**Output**: Notes created by either plugin are identical in format, frontmatter, and tagging. Templates are shared.

## 7. Rollback

If you need to switch back, just use the `/kf-claude:` prefix again. No uninstallation or configuration changes required.

```bash
# Switch back to kf-claude for any command
/kf-claude:youtube-note https://youtube.com/watch?v=VIDEO_ID
```

Since both plugins coexist, rollback is instant and per-command.
