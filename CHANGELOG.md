# Changelog

All notable changes to kf-cli will be documented in this file.

## [0.7.2] - 2026-07-02

- Quote SKILL.md description for strict-YAML so npx skills add/update works

## [0.7.1] - 2026-06-24

### Deprecated
- **`/kf-cli:youtube-note`** is deprecated in favour of **`/kf-cli:watch`**, which handles YouTube *and* any other public/shareable video URL, auto-detects instructional vs meeting content, and adds visual frame analysis when `claude-watch` is available. `youtube-note` still works for backward compatibility and may be removed in a future release. Added a deprecation banner to the command and flagged it across `README.md`, `COMMANDS.md`, `commands/setup.md`, and the vault-skeleton routing note.

## [0.7.0] - 2026-06-24

### Added
- **Any-video-URL support**, verified end-to-end against a Zoom cloud recording. `/watch` now handles any public/shareable video URL yt-dlp can reach — YouTube, Vimeo, Loom, Zoom recordings, Twitch, TikTok, and ~1800 other sites.
- **Content-type detection + meeting template**: `/watch` classifies the video as *instructional* (lecture/tutorial/talk) or *meeting* (call/standup/interview/recorded session) and picks the matching template — new `templates/meeting-note-template.md` (participants, decisions, action items, timeline) vs the existing learning-focused `watch-note-template.md`.
- **yt-dlp probe routing** in `/capture`: unknown `http(s)` URLs that miss the fast-path video-domain list are probed with `yt-dlp --simulate`; if recognised as video they route to `/watch`, otherwise they fall through to article handling. Added `Bash` to `capture.md` allowed-tools. Fast-path list extended with `zoom.us`/`zoom.com`.

### Fixed
- **No-thumbnail graceful degradation**: platforms that return no thumbnail (Zoom, Loom, Drive) no longer produce a broken `![]()` embed or a failed `curl` on an empty URL — the cover frontmatter is left blank and the body uses a plain watch link.
- Meeting recordings default to **transcript-only**, skipping the large (often 100MB+) frame download that adds little for talking-head/screen-share video.

### Changed
- Descriptions across `SKILL.md`, `README.md`, `plugin.json`, `marketplace.json`, and the `/watch` + `/capture` command frontmatter now state the any-video-URL capability honestly (login-gated / unshared-passcode video remains unsupported).

## [0.6.1] - 2026-04-21

### Added
- `/kf-cli:watch`: learning-focused YouTube capture with visual analysis when `claude-watch` is available, plus transcript fallback and the `watch-note-template`.
- `/kf-cli:capture` now routes YouTube URLs to `/kf-cli:watch` instead of transcript-only capture.

### Updated
- `commands/watch.md`, `templates/watch-note-template.md`, `commands/setup.md`, `COMMANDS.md`, `README.md`, and plugin metadata now include the watch workflow.

## [0.6.0] - 2026-04-21

### Added
- `install.sh`: auto-link step. After writing the canonical copy to `~/.agents/skills/kf-cli/`, the installer detects Claude Code / Codex / Gemini CLI / Cursor / GitHub Copilot and links each tool's skills dir to the canonical location. One place to manage, every tool sees the update.
- Cross-platform link type: POSIX symlinks on Linux / macOS, NTFS junctions (`mklink /J`) on Windows — no admin rights or Developer Mode required.
- `install.sh` flags: `--no-link` (skip link step), `--force-link` (link even if tool dir absent).
- `install.sh --uninstall`: removes all kf-cli links (only links pointing into our canonical dir) in addition to the canonical directory itself.
- `README.md`: rewrote Install section with 4 options — shell installer (recommended, symlink-based), Claude Code plugin marketplace, `npx skills add`, and `gh skill install`.
- `SKILL.md` frontmatter: added `license`, `metadata.version`, `metadata.repository`, `metadata.homepage` for Agent Skills spec completeness (used by `npx skills` and `gh skill update`).

