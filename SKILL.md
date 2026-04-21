---
name: kf-cli
description: Manage Obsidian knowledge base - capture ideas, YouTube videos, articles, repositories, create study guides, publish to GitHub Pages, and share notes via URL (no server storage). Use smart AI tagging for automatic organization. CLI-native — no Docker/MCP required.
license: MIT
allowed-tools:
  - Bash(*)
  - Read(*)
  - Write(*)
  - Edit(*)
  - Glob(*)
  - WebFetch
  - Task(*)
  - SlashCommand(*)
metadata:
  version: "0.6.0"
  repository: https://github.com/ZorCorp/kf-cli
  homepage: https://github.com/ZorCorp/kf-cli
---

# Obsidian Vault Manager (CLI-Native)

Manage an AI-powered Obsidian knowledge base with automatic organization and GitHub Pages publishing. This is the **CLI-native** version — uses `yt-dlp`, `gh` CLI, `curl`, and direct file operations instead of MCP/Docker.

## Vault Configuration

The skill resolves the vault path at runtime in this order:

1. `$KF_VAULT_PATH` environment variable (if set and `$KF_VAULT_PATH/notes/` exists)
2. Current working directory (if it contains `notes/`)
3. `$HOME/Documents/Obsidian/myrag` (fallback default)

- **Publishing target**: configured by `/kf-cli:setup` — see `$VAULT/.claude/config.local.json` (`sharehub_repo`, `sharehub_url` keys).
- **GitHub repository for publishing**: any repo you configure; not hardcoded.

## CLI Tool Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| `yt-dlp` | YouTube metadata & transcripts | `brew install yt-dlp` |
| `gh` | GitHub API access | `brew install gh` |
| `jq` | JSON parsing | `brew install jq` |
| `uvx` | YouTube transcript API | `brew install uv` |
| `curl` | HTTP requests | System default |
| `git` | Version control | System default |
| `python3` | Share URL generation | System default |

**No Docker required.**

## Tag Taxonomy (STRICT - Use Only These)

### Content Type Tags (choose 1)
- `idea` - Random thoughts, concepts, brainstorms
- `video` - YouTube videos, lectures
- `article` - Web articles, blog posts
- `study-guide` - Learning materials, courses
- `repository` - Code repositories, technical analysis
- `reference` - Documentation, quick lookups
- `project` - Project notes, planning

### Topic Tags (choose 2-4 relevant)
- `AI` - Artificial intelligence, machine learning
- `productivity` - Time management, workflows, GTD
- `knowledge-management` - PKM, note-taking, Obsidian
- `development` - Programming, software engineering
- `learning` - Education, study techniques
- `research` - Academic, scientific papers
- `writing` - Content creation, blogging
- `tools` - Software tools, applications
- `business` - Entrepreneurship, strategy
- `design` - UI/UX, visual design
- `automation` - Workflows, scripts, efficiency
- `data-science` - Analytics, statistics
- `web-development` - Frontend, backend, full-stack
- `personal-growth` - Self-improvement, habits
- `finance` - Money, investing, economics

### Status Tags (choose 1)
- `inbox` - Just captured, needs processing
- `processing` - Currently working on
- `evergreen` - Timeless, permanent knowledge
- `published` - Shared publicly
- `archived` - Done, historical reference
- `needs-review` - Requires attention

### Priority/Metadata Tags (choose 0-2)
- `high-priority` - Important, urgent
- `quick-read` - <5 min to consume
- `deep-dive` - Complex, requires focus
- `technical` - Code-heavy, engineering
- `conceptual` - Theory, ideas, frameworks
- `actionable` - Contains next steps/todos
- `tutorial` - Step-by-step guide
- `inspiration` - Creative, motivational

## Core Operations

### 1. Capture Content (Universal Inbox)

Intelligently route content based on type and create properly tagged notes.

#### YouTube Videos

