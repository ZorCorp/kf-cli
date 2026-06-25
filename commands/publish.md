---
description: Publish note to GitHub Pages (sharehub) with proper image handling
argument-hint: [filename] (note to publish, e.g., my-article.md)
allowed-tools:
  - Bash(*)
  - Read(*)
  - Task(*)
---

## Task

Publish note to GitHub Pages using a dedicated publish agent.

**Input**: `$ARGUMENTS` (filename with or without .md extension)

## Implementation

**IMPORTANT: Always spawn an agent for this task.**

Use the Task tool with these exact parameters:

```
Task tool call:
  subagent_type: "general-purpose"
  description: "Publish note to sharehub"
  prompt: |
    Publish the note "$ARGUMENTS" to GitHub Pages.

    Run this command (locate the script dynamically — the plugin may live under a marketplace):
    ```bash
    PUBLISH_SCRIPT=$(find "$HOME/.claude/plugins" -maxdepth 7 -path "*/kf-cli/scripts/core/publish.sh" 2>/dev/null | head -1)
    VAULT_PATH="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
    bash "$PUBLISH_SCRIPT" "$ARGUMENTS" "$VAULT_PATH"
    ```

    After the script completes, check the output:

    **Look for these key lines in the output:**
    - `VERIFIED_URL=<url>` → All checks passed (HTTP 200, HTML rendered, images OK)
    - `UNVERIFIED_URL=<url>` → Published but verification failed (broken images, etc.)

    **If VERIFIED_URL found:**
    - Report: "✅ Published and verified: <VERIFIED_URL>"
    - This URL is confirmed live, HTML-rendered, with all images working

    **If UNVERIFIED_URL found:**
    - Report the specific errors from the verification output
    - Include the URL but note it has issues

    **If neither found (script failed):**
    - Look for error messages starting with "❌" or "⚠️"
    - Report the specific issue
    - Common issues:
      • "Jekyll conversion failed" → HTML not generated, check Jekyll config
      • "Image not accessible" → image not uploaded or wrong path
      • "Page not yet reachable" → wait 60s and rerun the script

    **If script times out (>2 minutes):**
    - Report: "⚠️ Publish script timeout - GitHub Pages may be slow"
    - Tell user to verify manually in 2-3 minutes

    Return: Concise summary with the VERIFIED_URL (1-2 sentences max). The URL MUST be included in your response.
```

## Examples

```
/kf-cli:publish my-article.md
/kf-cli:publish KFE/KF-MIGRATION-CHECKLIST.md
```

## Password Protection

Add `access: private` to a note's frontmatter to mark it as password-protected. The password itself is **not** configured in this command or the kf-cli source — it lives in your sharehub repo's site config (e.g. `_config.yml` or equivalent), so only you and your deployment control it. See your sharehub repo's access-control docs for the specific field.
