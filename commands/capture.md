---
description: Smart capture router - delegates to specialized handlers based on content type
argument-hint: [content to capture]
allowed-tools:
  - SlashCommand(*)
---

## Task

Route content to the appropriate capture handler based on content type.

**Input**: `$ARGUMENTS`

## Content Routing

Analyze the input and delegate to the appropriate command. **Check patterns in this exact order**:

| Priority | Content Type | Pattern | Delegate To |
|----------|--------------|---------|-------------|
| 1 | **YouTube** | Domain is `youtube.com` or `youtu.be` | `/kf-cli:watch` |
| 2 | **GitHub** | Domain is `github.com` | `/kf-cli:gitingest` |
| 3 | **Long Article** | Input length > 1000 chars OR contains keywords like "article", "blog", "comprehensive" | `/kf-cli:article` |
| 4 | **Web Article** | Other `http://` or `https://` URL | `/kf-cli:study-guide` |
| 5 | **Plain Text** | No URL pattern | `/kf-cli:idea` |

## Routing Logic

### 1. YouTube URLs
**Pattern**: URL contains `youtube.com` or `youtu.be`

```
SlashCommand("/kf-cli:watch $ARGUMENTS")
```

### 2. GitHub URLs
**Pattern**: URL contains `github.com`

```
SlashCommand("/kf-cli:gitingest $ARGUMENTS")
```

### 3. Long Articles
**Pattern**: Input length > 1000 chars OR contains keywords like "article", "blog", "comprehensive"

```
SlashCommand("/kf-cli:article $ARGUMENTS")
```

### 4. Web Articles
**Pattern**: Starts with `http://` or `https://` (not YouTube or GitHub)

```
SlashCommand("/kf-cli:study-guide $ARGUMENTS")
```

### 5. Plain Text (Ideas)
**Pattern**: No URL detected

```
SlashCommand("/kf-cli:idea $ARGUMENTS")
```

## Examples

```
/kf-cli:capture https://youtube.com/watch?v=abc123
→ Delegates to: /kf-cli:watch https://youtube.com/watch?v=abc123

/kf-cli:capture https://github.com/anthropics/claude-code
→ Delegates to: /kf-cli:gitingest https://github.com/anthropics/claude-code

/kf-cli:capture [long content about scambaiting strategy, 2000 chars]
→ Delegates to: /kf-cli:article [content]

/kf-cli:capture https://medium.com/article-about-ai
→ Delegates to: /kf-cli:study-guide https://medium.com/article-about-ai

/kf-cli:capture Build a browser extension for note capture
→ Delegates to: /kf-cli:idea Build a browser extension for note capture
```

## Important

- This command is a **router only** - it does NOT process content directly
- Each handler (`/kf-cli:watch`, `/kf-cli:youtube-note`, `/kf-cli:gitingest`, `/kf-cli:study-guide`, `/kf-cli:idea`) has its own template and logic
- After detecting content type, immediately delegate using `SlashCommand`
- Always use `/kf-cli:` prefixed commands to ensure plugin templates are used
