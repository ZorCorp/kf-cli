---
description: Smart capture router - delegates to specialized handlers based on content type (any video URL → /watch, GitHub → /gitingest, articles → /article|/study-guide, text → /idea)
argument-hint: [content to capture]
allowed-tools:
  - SlashCommand(*)
  - Bash(*)
---

## Task

Route content to the appropriate capture handler based on content type.

**Input**: `$ARGUMENTS`

## Content Routing

Analyze the input and delegate to the appropriate command. **Check patterns in this exact order**:

| Priority | Content Type | Pattern | Delegate To |
|----------|--------------|---------|-------------|
| 1 | **Video (known platform)** | Domain is `youtube.com`, `youtu.be`, `loom.com`, `vimeo.com`, `tiktok.com`, `twitch.tv`, `zoom.us`/`*.zoom.us`, `*.zoom.com` | `/kf-cli:watch` |
| 2 | **GitHub** | Domain is `github.com` | `/kf-cli:gitingest` |
| 3 | **Video (probe)** | Any other `http(s)` URL that the yt-dlp probe (below) identifies as a video | `/kf-cli:watch` |
| 4 | **Long Article** | Input length > 1000 chars OR contains keywords like "article", "blog", "comprehensive" | `/kf-cli:article` |
| 5 | **Web Article** | Any remaining `http://` / `https://` URL | `/kf-cli:study-guide` |
| 6 | **Plain Text** | No URL pattern | `/kf-cli:idea` |

## Routing Logic

### 1. Video URLs — known platforms (fast path, no probe)
**Pattern**: URL host is `youtube.com`, `youtu.be`, `loom.com`, `vimeo.com`, `tiktok.com`, `twitch.tv`, or any `zoom.us` / `zoom.com` host.

```
SlashCommand("/kf-cli:watch $ARGUMENTS")
```

### 2. GitHub URLs
**Pattern**: URL host is `github.com`

```
SlashCommand("/kf-cli:gitingest $ARGUMENTS")
```

### 3. Video URLs — unknown host (yt-dlp probe fallback)
**Pattern**: the input contains an `http(s)` URL that did NOT match steps 1-2.

Run a fast simulate-only probe to see whether yt-dlp recognises it as a video. This is what makes
the router handle **any** public/shareable video URL, not just a hardcoded list:

```bash
URL=$(echo "$ARGUMENTS" | grep -oE 'https?://[^ ]+' | head -1)
if [[ -n "$URL" ]]; then
  if yt-dlp --simulate --quiet --no-warnings --playlist-items 1 "$URL" >/dev/null 2>&1; then
    echo "IS_VIDEO=yes"
  else
    echo "IS_VIDEO=no"
  fi
fi
```

- If `IS_VIDEO=yes` → delegate to watch:
  ```
  SlashCommand("/kf-cli:watch $ARGUMENTS")
  ```
- If `IS_VIDEO=no` → continue to step 4/5 (article handling).

> The probe only runs for URLs that miss the fast-path list, so common platforms stay instant and
> only genuinely unknown URLs pay the ~2-5s probe cost. yt-dlp returns non-zero for non-video pages,
> login-gated content, and unshared/passcode recordings — all of which correctly fall through to
> article handling.

### 4. Long Articles
**Pattern**: Input length > 1000 chars OR contains keywords like "article", "blog", "comprehensive"

```
SlashCommand("/kf-cli:article $ARGUMENTS")
```

### 5. Web Articles
**Pattern**: Any remaining `http://` / `https://` URL (not video, not GitHub)

```
SlashCommand("/kf-cli:study-guide $ARGUMENTS")
```

### 6. Plain Text (Ideas)
**Pattern**: No URL detected

```
SlashCommand("/kf-cli:idea $ARGUMENTS")
```

## Examples

```
/kf-cli:capture https://youtube.com/watch?v=abc123
→ step 1 (known) → /kf-cli:watch https://youtube.com/watch?v=abc123

/kf-cli:capture https://hkmci.zoom.us/rec/share/AbC123...
→ step 1 (zoom.us) → /kf-cli:watch https://hkmci.zoom.us/rec/share/AbC123...

/kf-cli:capture https://some-lms.example.com/lesson/42/video
→ step 1-2 miss → step 3 probe IS_VIDEO=yes → /kf-cli:watch ...

/kf-cli:capture https://github.com/anthropics/claude-code
→ step 2 → /kf-cli:gitingest https://github.com/anthropics/claude-code

/kf-cli:capture https://medium.com/article-about-ai
→ step 3 probe IS_VIDEO=no → step 5 → /kf-cli:study-guide ...

/kf-cli:capture Build a browser extension for note capture
→ step 6 → /kf-cli:idea Build a browser extension for note capture
```

## Important

- This command is a **router only** — it does NOT process content directly.
- Each handler (`/kf-cli:watch`, `/kf-cli:gitingest`, `/kf-cli:study-guide`, `/kf-cli:article`, `/kf-cli:idea`) has its own template and logic.
- Run the probe only when steps 1-2 miss; delegate immediately once the type is known.
- Always use `/kf-cli:` prefixed commands to ensure plugin templates are used.
