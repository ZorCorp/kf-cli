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

**IMPORTANT: Always spawn an agent for this task.**

Use the Task tool with these exact parameters:

```
Task tool call:
  subagent_type: "general-purpose"
  description: "Publish to Quartz garden"
  prompt: |
    Publish "$ARGUMENTS" to the Quartz digital garden.

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

## Examples

```
/kf-cli:quartz notes/內蒙古之旅/00-行程總覽.md
/kf-cli:quartz 內蒙古之旅/
/kf-cli:quartz notes/2026-06-15-deck.html
```

## Notes

- **Folder publish** copies every top-level `.md` + `.html` in the folder (non-recursive), preserving the `notes/<folder>/` layer inside the garden's `content/`.
- **Bake pass** renders `dataview TABLE`/`TASK` and `mapview` blocks; anything it cannot parse is left untouched (best-effort). Mermaid is left to Quartz's native renderer.
- **HTML** is copied byte-identical and served at its extensionless URL. Raw `.html` renders on direct page load.
- **Leaflet + SPA:** baked maps load Leaflet from a CDN and render on direct load / refresh. With Quartz's `enableSPA`, the inline `<script>` may not re-run on in-site (client-side) navigation — refresh the page if a map appears blank after navigating to it.
