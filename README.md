# kf-cli — Obsidian Knowledge Capture for Claude Code & OpenClaw

A skill package that captures any public/shareable video URL (YouTube, Vimeo, Loom, Zoom recordings, Twitch, TikTok, and any yt-dlp-supported site), articles, ideas, and GitHub repos into an Obsidian vault with AI auto-tagging. Publishes to GitHub Pages. No Docker. No MCP. Just CLI tools.

kf-cli is a **pure skill**: it exposes commands and templates only. Identity (who the agent is) and model choice (how it thinks) live in the agent or runtime that invokes the skill.

---

## Install

kf-cli follows the [Agent Skills specification](https://agentskills.io) — `SKILL.md` at the repo root, so every major AI tool can discover it.

**Canonical architecture:** real files always live at `~/.agents/skills/kf-cli/`. Every AI tool's skills directory gets a symlink that points there. One copy to manage, every tool sees the same files.

```
~/.agents/skills/kf-cli/          ← real files (single source of truth)
~/.claude/skills/kf-cli           → symlink → ~/.agents/skills/kf-cli
~/.gemini/skills/kf-cli           → symlink → ~/.agents/skills/kf-cli
~/.codex/skills/kf-cli            → symlink → ~/.agents/skills/kf-cli
~/.cursor/skills/kf-cli           → symlink → ~/.agents/skills/kf-cli
~/.copilot/skills/kf-cli          → symlink → ~/.agents/skills/kf-cli
```

### Option 1 — `npx skills add` (**recommended**)

```bash
npx skills add ZorCorp/kf-cli
```

Installs the real files to `~/.agents/skills/kf-cli/` and creates symlinks in each detected AI tool's skills directory (`.claude/skills/`, `.gemini/skills/`, `.codex/skills/`, `.cursor/skills/`, `.copilot/skills/`) pointing back to the canonical location. Add `-g` for a user-wide install that every project inherits.

Tell any AI agent to install it:

> Install the Agent Skill at github.com/ZorCorp/kf-cli using `npx skills add ZorCorp/kf-cli`.

Update / uninstall:

```bash
npx skills update ZorCorp/kf-cli   # pull latest, symlinks unchanged
npx skills remove ZorCorp/kf-cli   # remove skill + all links
```

**Windows (Git Bash):** if symlinks fail silently, `npx skills` falls back to NTFS junctions (`mklink /J`) — no admin rights or Developer Mode required.

### Option 2 — `gh skill install` (GitHub CLI 2.90.0+)

```bash
gh skill install ZorCorp/kf-cli
```

`gh skill` is **copy mode** (not symlinks), with interactive prompts for target agent and scope. Each agent ends up with its own copy. Good fit if you already use the `gh` workflow or prefer GitHub-signed release metadata.

Tell any AI agent to install it:

> Install the Agent Skill at github.com/ZorCorp/kf-cli using `gh skill install ZorCorp/kf-cli`.

### Option 3 — Claude Code plugin marketplace (Claude Code only)

If you use Claude Code exclusively and want to follow its official plugin update flow:

```
/plugin marketplace add ZorCorp/zorskill
/plugin install kf-cli
```

This path doesn't use `~/.agents/skills/` — Claude Code's plugin manager owns its own storage.

### Option 4 — Shell installer (no npx / gh dependency)

```bash
curl -fsSL https://raw.githubusercontent.com/ZorCorp/kf-cli/master/install.sh | bash
```

Same canonical architecture as Option 1 — installs to `~/.agents/skills/kf-cli/` and symlinks all detected tool dirs. Use this only if `npx` is unavailable in your environment.

```bash
curl -fsSL .../install.sh | bash -s -- --update        # update + refresh links
curl -fsSL .../install.sh | bash -s -- --uninstall     # remove skill + all kf-cli links
```

---

**Which should I pick?**

| Situation | Pick |
|---|---|
| Standard setup — cross-tool, canonical `~/.agents/skills/` layout (**recommended**) | **Option 1** (`npx skills`) |
| Already using the `gh` CLI, want GitHub release metadata | Option 2 (`gh skill`) |
| Claude Code only, prefer the official plugin flow | Option 3 (plugin marketplace) |
| No `npx` available | Option 4 (shell installer) |

All options install the same skill — **pick one; don't mix them** (whichever method runs last wins the per-tool skill path).

---

## Prerequisites

```bash
brew install yt-dlp gh jq uv
```

Verify: `yt-dlp --version && gh --version && jq --version && uvx --version`

---

## Configuration

The skill resolves the vault path at runtime:

1. `$KF_VAULT_PATH` environment variable (if set and contains `notes/`)
2. Current working directory (if it contains `notes/`)
3. `$HOME/Documents/Obsidian/myrag` (fallback default)

For publishing, run `/kf-cli:setup` inside your vault to create `.claude/config.local.json` with `sharehub_repo` and `sharehub_url`.

`/kf-cli:setup` also scaffolds the standard vault layout on first run — it creates `notes/`, `wiki/`, `raw/`, `output/`, `images/`, `Templates/` if missing, and seeds a starter `CLAUDE.md` (with the Capture → Wiki Rule + Tag → Topic mapping) plus `wiki/_master-index.md`. The seeding step is **non-destructive** — any existing `CLAUDE.md` or `_master-index.md` is preserved as-is.

Optional env vars:

| Var | Purpose | Default |
|---|---|---|
| `KF_VAULT_PATH` | Vault root | `$HOME/Documents/Obsidian/myrag` |
| `SHAREHUB_URL` | Published base URL | (required for publish) |
| `KF_SHARE_BASE_URL` | Share-link base URL | `https://example.com/share` |
| `GEMINI_IMG_GEN_DIR` | Gemini image-generator skill dir | `$HOME/.claude/skills/gemini-image-generator` |

---

## Don't use Obsidian?

**kf-cli does not require Obsidian at runtime.** The "vault" is just a folder containing a `notes/` subdirectory; kf-cli writes plain Markdown files with YAML frontmatter that any editor (VS Code, Zed, Typora, `bat`, `glow`, plain `cat`) can read. No Obsidian app, plugin, or local REST API is called.

### First-run on a machine without Obsidian

The vault resolver (listed above) falls back to `$HOME/Documents/Obsidian/myrag` if `$KF_VAULT_PATH` is unset and the current directory has no `notes/` folder. On a non-Obsidian system that path usually doesn't exist, and the first capture command will error on a missing directory. Two clean fixes:

**Option 1 — point at any directory (recommended):**

```bash
mkdir -p ~/kf-vault/notes
export KF_VAULT_PATH=~/kf-vault
# add the export to your shell rc if you want it permanent
```

**Option 2 — materialize the default path:**

If you'd rather not set an env var, just create the default path kf-cli looks for:

```bash
mkdir -p ~/Documents/Obsidian/myrag/notes
```

kf-cli will then find the fallback and write notes into `~/Documents/Obsidian/myrag/notes/` — Obsidian does not need to be installed for this to work. (The path is named after Obsidian only because that's the author's personal layout; it is otherwise an ordinary folder.)

### What degrades without Obsidian (cosmetic, not functional)

Notes cross-link with `[[path/to/note|Title]]` wikilink syntax. Obsidian renders those as clickable links; most other Markdown viewers show them as literal text. Published output via `/kf-cli:publish` is unaffected — sharehub's Jekyll config converts wikilinks server-side.

---

## Optional: floating read-status button (Obsidian only)

Every kf-cli capture template writes `read: false` into frontmatter. That field is inert on its own — it only lights up if you also install the floating read-status button, a small Obsidian Templater startup script that injects a 📕 / 📖 toggle into the corner of every note and flips the `read:` flag with one click.

This is **optional** and **Obsidian-specific**. Skip it if you don't use Obsidian.

**Install:**

1. In Obsidian, install the [Templater](https://github.com/SilentVoid13/Templater) community plugin.
2. Copy the script into your vault's Templates folder:
   ```bash
   cp ~/.agents/skills/kf-cli/templates/floating-read-button-startup.md "$KF_VAULT_PATH/Templates/"
   # Claude Code users: replace ~/.agents/skills/kf-cli with the plugin install dir
   ```
3. In Obsidian → Settings → Templater → **Startup Templates**, add `Templates/floating-read-button-startup.md`.
4. Restart Obsidian. The button appears on any note whose frontmatter contains `read:` (all kf-cli notes qualify).

---

## Commands

| Command | Description |
|---|---|
| `/kf-cli:capture <content>` | Smart router — any video URL, GitHub, article URL, or text |
| `/kf-cli:watch <url>` | Note from any video URL (YouTube, Vimeo, Loom, Zoom recordings, …); auto-picks instructional vs meeting template |
| `/kf-cli:youtube-note <url>` | _Deprecated_ — use `/kf-cli:watch`. YouTube-only transcript note kept for backward compatibility |
| `/kf-cli:idea <text>` | Quick idea capture with AI tagging |
| `/kf-cli:gitingest <github-url>` | GitHub repo analysis digest |
| `/kf-cli:study-guide <source>` | Comprehensive study guide |
| `/kf-cli:article <topic>` | Article with auto-generated hero image |
| `/kf-cli:publish <file>` | Publish note to GitHub Pages |
| `/kf-cli:share <file>` | Generate shareable URL (no server) |
| `/kf-cli:semantic-search <query>` | Ripgrep + optional rerank over the vault |
| `/kf-cli:bulk-auto-tag` | AI-tag all untagged notes |
| `/kf-cli:setup` | Configure publishing destination |

See `COMMANDS.md` for details.

---

## Invocation patterns

- **Claude Code** — invoke commands as `/kf-cli:<command>`. The session's model handles all AI work.
- **OpenClaw, single-agent** — list `kf-cli` in one agent's allowed skills. That agent's configured model runs the commands.
- **OpenClaw, multi-agent** — list `kf-cli` on any agent that needs it. Each uses its own model.
- **Plain CLI** — `scripts/**/*.sh` is directly callable; `commands/*.md` are portable prompt templates any framework that reads Markdown skills can consume.

The model is always chosen by the invoker, never by the skill.

---

## Contributing

Source: `github.com/ZorCorp/kf-cli`. PRs welcome. Before submitting:

```bash
# Audit checks — must all pass
KF=.
grep -riE "claude-(sonnet|opus|haiku)|gpt-[0-9]|gemini-[0-9]|glm-|ollama/|minimax" "$KF" && echo "FAIL: model names" && exit 1
grep -rF "Documents/Obsidian" "$KF" | grep -v 'KF_VAULT_PATH' && echo "FAIL: hardcoded vault path" && exit 1
grep -riE "\bKira\b|\bZorro\b" "$KF" && echo "FAIL: identity leak" && exit 1
echo "PASS — skill is identity-free"
```

---

## License

MIT.
