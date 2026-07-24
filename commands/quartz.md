---
description: Publish note/folder to a Quartz digital garden (dataview/mapview baked to static)
argument-hint: [note.md | folder/ | file.html] (single note, whole folder, or raw HTML)
allowed-tools:
  - Bash(*)
  - Read(*)
  - Task(*)
---

## Task

Publish an Obsidian note, a whole folder, or a raw HTML file to the Quartz digital garden configured by `/kf-cli:setup`. The garden is PUBLIC — the script prints exactly what will be published and refuses any note marked `access: private`. `dataview`/`mapview` blocks are baked to static markdown/HTML on the published copy (the vault original is never modified).

**Input**: `$ARGUMENTS` (a note filename, a folder, or a `.html` file)

## Implementation

The garden is **PUBLIC**. Never push to it without an explicit user confirmation. This command runs a two-step gate: **(1)** show exactly what would go public, **(2)** publish only after the user says yes.

### Step 1 — Dry-run and show the user what will publish (DO THIS FIRST, yourself)

Run the dry-run directly (do NOT spawn an agent for this step). `--dry-run` resolves and prints the exact file list (md + html + the generated `-embed.md` index stubs), makes NO changes, and exits 0:

```bash
QUARTZ_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 8 -path "*/kf-cli/scripts/core/quartz-publish.sh" 2>/dev/null | head -1)
VAULT_PATH="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
bash "$QUARTZ_SCRIPT" "$ARGUMENTS" "$VAULT_PATH" --dry-run
```

Then, in your reply to the user:
- If the output is `❌ quartz_repo / quartz_url not configured` → tell them to run `/kf-cli:setup` to add a garden, and STOP.
- If it is `🚫 Refusing to publish` (a note is `access: private`) → report which note(s), and STOP. Do NOT retry.
- Otherwise → show the user the exact file list from the dry-run and ask, clearly:
  **"This will publish the above to your PUBLIC Quartz garden (`<quartz_url>`). Publish now? (yes/no)"**
  Then STOP and wait for the user's answer. Do not proceed on your own.

### Step 2 — Publish only after the user confirms

Only if the user replies yes/confirm, spawn the publish agent. If they decline, do nothing further.

```
Task tool call:
  subagent_type: "general-purpose"
  description: "Publish to Quartz garden"
  prompt: |
    The user has already confirmed publishing "$ARGUMENTS" to the PUBLIC Quartz garden.

    Run this command (locate the script dynamically — the plugin may live under a marketplace or a submodule):
    ```bash
    QUARTZ_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 8 -path "*/kf-cli/scripts/core/quartz-publish.sh" 2>/dev/null | head -1)
    VAULT_PATH="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
    bash "$QUARTZ_SCRIPT" "$ARGUMENTS" "$VAULT_PATH" --yes
    ```

    After the script completes, inspect the output:
    - `VERIFIED_URL=<url>` → live and HTTP 200. Report: "✅ Published and verified: <url>"
    - `UNVERIFIED_URL=<url>` → pushed but not yet reachable (Actions still building). Report the URL and say to recheck in ~2 min.
    - `🚫 Refusing to publish` → one or more notes are `access: private`. Report which ones; do NOT retry.
    - `❌ quartz_repo / quartz_url not configured` → tell the user to run `/kf-cli:setup` to add a garden.

    Return: a concise 1–2 sentence summary. The URL MUST be included.
```

The `--yes` in Step 2 is safe because the human gate already happened in Step 1. (The script's own `read -p` prompt remains a fallback for anyone running it directly in a terminal.)

## Examples

```
/kf-cli:quartz notes/內蒙古之旅/00-行程總覽.md
/kf-cli:quartz 內蒙古之旅/
/kf-cli:quartz notes/2026-06-15-deck.html
```

## Notes

- **Folder publish** copies every top-level `.md` + `.html` in the folder (non-recursive), preserving the `notes/<folder>/` layer inside the garden's `content/`.
- **Bake pass** renders `dataview TABLE`/`TASK` and `mapview` blocks; anything it cannot parse is left untouched (best-effort). Mermaid is left to Quartz's native renderer.
- **HTML** is copied byte-identical, plus an indexed `<base>-embed.md` companion stub (title from `<title>` + `tags: [html-embed]` + a link + an `<iframe>`) so the deck shows up in Explorer/search — raw `.html` alone is absent from the Quartz content index. Index visibility, the title, and the tag always work. Inline rendering (the `<iframe>` preview, and opening the raw URL directly) only works where the host serves the raw html as `text/html`; **on GitHub Pages the extensionless file is served as `application/octet-stream`, so it downloads instead of rendering** — the stub still makes the deck findable and titled on the index.
- **Leaflet + SPA:** baked maps load Leaflet from a CDN and render on direct load / refresh. With Quartz's `enableSPA`, the inline `<script>` may not re-run on in-site (client-side) navigation — refresh the page if a map appears blank after navigating to it.