**CLI Tools Used:**
- **Transcript**: `scripts/core/fetch-youtube-transcript.sh` (uses `uvx youtube_transcript_api`)
- **Metadata**: `yt-dlp --dump-json --no-download "$URL"` → extracts title, channel, description, duration, upload_date
- **Thumbnail**: `curl -sI` to check resolution availability (maxresdefault → sddefault → hqdefault → mqdefault)
- **Template**: `templates/youtube-note-template.md`
- **Save**: Write tool to vault path

**Process:**
1. Extract VIDEO_ID from URL
2. Fetch transcript via bundled script
3. Fetch metadata via `yt-dlp --dump-json` (fallback: WebFetch YouTube page)
4. Check best thumbnail resolution
5. Read template, substitute `{{PLACEHOLDER}}` values
6. Apply smart tagging (6-8 tags)
7. Write file: `YYYY-MM-DD-creator-name-descriptive-title.md`

**Template Placeholders:**
- `{{TITLE}}` - Video title from metadata
- `{{VIDEO_ID}}` - Extracted video ID
- `{{CHANNEL}}` - Channel name
- `{{DATE}}` - Current date (YYYY-MM-DD)
- `{{TOPIC_TAGS}}` - 2-4 topic tags from taxonomy
- `{{METADATA_TAGS}}` - 1-2 metadata tags (tutorial, actionable, etc.)
- `{{PRIORITY}}` - high/medium/low
- `{{DURATION}}` - Estimated duration (~X minutes)
- `{{DESCRIPTION}}` - 2-3 sentence summary from transcript analysis
- `{{LEARNING_OBJECTIVES}}` - Bullet list of learning outcomes
- `{{CURRICULUM}}` - Structured outline with checkboxes
- `{{MAIN_INSIGHTS}}` - 3-5 key insights from transcript
- `{{ACTIONABLE_POINTS}}` - Practical takeaways
- `{{TARGET_AUDIENCE}}` - Who should watch this
- `{{TOPIC_ANALYSIS}}` - Explanation of chosen topics
- `{{COMPLEXITY_LEVEL}}` - quick-read/tutorial/deep-dive
- `{{PRIORITY_REASONING}}` - Why this priority
- `{{TAG_REASONING}}` - Tag selection explanation
- `{{PRIMARY_TOPIC}}` - Main topic for filtering
- `{{RELATED_SEARCHES}}` - Suggested semantic searches
- `{{CONNECTIONS}}` - Links to related notes
- `{{THUMBNAIL}}` - Best available thumbnail filename

**Tag Count:** 6-8 tags total
**Always include:** `video`, `inbox`, 2-4 topic tags, 1-2 metadata tags, optional content-specific tags

#### Ideas & Quick Thoughts

**CLI Tools Used:**
- **Template**: `templates/idea-template.md`
- **Save**: Write tool to vault path

**Process:**
1. Analyze idea content for concepts and tags
2. Read template, substitute placeholders
3. Apply smart tagging (5-8 tags)
4. Write file: `YYYY-MM-DD-3-5-word-idea-name.md`

**Template Placeholders:**
- `{{TITLE}}` - Concise idea title
- `{{TOPIC_TAGS}}` - 2-4 topic tags from taxonomy (comma-separated)
- `{{METADATA_TAGS}}` - 1-2 metadata tags (actionable, conceptual, inspiration, etc.)
- `{{DATE}}` - Current date (YYYY-MM-DD)
- `{{PRIORITY}}` - high/medium/low
- `{{CORE_IDEA}}` - Cleaned idea description (1-2 paragraphs)
- `{{WHY_MATTERS}}` - 1-2 sentences on potential impact or value
- `{{RELATED_CONCEPTS}}` - Bullet list of related concepts
- `{{NEXT_STEPS}}` - If actionable: 2-3 next steps. Otherwise: "Further research needed"
- `{{TOPICS_EXPLANATION}}` - Explanation of why these topics were chosen
- `{{CHARACTERISTICS_EXPLANATION}}` - Why it's actionable/conceptual/inspiration
- `{{PRIORITY_EXPLANATION}}` - Reasoning for priority level
- `{{TAG_REASONING}}` - Overall tag selection explanation
- `{{PRIMARY_TOPIC}}` - Main topic for filtering
- `{{SECONDARY_TOPIC}}` - Secondary topic for filtering
- `{{RELATED_CONCEPT}}` - For semantic search suggestions

