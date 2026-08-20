---
description: Turn a captured note (+ its source transcript) into a compliant, validated Claude agent skill bundled inside the kf-cli plugin under skills/<slug>/. Continues after /capture — grills you for the skill spec, drives book-to-skill to author it, then validates and security-scans it.
argument-hint: [note.md | video-url] [optional intent, e.g. "advisor for X"]
allowed-tools:
  - Bash(*)
  - Read(*)
  - Write(*)
  - Task(*)
  - SlashCommand(*)
---

## Task

Convert a captured note into a **compliant agent skill** and bundle it inside the kf-cli plugin at
`skills/<slug>/`. This is the step *after* `/kf-cli:capture` in the pipeline:

> `/kf-cli:capture` → (watch + enrich the note) → **`/kf-cli:skillify`**

**skillify is a bridge, not a generator.** It orchestrates; the unchanged **book-to-skill** skill is
the authoring engine. The four phases: gather full context → grill for the spec → drive book-to-skill
→ land the skill in the plugin.

**House rule:** generated skills live **in a plugin only** — never `~/.claude/skills/`. They are
written into the kf-cli source repo under `skills/<slug>/` and ship via kf-cli's release flow.

**Prerequisite:** the `book-to-skill` skill must be installed (`~/.agents/skills/book-to-skill` or a
plugin skills root). If missing, stop and tell the user to install it
(`git clone https://github.com/virgiliojr94/book-to-skill.git ~/.agents/skills/book-to-skill`).

**Input**: `$ARGUMENTS` — a note filename (in the vault `notes/`), a full path, or a video URL.

---

## Step 0 — Resolve input and assemble full context

```bash
ARGS="$ARGUMENTS"
VAULT="${KF_VAULT_PATH:-$HOME/Documents/Obsidian/myrag}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kf-skillify-XXXX")"
SRC="$WORK/source"; mkdir -p "$SRC"

FIRST=$(echo "$ARGS" | awk '{print $1}')
URL=$(echo "$ARGS" | grep -oE 'https?://[^ ]+' | head -1)

if [[ -n "$URL" ]]; then
  # A raw URL was passed — capture it first, then skillify the resulting note.
  echo "NEEDS_CAPTURE=1 URL=$URL"
  # (Handled below: run /kf-cli:watch, then set NOTE to the new note.)
else
  # A note file was passed.
  NOTE="$FIRST"; [[ "$NOTE" != *.md ]] && NOTE="$NOTE.md"
  [[ -f "$NOTE" ]] || NOTE="$VAULT/notes/$(basename "$NOTE")"
  [[ -f "$NOTE" ]] || { echo "ERROR: note not found: $FIRST"; exit 1; }
  echo "NOTE=$NOTE"
fi
echo "WORK=$WORK"
```

- **If `NEEDS_CAPTURE=1`** — run `SlashCommand("/kf-cli:watch <URL>")` first, then set `NOTE` to the
  note it created in `$VAULT/notes/` (newest matching file), and tell the user to enrich it with their
  own insights before continuing (or proceed if they say so).

- **Re-fetch the source transcript** (full context — the note alone is a distillation). Read the note's
  `url:` frontmatter; if it's a YouTube URL, use the bundled script:

```bash
NOTE_URL=$(awk -F'url:[[:space:]]*' '/^url:/{print $2; exit}' "$NOTE" | tr -d '"'"'"' \r')
cp "$NOTE" "$SRC/note.md"
VIDEO_ID=$(echo "$NOTE_URL" | grep -oE '[?&]v=([^&]+)' | head -1 | cut -d= -f2)
[[ -z "$VIDEO_ID" ]] && VIDEO_ID=$(echo "$NOTE_URL" | grep -oE 'youtu\.be/([^?]+)' | sed 's|.*/||')
if [[ -n "$VIDEO_ID" ]]; then
  TS=$(find "$HOME/.claude/plugins" -maxdepth 7 -path "*/kf-cli/scripts/core/fetch-youtube-transcript.sh" 2>/dev/null | head -1)
  { echo "# Transcript — $NOTE_URL"; echo; bash "$TS" "$VIDEO_ID" 2>/dev/null; } > "$SRC/transcript.md"
fi
ls -la "$SRC"
```

If no transcript is retrievable (no captions / not a video), proceed with `note.md` only and note it.

---

