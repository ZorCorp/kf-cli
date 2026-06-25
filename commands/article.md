---
description: Create comprehensive articles/blog posts with auto-generated hero images
argument-hint: [topic or content]
allowed-tools:
  - Bash(*)
  - Write(*)
  - Read(*)
  - Task(*)
---

## Task

Create a comprehensive article with auto-generated hero image.

**Input**: `$ARGUMENTS` (topic, outline, or existing content)

## Process

### 1. Generate Hero Image (MANDATORY)

**Spawn a background subagent to generate the hero image using the Task tool.**

**CRITICAL: Use `mode: "bypassPermissions"` — background agents cannot get interactive Bash approval.**

```
Task tool call:
  subagent_type: "general-purpose"
  description: "Generate hero image"
  mode: "bypassPermissions"
  run_in_background: true
  prompt: |
    Generate a hero image for an article titled: [TITLE]
    Topic: [BRIEF TOPIC DESCRIPTION]

    Run this command:
    VAULT_PATH="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
    GEMINI_GEN_DIR="${GEMINI_IMG_GEN_DIR:-$HOME/.claude/skills/gemini-image-generator}"
    GEMINI_API_KEY="$GEMINI_API_KEY" "$GEMINI_GEN_DIR/scripts/venv/bin/python3" \
      "$GEMINI_GEN_DIR/scripts/generate.py" \
      --prompt "[DESCRIPTIVE IMAGE PROMPT - no text/words, modern, professional, vibrant]" \
      --output "$VAULT_PATH/images/{slug}-hero.jpg" \
      --size 2K

    GEMINI_API_KEY must be set as an environment variable (e.g. in ~/.zshrc).
    If not set, skip image generation and warn the user.
    Return the saved image path.
```

**Image prompt strategy:**
- Focus on visual metaphors and concepts
- Use descriptive, evocative language
- Specify professional/modern aesthetic
- Include relevant objects, scenes, or abstract concepts

**Wait for image generation to complete before proceeding.**

### 2. Structure Content

Analyze input and organize into natural sections:

**Common patterns (adapt as needed):**
- Introduction / Overview
- Core concepts / Main content
- Examples / Case studies
- Implementation / How-to (if applicable)
- Implications / Analysis
- Conclusion / Takeaways

**DO NOT force rigid structure** - let content dictate organization.

### 3. Apply Template

Read the template first:
```bash
KFCLI_TEMPLATES=$(find "$HOME/.claude/plugins" -maxdepth 6 -path "*/kf-cli/templates" -type d 2>/dev/null | head -1)
cat "$KFCLI_TEMPLATES/article-template.md"
```

Substitute:
- `{{TITLE}}` - Article title
- `{{DATE}}` - Current date (YYYY-MM-DD format)
- `{{SLUG}}` - Kebab-case filename slug
- `{{HERO_PATH}}` - Path to generated hero image
- `{{CONTENT}}` - Flexible article body
- `{{TAGS}}` - Comma-separated tags from the canonical vault tag list below (2-4 tags, no # prefix, no quotes)
- `{{SUMMARY}}` - 1-2 sentence summary

### 4. Save to Obsidian Vault

Use Write tool to save to `${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}/notes/{filename}`

**Filename format:** `YYYY-MM-DD-{slug}.md`

## Output Format

Markdown article with:
- ✅ Hero image embedded at top
- ✅ Flexible content structure
- ✅ Proper metadata (frontmatter)
- ✅ Relevant tags
- ✅ Date-prefixed filename

## Examples

```bash
/kf-cli:article Building a scambaiting AI strategy
→ Generates hero: scambaiting-ai-strategy-hero.jpg
→ Creates: 2026-02-07-building-scambaiting-ai-strategy.md

/kf-cli:article How to use Developer Knowledge API
→ Generates hero: developer-knowledge-api-hero.jpg
→ Creates: 2026-02-07-how-to-use-developer-knowledge-api.md
```

## Canonical Tag List for {{TAGS}}

Pick 2-4 from these vault topic tags based on content. Write as comma-separated values (no # prefix):

| Tag | Use when article is about |
|-----|--------------------------|
| `claude-code` | Claude Code CLI, agent SDK, hooks, MCP, Claude API |
| `gemini` | Gemini AI, Google AI tools, Google Cloud |
| `mcp` | Model Context Protocol, MCP servers/tools |
| `ai-tools` | AI agents, agentic workflows, LLMs, RAG, prompt engineering |
| `ai-media` | Image generation, audio AI, video AI |
| `kf` | Knowledge Factory, kf-cli, sharehub |
| `doublecopy` | DoubleCopy clipboard tool |
| `openclaw` | OpenClaw, Clawdbot, WhatsApp AI, nano-banana |
| `crewnest` | Crewnest AI company project |
| `investing` | Finance, stocks, crypto, trading, brokers |
| `eco-tech` | Sustainability, energy, science, geopolitics |
| `obsidian` | Obsidian PKM, plugins, knowledge management |

Always include at least one topic tag from this list so the note routes to the correct wiki topic.

## Important

- **Hero image is MANDATORY** - always generate before article
- **Flexible structure** - adapt to content, not forced sections
- **Tags in frontmatter ONLY** - never write tags as `**Tags:** #foo` in the body
- **Use subagent for image** - always spawn with `mode: "bypassPermissions"` to avoid background permission denial

## After Saving: Index the Note

Run the indexer with the exact file path used when saving:

```bash
SCRIPT=$(find "$HOME/.claude/plugins" -path "*/kf-cli/hooks/scripts/index-note.sh" 2>/dev/null | head -1)
[[ -n "$SCRIPT" ]] && bash "$SCRIPT" "/absolute/path/to/saved/note.md"
```

Replace `/absolute/path/to/saved/note.md` with the actual absolute path of the note just saved.
The script reads the note's tags, looks up the Tag → Topic mapping in `CLAUDE.md`, and updates the wiki automatically.
