---
description: Watch a YouTube video with visual frame analysis and save as a learning-focused note — uses claude-watch frames when available, falls back to transcript-only
argument-hint: [youtube-url-or-video-id] [optional context or instructions]
allowed-tools:
  - Bash(*)
  - Read(*)
  - Write(*)
  - WebFetch(*)
---

## Task

Create a **learning-focused** video note by watching the video (frames + transcript when possible)
and saving it using the `watch-note-template`.

**⚠️ You MUST use the Write tool to save the file to the vault!**

**Input**: `$ARGUMENTS` (YouTube URL or video ID, plus any optional context)
**Operation**: Watch → extract visual + transcript insights → save learning note
**Today's Date**: Run `date "+%Y-%m-%d"` to get current date

---

## Step 1 — Extract Video ID, Date & Metadata

```bash
# Extract video ID from various URL formats
ARGS="$ARGUMENTS"
VIDEO_ID=$(echo "$ARGS" | grep -oE '[?&]v=([^&[:space:]]+)' | head -1 | cut -d= -f2)
[[ -z "$VIDEO_ID" ]] && VIDEO_ID=$(echo "$ARGS" | grep -oE 'youtu\.be/([^?[:space:]]+)' | head -1 | sed 's|youtu.be/||')
[[ -z "$VIDEO_ID" ]] && VIDEO_ID=$(echo "$ARGS" | grep -oE '^[A-Za-z0-9_-]{11}$')

TODAY=$(date "+%Y-%m-%d")
echo "VIDEO_ID=$VIDEO_ID  TODAY=$TODAY"
```

Fetch metadata:
```bash
yt-dlp --dump-json --no-download "https://www.youtube.com/watch?v=$VIDEO_ID" 2>/dev/null \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('TITLE=' + d.get('title',''))
print('CHANNEL=' + d.get('channel',''))
print('UPLOAD_DATE=' + d.get('upload_date',''))
print('DURATION_SECS=' + str(d.get('duration',0)))
"
```

Convert `UPLOAD_DATE` (YYYYMMDD) to `VIDEO_DATE` (YYYY-MM-DD):
```bash
echo "$UPLOAD_DATE" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/'
```

Compute human duration:
```bash
python3 -c "s=$DURATION_SECS; print(f'{s//60}:{s%60:02d}')"
```

Find best thumbnail:
```bash
for res in maxresdefault sddefault hqdefault mqdefault; do
  STATUS=$(curl -sI "https://i.ytimg.com/vi/$VIDEO_ID/$res.jpg" | head -1 | awk '{print $2}')
  if [ "$STATUS" = "200" ]; then echo "$res"; break; fi
done
```

---

## Step 2 — Visual Pipeline (claude-watch) or Transcript Fallback

### Detect claude-watch

```bash
WATCH_PY=$(find "$HOME/.claude/plugins" \
  -path "*/claude-watch/*/scripts/watch.py" \
  -o -path "*/claude-watch/scripts/watch.py" \
  2>/dev/null | head -1)
echo "WATCH_PY=$WATCH_PY"
```

### Branch A — claude-watch is installed

If `$WATCH_PY` is non-empty, run the visual pipeline:

```bash
WORKDIR="/tmp/kf-watch-$VIDEO_ID"
mkdir -p "$WORKDIR"
python3 "$WATCH_PY" "https://www.youtube.com/watch?v=$VIDEO_ID" \
  --out-dir "$WORKDIR" 2>&1 | tail -20
```

After running, check what was produced:
```bash
FRAMES_DIR="$WORKDIR/frames"
FRAME_COUNT=$(ls "$FRAMES_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
TRANSCRIPT_VTT=$(find "$WORKDIR" -name "*.vtt" 2>/dev/null | head -1)
echo "FRAMES=$FRAME_COUNT  VTT=$TRANSCRIPT_VTT"
```

