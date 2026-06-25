# kf-cli Command Reference

All commands use the `/kf-cli:` prefix. Short commands (e.g., `/capture`) can be enabled via `/kf-cli:setup --enable-short-commands`.

---

## Quick Reference

| Command | Purpose | Input |
|---------|---------|-------|
| `capture` | Smart router -- delegates to the right handler | Any content |
| `watch` | Note from any video URL; auto-picks instructional vs meeting template | Any video URL (YouTube, Vimeo, Loom, Zoom recordings, …) or YouTube ID |
| `youtube-note` | _Deprecated — use `watch`_. YouTube-only transcript note | YouTube URL or video ID |
| `idea` | Quick idea capture | Plain text |
| `gitingest` | GitHub repository analysis digest | GitHub URL |
| `study-guide` | Comprehensive study guide | URL, file path, or text |
| `article` | Article with auto-generated hero image | Topic or content |
| `publish` | Publish note to GitHub Pages | Filename |
| `share` | Share note via URL-encoded link | Filename |
| `bulk-auto-tag` | Bulk tag existing notes | Folder path or file pattern |
| `semantic-search` | Search vault via Local REST API | Search query |
| `setup` | Setup wizard and dependency check | `--enable-short-commands` (optional) |

---

## Commands

### 1. `/kf-cli:capture`

Smart router that analyzes input and delegates to the appropriate handler.

**Syntax**

```
/kf-cli:capture <content>
```

**Routing Rules** (checked in order):

| Priority | Pattern | Delegates To |
|----------|---------|--------------|
| 1 | Known video host (`youtube.com`, `youtu.be`, `vimeo.com`, `loom.com`, `tiktok.com`, `twitch.tv`, `*.zoom.us`/`zoom.com`) | `watch` |
| 2 | `github.com` URL | `gitingest` |
| 3 | Unknown `http(s)` URL that `yt-dlp --simulate` recognises as video | `watch` |
| 4 | Input > 1000 chars or contains "article"/"blog"/"comprehensive" | `article` |
| 5 | Any remaining `http://` or `https://` URL | `study-guide` |
| 6 | Plain text (no URL) | `idea` |

**CLI Tools Used**: None directly (pure router).

**Examples**

```
/kf-cli:capture https://youtube.com/watch?v=abc123
/kf-cli:capture https://github.com/anthropics/claude-code
/kf-cli:capture https://medium.com/article-about-ai
/kf-cli:capture Build a browser extension for note capture
```

**Output**: Delegates to the matched handler; no file created by this command itself.

---

### 2. `/kf-cli:youtube-note` _(deprecated)_

> **Deprecated — use `/kf-cli:watch`.** `/watch` handles YouTube and any other public/shareable
> video URL, auto-detects instructional vs meeting content, and adds visual frame analysis when
> available. `youtube-note` is kept only for backward compatibility and may be removed in a future
> release.

Fetches a YouTube video transcript and metadata, then creates a structured video note with timestamps, curriculum, and AI-powered tags.

**Syntax**

```
/kf-cli:youtube-note <youtube-url-or-video-id>
```

**CLI Tools Used**: `fetch-youtube-transcript.sh` (bundled), `yt-dlp`, `curl`, `date`.

**Process**

1. Extract video ID from URL
2. Fetch transcript via bundled script
3. Fetch metadata via `yt-dlp --dump-json`
4. Check thumbnail availability (maxresdefault > sddefault > hqdefault > mqdefault)
5. Populate template and apply smart tags
6. Save to vault

**Examples**

```
/kf-cli:youtube-note https://www.youtube.com/watch?v=dQw4w9WgXcQ
/kf-cli:youtube-note dQw4w9WgXcQ
```

**Output**: `YYYY-MM-DD-creator-name-descriptive-title.md` with frontmatter (`type: video`, `status: inbox`, `cover`, `url`, `channel`, `duration`, `priority`, tags), clickable thumbnail, curriculum with timestamps, key takeaways, and rating section.

---

### 3. `/kf-cli:idea`

Captures a quick idea with AI-generated tags and structured sections.

**Syntax**

```
/kf-cli:idea <idea-text>
```

**CLI Tools Used**: `date`.

**Process**

1. Get current date
2. Analyze idea content
3. Read and populate idea template
4. Apply smart tags from taxonomy
5. Save to vault

**Examples**

```
/kf-cli:idea Use AI to automatically categorize notes
/kf-cli:idea Knowledge compounds when connected properly
```