### Preserved
- `~/.agents/skills/kf-cli/` remains the canonical real-file location (layout unchanged).
- `.claude-plugin/marketplace.json` structurally unchanged (version bump only).
- `install.sh` core behavior (`fetch_and_extract`, `diff -qr` update detection, `prune_backups`, `check_deps`) unchanged.

## [0.4.6] - 2026-04-13

### Added
- `youtube-note` template: added `read: false` frontmatter field for Obsidian floating read-status button compatibility (📕/📖 toggle)

## [0.4.5] - 2026-04-13

### Fixed
- `article` command: GEMINI_API_KEY is env-var only — no app-specific fallback. If not set, image generation is skipped with a warning. Set via `export GEMINI_API_KEY="..."` in `~/.zshrc`.

## [0.4.4] - 2026-04-13

### Fixed
- Expanded `allowed-tools` in all 12 commands to eliminate Claude Code permission prompts
  - `article`: `Bash(date)` → `Bash(*)`
  - `capture`: `Bash(date)` → `Bash(*), Read(*), Write(*), WebFetch(*)`
  - `gitingest`: `WebFetch` → `WebFetch(*)`
  - `publish`: added `Bash(*), Read(*)` alongside `Task(*)`
  - `share`: added `Bash(*), Read(*)` alongside `Task(*)`
  - `study-guide`: `WebFetch` → `WebFetch(*)`
  - `youtube-note`: `WebFetch` → `WebFetch(*)`
  - `bulk-auto-tag`, `idea`, `semantic-search`, `setup`: already complete, no changes needed

## [0.4.3] - 2026-04-13

### Fixed
- `article` command: `{{TAGS}}` now uses canonical vault topic tags (claude-code, gemini, mcp, ai-tools, etc.) routed to correct wiki topics
- `article` template: tags now formatted as `[article, {{TAGS}}]` YAML inline array — prevents freeform tag format bugs
- `article` command: explicit rule added — tags must be in frontmatter only, never as `**Tags:** #foo` in body

## [0.1.0] - 2026-03-12

### Added
- Initial release of kf-cli — native CLI replacement for kf-claude
- All 12 commands ported from kf-claude with MCP → CLI tool replacement:
  - `/kf-cli:capture` — Smart content router
  - `/kf-cli:watch` — Learning-focused YouTube analysis with frames + transcript
  - `/kf-cli:youtube-note` — YouTube video notes (yt-dlp + uvx transcript)
  - `/kf-cli:idea` — Quick idea capture
  - `/kf-cli:gitingest` — GitHub repository analysis (gh CLI)
  - `/kf-cli:study-guide` — Study guide generation (WebFetch)
  - `/kf-cli:article` — Article creation with Gemini hero images
  - `/kf-cli:publish` — GitHub Pages publishing
  - `/kf-cli:share` — URL-encoded sharing (zlib + base64 + CRC32)
  - `/kf-cli:bulk-auto-tag` — Bulk AI tagging
  - `/kf-cli:semantic-search` — Vault search via Obsidian REST API
  - `/kf-cli:setup` — Setup wizard with dependency checks
- SKILL.md with full CLI-native skill definition
- Templates symlinked from kf-claude (shared)
- Core scripts symlinked from kf-claude (publish.sh, fetch-youtube-transcript.sh, verify-publish.sh)
- Helper utilities in scripts/helpers/common.sh

### Changed (vs kf-claude)
- `mcp__MCP_DOCKER__obsidian_*` → `Write(*)` / `Read(*)` / `Edit(*)`
- `mcp__MCP_DOCKER__get_video_info` → `yt-dlp --dump-json`
- `mcp__MCP_DOCKER__get_transcript` → `scripts/core/fetch-youtube-transcript.sh`
- `mcp__MCP_DOCKER__fetch` / `firecrawl_scrape` → `WebFetch`
- MCP GitHub tools → `gh api`
- No Docker dependency required

### Performance
- Local I/O operations 100-500x faster (sub-ms vs MCP Docker overhead)
- No Docker cold start penalty (saves 2-5s on first call)
- Network-bound operations (yt-dlp, gh API) have similar latency
