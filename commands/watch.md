---
description: Watch any public video URL and save as a structured note — YouTube, Vimeo, Loom, Zoom recordings, Twitch, TikTok, and any yt-dlp-supported platform. Auto-detects instructional vs meeting content and picks the matching template. Uses claude-watch frames for instructional video when available; transcript-only otherwise.
argument-hint: [video-url-or-youtube-id] [optional context or instructions]
allowed-tools:
  - Bash(*)
  - Read(*)
  - Write(*)
  - WebFetch(*)
---

## Task

Create a structured video note by watching the video (transcript always, frames when useful)
and saving it using the template that fits the content type:

- **Instructional / creator video** (lecture, tutorial, talk, demo) → `watch-note-template`
- **Meeting / call / recorded session** (Zoom, Meet, Teams recordings, standups, interviews) → `meeting-note-template`

**Works with any public/shareable video URL that yt-dlp supports** — YouTube, Vimeo, Loom,
Zoom cloud recordings, Twitch, TikTok, X/Twitter, and ~1800 other sites. Videos that require a
login session or an unshared passcode are **not** supported (yt-dlp can't reach them).

**⚠️ You MUST use the Write tool to save the file to the vault!**

**Input**: `$ARGUMENTS` (video URL or YouTube video ID, plus any optional context)
**Today's Date**: Run `date "+%Y-%m-%d"` to get current date

---

## Step 1 — Detect Platform, Extract Metadata

```bash
ARGS="$ARGUMENTS"
URL=$(echo "$ARGS" | grep -oE 'https?://[^ ]+' | head -1)
TODAY=$(date "+%Y-%m-%d")

# Detect platform and normalise URL
if echo "$URL" | grep -qE '(youtube\.com|youtu\.be)'; then
  PLATFORM="youtube"
  VIDEO_ID=$(echo "$URL" | grep -oE '[?&]v=([^&[:space:]]+)' | head -1 | cut -d= -f2)
  [[ -z "$VIDEO_ID" ]] && VIDEO_ID=$(echo "$URL" | grep -oE 'youtu\.be/([^?[:space:]]+)' | head -1 | sed 's|.*youtu\.be/||')
  [[ -z "$VIDEO_ID" ]] && VIDEO_ID=$(echo "$ARGS" | grep -oE '^[A-Za-z0-9_-]{11}$')
  FULL_URL="https://www.youtube.com/watch?v=$VIDEO_ID"
elif [[ -n "$URL" ]]; then
  FULL_URL="$URL"
  # Derive a short platform label from the hostname (zoom, vimeo, loom, drive, etc.)
  PLATFORM=$(echo "$URL" | sed -E 's#https?://([^/]+)/.*#\1#' | sed -E 's/^www\.//; s/\.(com|us|tv|io|co|net|org).*//' | awk -F. '{print $NF}')
  [[ -z "$PLATFORM" ]] && PLATFORM="other"
else
  # Bare 11-char YouTube video ID
  PLATFORM="youtube"
  VIDEO_ID="$ARGS"
  FULL_URL="https://www.youtube.com/watch?v=$VIDEO_ID"
fi

echo "PLATFORM=$PLATFORM  FULL_URL=$FULL_URL  TODAY=$TODAY"

# Single working dir reused by every later step (transcript, frames, thumbnail).
WORKDIR="/tmp/kf-watch-$(echo "$FULL_URL" | md5 2>/dev/null | cut -c1-8)"
[[ -z "$WORKDIR" || "$WORKDIR" == "/tmp/kf-watch-" ]] && WORKDIR="/tmp/kf-watch-$$"
mkdir -p "$WORKDIR"
echo "WORKDIR=$WORKDIR"
```

Fetch metadata via yt-dlp (works for YouTube, Vimeo, Loom, Zoom, and any supported platform):
```bash
yt-dlp --dump-json --no-download "$FULL_URL" 2>/dev/null \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('TITLE=' + d.get('title',''))
print('CHANNEL=' + (d.get('channel','') or d.get('uploader','')))
print('UPLOAD_DATE=' + (d.get('upload_date','') or ''))
print('DURATION_SECS=' + str(d.get('duration',0) or 0))
print('THUMBNAIL_URL=' + (d.get('thumbnail','') or ''))
print('EXTRACTOR=' + (d.get('extractor','') or ''))
"
```

Convert `UPLOAD_DATE` (YYYYMMDD) to `VIDEO_DATE` (YYYY-MM-DD); if empty, fall back to today:
```bash
if [[ -n "$UPLOAD_DATE" ]]; then
  VIDEO_DATE=$(echo "$UPLOAD_DATE" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
else
  VIDEO_DATE="$TODAY"
fi
```

Compute human duration:
```bash
python3 -c "s=$DURATION_SECS; print(f'{s//60}:{s%60:02d}')"
```

Resolve cover URL — YouTube uses the ytimg CDN with resolution fallback; other platforms use the
thumbnail from yt-dlp metadata. **Many platforms (Zoom, Loom, Drive) return no thumbnail — that is
fine, leave `COVER_URL` empty and degrade gracefully later.**
```bash
if [[ "$PLATFORM" == "youtube" ]]; then
  COVER_URL=""
  for res in maxresdefault sddefault hqdefault mqdefault; do
    STATUS=$(curl -sI "https://i.ytimg.com/vi/$VIDEO_ID/$res.jpg" | head -1 | awk '{print $2}')
    if [ "$STATUS" = "200" ]; then
      COVER_URL="https://i.ytimg.com/vi/$VIDEO_ID/$res.jpg"
      break
    fi
  done
else
  COVER_URL="$THUMBNAIL_URL"   # may be empty — that's OK
fi
VIDEO_URL="$FULL_URL"
echo "COVER_URL=${COVER_URL:-<none>}  VIDEO_URL=$VIDEO_URL"
```

---

## Step 2 — Fetch the Transcript (always — it's cheap and drives everything)

Transcript is needed for both content-type detection and the note itself. Fetch it before any
heavy video download.

**YouTube** — use kf-cli's bundled transcript script:
```bash
TRANSCRIPT_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 7 \
  -path "*/kf-cli/scripts/core/fetch-youtube-transcript.sh" 2>/dev/null | head -1)
bash "$TRANSCRIPT_SCRIPT" "$VIDEO_ID" 2>/dev/null
```

**Any other platform (Zoom, Loom, Vimeo, …)** — extract subtitles/transcript via yt-dlp (into the
`$WORKDIR` from Step 1). Zoom recordings expose a `transcript` track; `--write-subs
--write-auto-subs` grabs whatever is present:
```bash
yt-dlp --write-subs --write-auto-subs --sub-format vtt --skip-download \
  -o "$WORKDIR/video" "$FULL_URL" 2>/dev/null
VTT_FILE=$(find "$WORKDIR" -name "*.vtt" 2>/dev/null | head -1)
if [[ -n "$VTT_FILE" ]]; then
  python3 -c "
import re
with open('$VTT_FILE') as f: content = f.read()
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
fi
```
If no subtitles/transcript are available, note that and proceed with metadata + visual analysis only.

---

## Step 3 — Detect Content Type → Choose Template

Using the **title, channel/host, and transcript**, classify the video:

- **`meeting`** — a recorded meeting, call, standup, interview, webinar, or working session.
  Signals: title contains "meeting", "call", "standup", "sync", "1:1", "interview", "review",
  "Personal Meeting Room", or a Zoom/Meet/Teams recording domain; transcript has multiple named
  speakers, conversational back-and-forth, scheduling/decision talk rather than teaching.
  → Use **`meeting-note-template.md`**.

- **`instructional`** — a lecture, tutorial, talk, demo, course, or creator video that teaches
  something to an audience. → Use **`watch-note-template.md`** (the learning-focused template).

Set `CONTENT_TYPE` accordingly. When genuinely ambiguous, default to `instructional`.

---

## Step 4 — Visual Analysis Decision

```bash
WATCH_PY=$(find "$HOME/.claude/plugins" \
  -path "*/claude-watch/*/scripts/watch.py" \
  -o -path "*/claude-watch/scripts/watch.py" \
  2>/dev/null | head -1)
echo "WATCH_PY=${WATCH_PY:-<not installed>}"
```

Decide the mode:

- **`CONTENT_TYPE` = meeting** → **transcript-only**. Do NOT run the frame pipeline. Meeting
  recordings are long and large (often 100MB+), and frames of talking heads / screen shares add
  little over the transcript. Set `WATCH_MODE="transcript-only (meeting recording)"`.

- **`CONTENT_TYPE` = instructional AND `$WATCH_PY` is set** → run the visual pipeline for frames:
  ```bash
  python3 "$WATCH_PY" "$FULL_URL" --out-dir "$WORKDIR" 2>&1 | tail -20
  FRAMES_DIR="$WORKDIR/frames"
  FRAME_COUNT=$(ls "$FRAMES_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
  echo "FRAMES=$FRAME_COUNT"
  ```
  - If `FRAME_COUNT > 0`: Set `WATCH_MODE="visual (frames + transcript)"`. Use the Read tool on each
    `$FRAMES_DIR/*.jpg` and note: timestamp, what's on screen, visible text, visual/motion changes.
    This becomes `{{VISUAL_OBSERVATIONS}}` and informs `{{HOOK_ANALYSIS}}`.
  - If `FRAME_COUNT = 0` (download blocked, e.g. YouTube SABR): Set
    `WATCH_MODE="transcript-only (video download blocked)"` and rely on the Step 2 transcript.

- **`CONTENT_TYPE` = instructional AND claude-watch NOT installed** → Set
  `WATCH_MODE="transcript-only (claude-watch not installed)"` and rely on the Step 2 transcript.

**Cover / hook image (instructional template only):** if `COVER_URL` is non-empty, download it:
```bash
if [[ -n "$COVER_URL" ]]; then
  THUMB_TMP="/tmp/kf-watch-thumb-$(echo "$FULL_URL" | md5 | cut -c1-8).jpg"
  curl -sL "$COVER_URL" -o "$THUMB_TMP" && echo "THUMB_TMP=$THUMB_TMP"
fi
```
Then use the **Read tool** on `$THUMB_TMP` and describe it for `{{HOOK_ANALYSIS}}`.
If `COVER_URL` is empty, **skip** the thumbnail step entirely — do not curl an empty URL, and base
`{{HOOK_ANALYSIS}}` on the opening transcript lines instead.

---

## Step 5 — Read the Chosen Template

```bash
KFCLI_TEMPLATES=$(find "$HOME/.claude/plugins" -maxdepth 6 \
  -path "*/kf-cli/templates" -type d 2>/dev/null | head -1)
# meeting → meeting-note-template.md ; instructional → watch-note-template.md
cat "$KFCLI_TEMPLATES/watch-note-template.md"      # or meeting-note-template.md
```

---

## Step 6 — Fill Every Placeholder

Replace ALL `{{PLACEHOLDER}}` values. Never leave any placeholder unfilled.

### Shared placeholders (both templates)

| Placeholder | How to fill |
|-------------|-------------|
| `{{TITLE}}` | From yt-dlp metadata |
| `{{VIDEO_URL}}` | Full URL to the video (`$FULL_URL`) |
| `{{COVER_URL}}` | `$COVER_URL` — **if empty, leave the value blank** (do not invent one) |
| `{{PLATFORM}}` | `youtube` / `vimeo` / `loom` / `zoom` / etc. (from Step 1) |
| `{{DATE}}` | Today's date YYYY-MM-DD |
| `{{VIDEO_DATE}}` | Upload/recording date YYYY-MM-DD (`$VIDEO_DATE`) |
| `{{CHANNEL}}` | Channel (instructional) or host/organizer (meeting) |
| `{{DURATION}}` | Human format (e.g. `36:56`) |
| `{{PRIORITY}}` | high / medium / low — assess from relevance to current context |
| `{{WATCH_MODE}}` | From Step 4 |
| `{{TOPIC_TAGS}}` | 2-4 tags from the SKILL.md taxonomy, comma-separated |
| `{{METADATA_TAGS}}` | 1-2 tags: tutorial, deep-dive, technical, actionable, conceptual, inspiration |
| `{{DESCRIPTION}}` | 2-3 sentences: what this covers and who it's for |
| `{{TOPIC_ANALYSIS}}` | Why these topic tags were chosen |
| `{{PRIORITY_REASONING}}` | Why this priority |
| `{{TAG_REASONING}}` | Why these specific tags |
| `{{PRIMARY_TOPIC}}` | Single most relevant topic tag |
| `{{CONNECTIONS}}` | Wikilinks to related notes: `[[wiki/topic/topic|Description]]` |

**Cover degradation:** if `COVER_URL` is empty, replace the instructional template's
`[![Watch Video]({{COVER_URL}})]({{VIDEO_URL}})` line with a plain `🎥 [Watch Video]({{VIDEO_URL}})`
link, and leave the `cover:` frontmatter value blank. (The meeting template already uses a plain
link, so no change needed there.)

### Instructional template only (`watch-note-template.md`)

| Placeholder | How to fill |
|-------------|-------------|
| `{{HOOK_ANALYSIS}}` | What the thumbnail communicates + the first 10s of transcript. If frames available, describe them. Include hook strategy (in-media-res / problem-first / story). If no cover and transcript-only, base it on the opening lines. |
| `{{LEARNING_OBJECTIVES}}` | Bullets: "- Understand X", "- Apply Y" — things a learner can DO after watching |
| `{{CURRICULUM}}` | Timestamped table with **clickable links**. YouTube: `[MM:SS](https://www.youtube.com/watch?v=VIDEO_ID&t=Xs)`. Other platforms: deep-link if supported, else plain `[MM:SS]`. Mark visual-heavy moments with 👁️ if frames available |
| `{{VISUAL_OBSERVATIONS}}` | Visual mode: specifics from reading frames. Transcript-only: `*Note: visual analysis unavailable — {{WATCH_MODE}}.*` |
| `{{CORE_CONCEPTS}}` | 3-6 concepts: `**Concept**: one-line explanation` |
| `{{KEY_INSIGHTS}}` | 3-5 bullets: most important takeaways |
| `{{BEFORE_AFTER}}` | 2-3 rows: `**Before**: [gap] → **After**: [understanding]` |
| `{{OPEN_QUESTIONS}}` | 2-4 questions the video raised but didn't answer |
| `{{SELF_TEST}}` | 3-5 Q&A pairs: `**Q:** …\n**A:** …` |
| `{{ACTION_CHECKLIST}}` | `- [ ] specific action` based on the video |
| `{{TARGET_AUDIENCE}}` | Who gets the most value |
| `{{COMPLEXITY_LEVEL}}` | quick-read / tutorial / deep-dive |
| `{{RELATED_SEARCHES}}` | 3-5 bullets: related topics/creators/concepts |

### Meeting template only (`meeting-note-template.md`)

| Placeholder | How to fill |
|-------------|-------------|
| `{{PARTICIPANTS}}` | Bullet list of speakers/attendees inferred from the transcript (speaker labels) and metadata. If unknown, note "Speakers not labelled in transcript." |
| `{{TOPICS_DISCUSSED}}` | Bullet list of the main subjects covered |
| `{{KEY_DECISIONS}}` | Bullet list of decisions reached. If none, "No explicit decisions recorded." |
| `{{ACTION_ITEMS}}` | Checkbox list `- [ ] Owner — action — (due)`. Extract concrete commitments. If none, "No explicit action items." |
| `{{TIMELINE}}` | Timestamped table of how the conversation progressed. YouTube-style deep links only if the platform supports `#t=Xs`; otherwise plain `[MM:SS]` |
| `{{NOTABLE_MOMENTS}}` | 2-5 key quotes/turning points with timestamps |
| `{{OPEN_QUESTIONS}}` | Unresolved questions and follow-ups |

> The transcript may be in any language (Zoom transcribes in the meeting language). Write the note's
> analysis in the same language as the transcript unless the user asked otherwise, and preserve
> speaker names verbatim.

---

## Step 7 — Save the Note

**Filename format**: `YYYY-MM-DD-channel-or-host-descriptive-title.md`
(slugify: lowercase, hyphens for spaces, strip punctuation, max ~60 chars)

```bash
VAULT="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
FILEPATH="$VAULT/notes/YYYY-MM-DD-host-descriptive-title.md"
```

Use the Write tool to save the completed note to `$FILEPATH`.

---

## Step 8 — Index the Note

```bash
SCRIPT=$(find "$HOME/.claude/plugins" \
  -path "*/kf-cli/hooks/scripts/index-note.sh" 2>/dev/null | head -1)
[[ -n "$SCRIPT" ]] && bash "$SCRIPT" "$FILEPATH"
```

Replace `$FILEPATH` with the actual absolute path used in Step 7.