- **If `FRAME_COUNT > 0`**: Set `WATCH_MODE="visual (frames + transcript)"`.
  Use the Read tool to read each frame image in `$FRAMES_DIR/` (all *.jpg files).
  As you read each frame, note: timestamp marker (from filename or frame listing),
  what is on screen, any text visible, visual style/motion changes.
  This becomes the `{{VISUAL_OBSERVATIONS}}` and `{{HOOK_ANALYSIS}}` content.

- **If `FRAME_COUNT = 0` but `$TRANSCRIPT_VTT` exists**: Video download was blocked
  (YouTube SABR restriction). Set `WATCH_MODE="transcript-only (video download blocked)"`.
  Parse the VTT file for the transcript:
  ```bash
  python3 -c "
  import re
  with open('$TRANSCRIPT_VTT') as f: content = f.read()
  blocks = re.split(r'\n\n', content)
  seen = set()
  for block in blocks:
      lines = block.strip().split('\n')
      ts = next((l.split(' --> ')[0].strip() for l in lines if '-->' in l), None)
      if not ts: continue
      text = ''
      for l in reversed(lines):
          c = re.sub(r'<[^>]+>', '', l).strip()
          if c: text = c; break
      if text and text not in seen:
          seen.add(text)
          print(f'[{ts}] {text}')
  "
  ```
  Also download and read the thumbnail image for hook analysis:
  ```bash
  curl -sL "https://i.ytimg.com/vi/$VIDEO_ID/maxresdefault.jpg" -o "/tmp/kf-watch-thumb-$VIDEO_ID.jpg"
  ```
  Then Read("/tmp/kf-watch-thumb-$VIDEO_ID.jpg") and describe it for `{{HOOK_ANALYSIS}}`.

### Branch B — claude-watch is NOT installed

Set `WATCH_MODE="transcript-only (claude-watch not installed)"`.

Fetch transcript using kf-cli's bundled script:
```bash
TRANSCRIPT_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 7 \
  -path "*/kf-cli/scripts/core/fetch-youtube-transcript.sh" 2>/dev/null | head -1)
bash "$TRANSCRIPT_SCRIPT" "$VIDEO_ID" 2>/dev/null
```

Download and read the thumbnail for hook analysis:
```bash
curl -sL "https://i.ytimg.com/vi/$VIDEO_ID/maxresdefault.jpg" -o "/tmp/kf-watch-thumb-$VIDEO_ID.jpg"
```
Then Read("/tmp/kf-watch-thumb-$VIDEO_ID.jpg") and describe it for `{{HOOK_ANALYSIS}}`.

---

## Step 3 — Read the Template

```bash
KFCLI_TEMPLATES=$(find "$HOME/.claude/plugins" -maxdepth 6 \
  -path "*/kf-cli/templates" -type d 2>/dev/null | head -1)
cat "$KFCLI_TEMPLATES/watch-note-template.md"
```

---

## Step 4 — Fill Every Placeholder

Replace ALL `{{PLACEHOLDER}}` values. Never leave any placeholder unfilled.

