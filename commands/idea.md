---
description: Create an idea file with AI-powered smart tagging for Bases filtering
argument-hint: [idea-text] (Your idea or concept to capture)
allowed-tools:
  - Bash(*)
  - Write(*)
  - Read(*)
---

## Task

Create an idea note using direct file operations (no MCP/Docker required).

**⚠️ You MUST use the Write tool to save the file to the vault!**

**Input**: `$ARGUMENTS` (Plain text idea or concept)
**Operation**: Idea note creation
**Today's Date**: Run `date "+%Y-%m-%d"` to get current date

## Process

1. Get today's date: `date "+%Y-%m-%d"`
2. Analyze idea content and determine main concepts
3. **Read template FIRST**:
   ```bash
   KFCLI_TEMPLATES=$(find "$HOME/.claude/plugins" -maxdepth 6 -path "*/kf-cli/templates" -type d 2>/dev/null | head -1)
   cat "$KFCLI_TEMPLATES/idea-template.md"
   ```
4. Apply AI-powered smart tagging (using tag taxonomy)
5. Generate smart filename: `{date}-{3-5-word-idea-name}.md`
6. Replace all `{{PLACEHOLDER}}` with actual values
7. Save note using Write tool to `${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}/notes/{filename}`

## Tag Taxonomy Reference

**Topics:** AI, productivity, knowledge-management, development, learning, research, writing, tools, business, design, automation, data-science, web-development, personal-growth, finance
**Status:** inbox (default for new ideas)
**Metadata:** actionable, conceptual, inspiration, high-priority

## Expected Output

A comprehensive idea note with:
- Proper frontmatter (title, tags, date, type, status, priority)
- Core idea explanation
- Why it matters section
- Related concepts
- Next steps (if actionable)
- Tags analysis and filtering suggestions
- Semantic search suggestions

**File naming format**: `[date]-[3-5-word-idea-name].md`
**Tag count**: 5-8 tags total

## Examples

**Input**: "Use AI to automatically categorize notes"
→ `2025-10-23-ai-note-categorization.md`

**Input**: "Knowledge compounds when connected properly"
→ `2025-10-23-knowledge-compound-connections.md`

## After Saving: Index the Note

Run the indexer with the exact file path used when saving:

```bash
SCRIPT=$(find "$HOME/.claude/plugins" -path "*/kf-cli/hooks/scripts/index-note.sh" 2>/dev/null | head -1)
[[ -n "$SCRIPT" ]] && bash "$SCRIPT" "/absolute/path/to/saved/note.md"
```

Replace `/absolute/path/to/saved/note.md` with the actual absolute path of the note just saved.
The script reads the note's tags, looks up the Tag → Topic mapping in `CLAUDE.md`, and updates the wiki automatically.