**Output**: `YYYY-MM-DD-3-to-5-word-name.md` with frontmatter (`type: idea`, `status: inbox`, tags, priority), core idea explanation, "why it matters" section, related concepts, and next steps.

---

### 4. `/kf-cli:gitingest`

Analyzes a GitHub repository using the `gh` CLI and creates an LLM-optimized markdown digest.

**Syntax**

```
/kf-cli:gitingest <github-url> [options]
```

**Options**

| Flag | Description | Default |
|------|-------------|---------|
| `--branch <name>` | Specific branch to analyze | Repo default |
| `--focus <mode>` | Filter files: `code`, `docs`, `config`, `all` | `all` |

**CLI Tools Used**: `gh api`, `date`.

**Examples**

```
/kf-cli:gitingest https://github.com/anthropics/claude-code
/kf-cli:gitingest https://github.com/user/repo --branch feature-branch
/kf-cli:gitingest https://github.com/user/repo --focus code
```

**Output**: `YYYY-MM-DD-repo-name-repository-analysis.md` with frontmatter (`type: repository`, `status: inbox`, detected languages, tech stack), repository overview, file tree, key file contents, technical stack analysis, repository metrics, and tags analysis.

**Limitations**: Files over 1MB are summarized. Binary files are listed but not included. Repos with 500+ files may be sampled. GitHub API rate limits apply (5000/hour with `gh` auth).

---

### 5. `/kf-cli:study-guide`

Generates a comprehensive study guide from any content source with structured learning objectives and self-assessment.

**Syntax**

```
/kf-cli:study-guide <content-source>
```

The `<content-source>` can be a URL, file path, or direct text.

**CLI Tools Used**: `date`, `WebFetch` (for URLs).

**Examples**

```
/kf-cli:study-guide https://example.com/machine-learning-course
/kf-cli:study-guide react-advanced-patterns.md
/kf-cli:study-guide Deep dive into distributed systems architecture
```

**Output**: `YYYY-MM-DD-topic-name-study-guide.md` with frontmatter (`type: study-guide`, `status: processing`, difficulty, estimated-time), learning objectives with checkboxes, structured study plan (weekly/modular), study strategies, self-assessment questions, and progress tracking.

---

### 6. `/kf-cli:article`

Creates a comprehensive article with an auto-generated hero image via Gemini.

**Syntax**

```
/kf-cli:article <topic-or-content>
```

**CLI Tools Used**: `date`, Gemini image generator script (`generate.py`), background Task subagent.

**Process**

1. Spawn background subagent to generate hero image via Gemini API
2. Wait for image generation to complete
3. Read and populate article template
4. Structure content into natural sections
5. Save to vault

**Examples**

```
/kf-cli:article Building a scambaiting AI strategy
/kf-cli:article How to use Developer Knowledge API
```

**Output**: `YYYY-MM-DD-slug.md` with frontmatter (tags, date, summary), hero image embedded at top (`images/slug-hero.jpg`), and flexible article body. Hero image is mandatory.

---

### 7. `/kf-cli:publish`

Publishes a note to GitHub Pages via the sharehub repository with image path conversion and verification.

**Syntax**

```
/kf-cli:publish <filename>
```

**CLI Tools Used**: `publish.sh` (bundled), `git`, spawned via Task subagent.

**Process**

1. Copies images from vault to sharehub repo
2. Converts image paths for web (`./images/` to `/images/`)
3. Copies note to `sharehub/documents/`
4. Git commit and push triggers GitHub Pages deployment
5. Verifies deployment (HTTP 200, HTML rendered, images OK)

**Password Protection**: Add `access: private` to frontmatter (password: "maco").

**Examples**

```
/kf-cli:publish my-article.md
/kf-cli:publish KFE/KF-MIGRATION-CHECKLIST.md
```

**Output**: Published URL at `https://<your-sharehub-host>/documents/{filename}.html`. Reports `VERIFIED_URL` (all checks passed) or `UNVERIFIED_URL` (published with issues).

---

### 8. `/kf-cli:share`

Generates a shareable URL containing the full note content encoded in the URL fragment (no server storage required).

**Syntax**

```
/kf-cli:share <filename>
```

**CLI Tools Used**: `python3` (zlib, base64, json), `pbcopy`, spawned via Task subagent.

**Process**

1. Reads vault path from `.claude/config.local.json`
2. Reads note content
3. Compresses via zlib, encodes as Base64
4. Adds CRC32 checksum for integrity
5. Generates URL and copies to clipboard