| Placeholder | How to fill |
|-------------|-------------|
| `{{TITLE}}` | From yt-dlp metadata |
| `{{VIDEO_ID}}` | Extracted in Step 1 |
| `{{THUMBNAIL}}` | Best resolution filename (e.g. `maxresdefault.jpg`) |
| `{{DATE}}` | Today's date YYYY-MM-DD |
| `{{VIDEO_DATE}}` | Upload date YYYY-MM-DD |
| `{{CHANNEL}}` | From yt-dlp metadata |
| `{{DURATION}}` | Human format (e.g. `4:53`) |
| `{{PRIORITY}}` | high / medium / low — assess based on relevance to current context |
| `{{WATCH_MODE}}` | From Step 2 (visual or transcript-only + reason) |
| `{{TOPIC_TAGS}}` | 2-4 tags from taxonomy, comma-separated |
| `{{METADATA_TAGS}}` | 1-2 tags: tutorial, deep-dive, technical, actionable, conceptual, inspiration |
| `{{DESCRIPTION}}` | 2-3 sentences summarizing what the video covers and who it's for |
| `{{HOOK_ANALYSIS}}` | What the thumbnail communicates visually + what happens in the first 10s of transcript. If frames available, describe specific frames. Always include: thumbnail visual description, opening words with timestamps, hook strategy (in-media-res / problem-first / story / etc.) |
| `{{LEARNING_OBJECTIVES}}` | Bullet list: "- Understand X", "- Apply Y", "- Build Z" — things a learner can DO after watching |
| `{{CURRICULUM}}` | Timestamped table with **clickable timestamp links**. For each row, convert `MM:SS` to total seconds and format as: `[MM:SS](https://www.youtube.com/watch?v={{VIDEO_ID}}&t=Xs)` where X is seconds (e.g. `[01:23]` → 83s → `[01:23](https://www.youtube.com/watch?v=VIDEO_ID&t=83s)`). Include: topic and what was shown/said. If frames available, mark visual-heavy moments with 👁️ |
| `{{VISUAL_OBSERVATIONS}}` | If visual mode: specific observations from reading frames — UI shown, diagrams, code on screen, motion patterns, b-roll choices. If transcript-only: `*Note: visual analysis unavailable — {{WATCH_MODE}}. Re-watch for visual details.*` |
| `{{CORE_CONCEPTS}}` | 3-6 concepts with brief definitions. Format: `**Concept**: one-line explanation`. Include mental models, frameworks, and terms this video introduces or relies on |
| `{{KEY_INSIGHTS}}` | 3-5 bullet points: the most important things to remember from this video |
| `{{BEFORE_AFTER}}` | 2-3 rows: `**Before**: [assumption/gap] → **After**: [correct understanding]`. Make this specific — what actually changes in how you think |
| `{{OPEN_QUESTIONS}}` | 2-4 questions the video raised but didn't answer, or that you'd want to explore further |
| `{{SELF_TEST}}` | 3-5 Q&A pairs. Format: `**Q:** question\n**A:** answer`. Cover the key concepts — if you can answer these, you understood the video |
| `{{ACTION_CHECKLIST}}` | Checkbox list `- [ ] specific action`. Based directly on what the video shows or recommends. Be concrete, not generic |
| `{{TARGET_AUDIENCE}}` | Who gets the most value from this video |
| `{{TOPIC_ANALYSIS}}` | Brief explanation of why these topic tags were chosen |
| `{{COMPLEXITY_LEVEL}}` | quick-read / tutorial / deep-dive |
| `{{PRIORITY_REASONING}}` | Why this priority level |
| `{{TAG_REASONING}}` | Why these specific tags |
| `{{PRIMARY_TOPIC}}` | Single most relevant topic tag |
| `{{RELATED_SEARCHES}}` | 3-5 bullet points: related topics, creators, or concepts worth exploring |
| `{{CONNECTIONS}}` | Wikilinks to related notes in vault: `[[wiki/topic/topic|Description]]` |

---

## Step 5 — Save the Note

**Filename format**: `YYYY-MM-DD-channel-name-descriptive-title.md`
(slugify: lowercase, hyphens for spaces, max 60 chars total)

```bash
VAULT="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
FILEPATH="$VAULT/notes/YYYY-MM-DD-channel-descriptive-title.md"
```

Use the Write tool to save the completed note to `$FILEPATH`.

---

## Step 6 — Index the Note

```bash
SCRIPT=$(find "$HOME/.claude/plugins" \
  -path "*/kf-cli/hooks/scripts/index-note.sh" 2>/dev/null | head -1)
[[ -n "$SCRIPT" ]] && bash "$SCRIPT" "$FILEPATH"
```

Replace `$FILEPATH` with the actual absolute path used in Step 5.