## Step 1 — Grill for the skill spec (human-in-the-loop)

Run a **bounded scoping interview** — read `note.md` + `transcript.md` FIRST, then ask only what you
cannot infer. **One question at a time**, each with a recommended answer. Pin down:

1. **Purpose** — what job does the skill do? (advisor / how-to method / reference catalog / narrower)
2. **Trigger** — when should it auto-activate? (this becomes the `description` "use-when")
3. **Slug** — `lowercase-hyphen` name (recommend one from the title).
4. **Depth & caveats** — point-in-time snapshot? verify-sources note? scope boundaries.

Record the answers as a short **SKILL_SPEC** (slug, description, purpose, scope). These pre-answer
book-to-skill's own questions in Step 2, so it never re-asks.

---

## Step 2 — Generate the skill with book-to-skill

Drive the **book-to-skill** engine on the combined `[note + transcript]`, applying the spec.

```bash
BTS=$(find "$HOME/.agents/skills/book-to-skill" "$HOME/.claude/skills/book-to-skill" -maxdepth 0 -type d 2>/dev/null | head -1)
[[ -z "$BTS" ]] && { echo "ERROR: book-to-skill not installed"; exit 1; }
OUT="$WORK/<slug>"; mkdir -p "$OUT"
# a) extract combined text
python3 "$BTS/scripts/extract.py" "$SRC/note.md" "$SRC/transcript.md" --mode text --install-missing ask 2>&1 | tail -5
```

Then, following book-to-skill's SKILL.md instructions and the SKILL_SPEC, author into `$OUT`:
- `SKILL.md` — **YAML frontmatter** `name: <slug>` + `description: "<use-when from the grill>"`, then the
  structured body fit to the purpose (advisor → Decision Guide; method → steps; reference → catalog).
- `references/` — the source transcript (+ any distilled catalog) as ground truth.

Then run book-to-skill's quality gates and **hard-stop on failure**:

```bash
python3 "$BTS/tools/validate_skill.py" "$OUT/SKILL.md" --lens claude          # must be 0 errors
python3 "$BTS/tools/scan_generated_skill.py" "$OUT"                            # must pass
# Also scan the references (book-to-skill's scanner skips them by default):
for f in "$OUT"/references/*.md; do python3 "$BTS/tools/scan_generated_skill.py" "$f" 2>/dev/null; done
```

If validate reports errors or the scan flags anything, fix and re-run before landing.

---

## Step 3 — Land the skill in the kf-cli plugin

Write the validated skill into the **kf-cli source repo** under `skills/<slug>/` (never
`~/.claude/skills/`). Locate the source repo (maintainer machine); if not found, stop and report.

```bash
KF_SRC="${KF_CLI_SRC:-$HOME/Dev/zorcorp/zorskill/plugins/kf-cli}"
[[ -d "$KF_SRC/.claude-plugin" ]] || { echo "ERROR: kf-cli source repo not found at $KF_SRC (set KF_CLI_SRC)"; exit 1; }
mkdir -p "$KF_SRC/skills"
cp -R "$OUT" "$KF_SRC/skills/<slug>"
echo "LANDED: $KF_SRC/skills/<slug>"
```

Then:
- **Backlink** the source note — append a line to the note pointing at the new skill (`/kf-cli:<slug>`).
- Report the skill path and its invocation name `/kf-cli:<slug>` (auto-discovered — no plugin.json change).
- **Do NOT auto-release.** Tell the user the skill is staged in the kf-cli repo. To ship it, cut a
  release from the kf-cli repo: `gh workflow run release.yml -f version=<x.y.z>` (patch bump for a new
  skill), which the marketplace drift-scanner carries in. Pass `--ship` to offer to run it for them.

---

## Notes

- **Maintainer-oriented:** landing into the kf-cli repo + releasing requires write access to
  `ZorCorp/kf-cli`. That's the intended use (the vault owner maintains kf-cli). A non-maintainer would
  instead point `KF_CLI_SRC` at their own fork/plugin.
- **book-to-skill is the engine** — never reimplement its authoring here; skillify only orchestrates.

## Examples

```
/kf-cli:skillify 2026-08-20-sharbel-a-10-hermes-agent-skills-to-install.md
/kf-cli:skillify notes/my-note.md "make it an install advisor"
/kf-cli:skillify https://youtu.be/XXXX          # captures first, then skillifies
```
