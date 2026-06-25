---
description: "[DEPRECATED — use /kf-cli:watch] Fetch YouTube video transcript and create a video note with AI-powered smart tagging"
argument-hint: [youtube-url-or-video-id] (YouTube URL or video ID to process)
allowed-tools:
  - Bash(*)
  - WebFetch(*)
  - Write(*)
  - Read(*)
---

> [!WARNING] Deprecated — use `/kf-cli:watch`
> `/kf-cli:watch` supersedes this command. It handles YouTube **and** any other public/shareable
> video URL (Vimeo, Loom, Zoom recordings, etc.), auto-detects instructional vs meeting content,
> adds visual frame analysis when `claude-watch` is available, and produces clickable timestamped
> curricula. `/kf-cli:youtube-note` remains only for backward compatibility and may be removed in a
> future release. **Prefer `/kf-cli:watch <youtube-url>`.**

## Task

Create a YouTube video note using CLI tools (no MCP/Docker required).

**⚠️ You MUST use the Write tool to save the file to the vault!**

**Input**: `$ARGUMENTS` (YouTube URL or video ID)
**Operation**: YouTube video note creation
**Today's Date**: Run `date "+%Y-%m-%d"` to get current date

## Process

The skill will:
1. Extract video ID from URL/argument
2. Fetch transcript using bundled script (locate it dynamically — the plugin may live under a marketplace):
   ```bash
   TRANSCRIPT_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 7 -path "*/kf-cli/scripts/core/fetch-youtube-transcript.sh" 2>/dev/null | head -1)
   bash "$TRANSCRIPT_SCRIPT" "$VIDEO_ID"
   ```
3. Fetch video metadata using yt-dlp:
   ```bash
   yt-dlp --dump-json --no-download "https://www.youtube.com/watch?v=$VIDEO_ID" 2>/dev/null
   ```
   Extract: title, channel, description, duration, upload_date from the JSON output.
   If yt-dlp is not available, use WebFetch to get the YouTube page and extract metadata from HTML.
4. **Read and substitute template** (see CRITICAL section below)
5. Analyze content and apply AI-powered smart tagging (using tag taxonomy)
6. Save note using Write tool to `${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}/notes/{filename}`

## ⚠️ CRITICAL: Template Compliance

**You MUST follow this exact workflow - DO NOT skip any steps:**

### Step 1: Read the Template File FIRST

Before generating ANY content, execute this command:
```bash
KFCLI_TEMPLATES=$(find "$HOME/.claude/plugins" -maxdepth 6 -path "*/kf-cli/templates" -type d 2>/dev/null | head -1)
cat "$KFCLI_TEMPLATES/youtube-note-template.md"
```

### Step 2: Use EXACT Field Names from Template

| ✅ CORRECT | ❌ WRONG |
|-----------|----------|
| `url:` | `source:` |
| `channel:` | `creator:` |
| `cover:` | (missing) |
| `video_date:` | `published:` |
| `priority:` | (missing) |

### Step 3: Include ALL Required Elements

**Frontmatter MUST include:**
- [ ] `type: video`
- [ ] `status: inbox`
- [ ] `read: false` ← **REQUIRED for tracking read status**
- [ ] `cover:` with best available thumbnail (see Thumbnail Resolution below)
- [ ] `url:` with full YouTube URL
- [ ] `channel:` with channel name
- [ ] `video_date:` with video publication date
- [ ] `duration:` with video length
- [ ] `priority:` (low/medium/high)
- [ ] `tags:` array with proper taxonomy

**Content MUST include:**
- [ ] Clickable thumbnail: `[![Watch on YouTube](thumbnail_url)](video_url)` after H1 title
- [ ] Emoji section headers: 📖 🎯 📋 📝 ⭐ 🏷️ 🔗
- [ ] Rating section with Quality/Relevance/Recommend fields
- [ ] Footer with "Captured:", "Source:", "Channel:"

### Step 4: Literal Substitution

**DO NOT:**
- ❌ Generate your own structure
- ❌ Reorganize or reorder sections
- ❌ Omit any fields or sections
- ❌ Change field names
- ❌ Remove emojis from headers

**DO:**
- ✅ Read the raw template content
- ✅ Replace `{{PLACEHOLDER}}` with actual values
- ✅ Keep ALL sections, even if some data is unavailable (mark as "N/A")

## Thumbnail Resolution

**Not all YouTube videos have `maxresdefault.jpg`.** You MUST check availability and use the best working resolution.

Run this to find the best thumbnail:
```bash
VIDEO_ID="<video_id>"
for res in maxresdefault sddefault hqdefault mqdefault; do
  STATUS=$(curl -sI "https://i.ytimg.com/vi/$VIDEO_ID/$res.jpg" | head -1 | awk '{print $2}')
  if [ "$STATUS" = "200" ]; then echo "$res.jpg"; break; fi
done
```

**Resolution priority** (use first that returns 200):
1. `maxresdefault.jpg` (1280x720)
2. `sddefault.jpg` (640x480)
3. `hqdefault.jpg` (480x360)
4. `mqdefault.jpg` (320x180)

Replace `{{THUMBNAIL}}` in the template with the chosen filename.

## Tag Taxonomy Reference

**Topics:** AI, productivity, knowledge-management, development, learning, research, writing, tools, business, design, automation, data-science, web-development, personal-growth, finance
**Status:** inbox (default for new videos)
**Metadata:** tutorial, deep-dive, quick-read, technical, conceptual, actionable, inspiration

## Expected Output

A comprehensive video note with:
- Proper frontmatter (title, tags, url, cover, date, type, status, priority, duration, channel)
- Clickable YouTube thumbnail
- Description and learning objectives
- Structured curriculum with timestamps
- Key takeaways and insights
- Rating section
- Tags analysis and filtering suggestions
- Related topics

**File naming format**: `[date]-[creator-name]-[descriptive-title].md`
**Tag count**: 6-8 tags total

## After Saving: Index the Note

Run the indexer with the exact file path used when saving:

```bash
SCRIPT=$(find "$HOME/.claude/plugins" -path "*/kf-cli/hooks/scripts/index-note.sh" 2>/dev/null | head -1)
[[ -n "$SCRIPT" ]] && bash "$SCRIPT" "/absolute/path/to/saved/note.md"
```

Replace `/absolute/path/to/saved/note.md` with the actual absolute path of the note just saved.
The script reads the note's tags, looks up the Tag → Topic mapping in `CLAUDE.md`, and updates the wiki automatically.