**Examples**

```
/kf-cli:share my-note.md
/kf-cli:share paydollar-test-plan
```

**Output**: Shareable URL at `https://<your-sharehub-host>/share#<encoded-data>`, auto-copied to clipboard. Warns if URL exceeds 4000 chars; recommends `/publish` if over 8000 chars.

---

### 9. `/kf-cli:bulk-auto-tag`

Scans existing notes and applies AI-powered tags from the taxonomy to enable Obsidian Bases filtering.

**Syntax**

```
/kf-cli:bulk-auto-tag [folder-path-or-file-pattern]
```

Defaults to all `.md` files in the vault (excluding `.obsidian/` and `.claude/`) if no argument is given.

**CLI Tools Used**: `find`, `date`.

**Tag Taxonomy**

| Category | Values |
|----------|--------|
| Content Types | idea, video, article, study-guide, repository, reference, project |
| Topics | AI, Claude, Gemini, product, marketing, projects, workflow, architecture, design, UI-UX, coding, productivity, knowledge-management, development, learning, research, writing, tools, business, automation, data-science, web-development, personal-growth, finance |
| Status | inbox, processing, evergreen, published, archived, needs-review |
| Metadata | high-priority, quick-read, deep-dive, technical, conceptual, actionable, tutorial, inspiration |

**Behavior**

- Skips notes already well-tagged (5+ taxonomy-compliant tags)
- Preserves existing user-added tags and frontmatter fields
- Processes in batches of 10 with progress reporting
- Reports tag distribution summary when complete

**Examples**

```
/kf-cli:bulk-auto-tag
/kf-cli:bulk-auto-tag *.md
/kf-cli:bulk-auto-tag KFE/
```

**Output**: Updated frontmatter in each processed file, plus a summary report with file counts, tag distribution by type/topic/status, and suggested Bases filter views.

---

### 10. `/kf-cli:semantic-search`

Searches the Obsidian vault using the Local REST API plugin.

**Syntax**

```
/kf-cli:semantic-search <query>
```

**CLI Tools Used**: `curl`, `jq`, `python3` (URL encoding).

**Prerequisites**

- Obsidian must be running
- Local REST API plugin installed and enabled (API on `https://127.0.0.1:27124/`)

**Examples**

```
/kf-cli:semantic-search KnowledgeFactory
/kf-cli:semantic-search migration checklist
```

**Output**: Top 10 matching files with match counts:

```
📄 KFE/KF-MIGRATION-CHECKLIST.md
   Matches: 15

📄 KnowledgeFactory/README.md
   Matches: 8
```

**Troubleshooting**: "Connection refused" means Obsidian is not running. "Authorization required" means the API key is misconfigured.

---

### 11. `/kf-cli:setup`

Interactive setup wizard that verifies dependencies, checks Obsidian plugins, discovers the sharehub repo, and creates vault configuration.

**Syntax**

```
/kf-cli:setup [--enable-short-commands]
```

**CLI Tools Used**: `git`, `jq`, `command -v` (dependency checks).

**What It Checks**

| Category | Items |
|----------|-------|
| Required CLI tools | `git`, `python3`, `jq`, `yt-dlp`, `gh` |
| Optional CLI tools | `uvx` (YouTube transcripts) |
| Obsidian plugins | Local REST API, Smart Connections |
| Publishing | Sharehub repo discovery and GitHub Pages URL |

**Options**

| Flag | Effect |
|------|--------|
| `--enable-short-commands` | Copies command files to `.claude/commands/` so `/capture` works instead of `/kf-cli:capture` |

**Examples**

```
/kf-cli:setup
/kf-cli:setup --enable-short-commands
```

**Output**: Creates `.claude/config.local.json` with `vault_path`, `sharehub_url`, `sharehub_repo`, and `enable_short_commands`. Prints a summary of all available commands and detected configuration.

---

## Dependencies

| Tool | Required By | Install |
|------|-------------|---------|
| `git` | publish, setup | `brew install git` |
| `python3` | share, semantic-search | Pre-installed on macOS |
| `jq` | setup, semantic-search | `brew install jq` |
| `yt-dlp` | youtube-note | `brew install yt-dlp` |
| `gh` | gitingest | `brew install gh` |
| `uvx` | youtube-note (optional) | `brew install uv` |
| `curl` | youtube-note, semantic-search | Pre-installed on macOS |

No Docker required. All commands use native CLI tools.