**Tag Count:** 5-8 tags total
**Always include:** `idea`, `inbox`, 2-4 topic tags, 1-2 metadata tags

#### GitHub Repositories

**CLI Tools Used:**
- **Repository info**: `gh api /repos/{owner}/{repo}`
- **File tree**: `gh api /repos/{owner}/{repo}/git/trees/{branch}?recursive=1`
- **File contents**: `gh api /repos/{owner}/{repo}/contents/{path}` (base64 decode)
- **Commits**: `gh api /repos/{owner}/{repo}/commits?per_page=10`
- **Save**: Write tool to vault path

**Process:**
1. Parse GitHub URL for owner/repo
2. Fetch repo info, file tree, key file contents via `gh api`
3. Analyze tech stack, architecture, patterns
4. Apply smart tagging (6-8 tags)
5. Write file: `YYYY-MM-DD-repo-name-repository-analysis.md`

#### Web Articles

**CLI Tools Used:**
- **Fetch content**: WebFetch (primary) or `curl` (fallback)
- **Template**: `templates/article-template.md`
- **Save**: Write tool to vault path

#### Study Guides

**CLI Tools Used:**
- **Fetch content**: WebFetch (primary) or `curl` (fallback)
- **Template**: `templates/study-guide-template.md`
- **Save**: Write tool to vault path

**Process:**
1. Fetch content from URL (WebFetch), file (Read tool), or use provided text
2. Analyze for topics, complexity, prerequisites, and estimated study time
3. Read template, substitute placeholders
4. Apply smart tagging (6-8 tags)
5. Write file: `YYYY-MM-DD-topic-name-study-guide.md`

**Template Placeholders:**
- `{{TITLE}}` - Study subject/topic name
- `{{TOPIC_TAGS}}` - 2-4 topic tags from taxonomy (comma-separated)
- `{{METADATA_TAGS}}` - 1-2 metadata tags (deep-dive, technical, tutorial, etc.)
- `{{SOURCE}}` - Source URL or file reference
- `{{DATE}}` - Current date (YYYY-MM-DD)
- `{{DIFFICULTY}}` - beginner/intermediate/advanced
- `{{ESTIMATED_TIME}}` - Study time (e.g., "40 hours", "2 weeks")
- `{{PRIORITY}}` - high/medium/low
- `{{LEARNING_OBJECTIVES}}` - Bulleted checklist of objectives
- `{{PREREQUISITES}}` - Required background knowledge
- `{{STUDY_METHOD}}` - Recommended approach (active reading, practice-based, mixed)
- `{{CONTENT_STRUCTURE}}` - Weekly breakdown with concepts/activities/assessments
- `{{MATERIAL_STRATEGIES}}` - Content-specific study strategies
- `{{PRACTICE_EXERCISES}}` - Practical exercises or projects
- `{{TEACHING_TECHNIQUES}}` - How to teach/explain concepts
- `{{WEEK1_ASSESSMENT}}` - Early knowledge check questions
- `{{FINAL_ASSESSMENT}}` - Comprehensive assessment questions
- `{{PROGRESS_STATUS}}` - Weekly completion tracking checklist
- `{{NEXT_MILESTONE}}` - Specific next goal
- `{{RELATED_NOTES}}` - Wiki-style links to related content
- `{{TOPICS_EXPLANATION}}` - Why these topics were chosen
- `{{DIFFICULTY_EXPLANATION}}` - Difficulty level reasoning
- `{{CHARACTERISTICS_EXPLANATION}}` - Content characteristics (technical, deep-dive, etc.)
- `{{PRIORITY_EXPLANATION}}` - Priority reasoning
- `{{TAG_REASONING}}` - Overall tag selection explanation
- `{{PRIMARY_TOPIC}}` - Main topic for filtering
- `{{SECONDARY_TOPIC}}` - Secondary topic for filtering
- `{{RELATED_CONCEPT}}` - For semantic searches
- `{{FOUNDATIONAL_TOPIC}}` - Base knowledge topic
- `{{NEXT_ACTION}}` - Specific next step in study plan

**Tag Count:** 6-8 tags total
**Status:** Always use `processing` for study guides (not `inbox`)
**Always include:** `study-guide`, `processing`, 2-4 topic tags, 1-2 metadata tags

### 2. Publish to GitHub Pages

**CLI Tools Used:**
- **Script**: `scripts/core/publish.sh` (handles images, path conversion, git push)
- **Verification**: `scripts/core/verify-publish.sh`
- **Execution**: Task tool (spawns background agent)

**Publishing Paths (configurable):**
- **Vault**: `$KF_VAULT_PATH` (or fallback resolution — see Vault Configuration)
- **Sharehub local clone**: `sharehub_repo` in `$VAULT/.claude/config.local.json`
- **Sharehub remote repo**: configured by `/kf-cli:setup`
- **Published URL**: `sharehub_url` in `$VAULT/.claude/config.local.json`

### 3. Share via URL

**CLI Tools Used:**
- **Python script**: zlib compression + base64 encoding + CRC32 checksum
- **Clipboard**: `pbcopy` (macOS)
- **Execution**: Task tool (spawns background agent)

### 4. Search Vault

**CLI Tools Used:**
- **API**: Obsidian Local REST API on `https://127.0.0.1:27124/`
- **Auth**: API key from `.obsidian/plugins/obsidian-local-rest-api/data.json`
- **HTTP**: `curl` with Bearer token

### 5. Bulk Tag Notes

**CLI Tools Used:**
- **Discovery**: Glob tool
- **Read/Write**: Read and Edit tools
- **No external dependencies**

## CLI Tools Reference

### Primary Tools (replaces MCP)
| Operation | CLI Tool |
|-----------|----------|
| Create/write vault files | `Write(*)` tool |
| Read vault files | `Read(*)` tool |
| Update file sections | `Edit(*)` tool |
| YouTube metadata | `yt-dlp --dump-json` |
| YouTube transcript | `scripts/core/fetch-youtube-transcript.sh` |
| Web content | `WebFetch` tool |
| GitHub API | `gh api /repos/{owner}/{repo}/...` |
| Publishing | `scripts/core/publish.sh` |
| Search | `curl` to Local REST API |
| Share URLs | Python zlib + base64 |

## Response Format

When completing operations:
1. **Confirm action**: "✅ Created video note: [title]"
2. **Show frontmatter**: Display YAML tags and metadata
3. **Provide path**: Show filename and location
4. **For publishing**: Include GitHub Pages URL
5. **Be concise**: Action-oriented responses

## Quality Standards

- **Consistent tagging**: Use ONLY the defined taxonomy
- **Correct tag counts**: 5-8 for ideas, 6-8 for videos/study-guides
- **Complete frontmatter**: All required YAML fields
- **Clean formatting**: Proper markdown structure
- **Meaningful titles**: Descriptive, searchable
- **Actionable content**: Include next steps where relevant
- **Smart defaults**: Medium priority, inbox status for new captures (except study-guides use processing)
- **Date stamps**: Always include capture date (YYYY-MM-DD)
- **Filename rules**: Follow format for each content type

## Integration with Bases

These tags enable powerful Bases filtering queries like:

- "Show all `inbox` items with `high-priority`"
- "Show `video` content about `AI` and `productivity`"
- "Show `actionable` items in `processing` status"
- "Show `technical` `tutorial` content for learning"

**Always create tags with filtering in mind.**
