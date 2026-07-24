#!/bin/bash
# Tier A shell tests for quartz-publish.sh — run against a TEMP git repo, never live.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PUBLISH="$HERE/../scripts/core/quartz-publish.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# ── Fixture: a temp vault + a temp bare-ish quartz repo ────────────────────────
setup() {
    VAULT=$(mktemp -d); GARDEN=$(mktemp -d)
    mkdir -p "$VAULT/.claude" "$VAULT/notes/trip" "$GARDEN/content"
    git -C "$GARDEN" init -q
    git -C "$GARDEN" config user.email t@t.t; git -C "$GARDEN" config user.name t
    git -C "$GARDEN" checkout -q -b v5
    printf 'configuration:\n  baseUrl: example.test\n' > "$GARDEN/quartz.config.yaml"
    git -C "$GARDEN" add -A; git -C "$GARDEN" commit -qm init
    cat > "$VAULT/.claude/config.local.json" <<EOF
{"vault_path":"$VAULT","quartz_url":"https://example.test","quartz_repo":"$GARDEN"}
EOF
}
teardown() { rm -rf "$VAULT" "$GARDEN"; }

# ── Test 1: access: private is refused (exit 1, offender listed) ───────────────
setup
printf -- '---\naccess: private\ntitle: secret\n---\nhi\n' > "$VAULT/notes/trip/secret.md"
OUT=$(bash "$PUBLISH" "notes/trip/secret.md" "$VAULT" --yes 2>&1); RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "secret.md"; then
    ok "access: private refused with offender listed"
else
    no "access: private NOT refused (rc=$RC)"; echo "$OUT" | sed 's/^/     /'
fi
teardown

# ── Test 2: config-driven path resolution (copies into CONFIGURED repo) ────────
setup
printf -- '---\ntitle: hello\n---\n# hi\n' > "$VAULT/notes/trip/hello.md"
# Neuter network: stub verify by pointing quartz-verify at an unreachable host is fine;
# we only assert the file landed in the configured GARDEN before push/verify.
bash "$PUBLISH" "notes/trip/hello.md" "$VAULT" --yes >/dev/null 2>&1
if [[ -f "$GARDEN/content/notes/trip/hello.md" ]]; then
    ok "note copied into configured quartz_repo (no hardcoded path)"
else
    no "note NOT found in configured repo — path resolution broken"
fi
teardown

# ── Test 3: html publish lands raw file + indexed stub with correct paths ──────
setup
cat > "$VAULT/notes/trip/deck.html" <<'HTML'
<html><head><title>My CityU Deck</title></head><body><h1>slides</h1></body></html>
HTML
bash "$PUBLISH" "notes/trip/deck.html" "$VAULT" --yes >/dev/null 2>&1
# raw html now lands in the garden STATIC dir (served as text/html), NOT content/
RAW="$GARDEN/quartz/static/embeds/notes/trip/deck.html"
STUB="$GARDEN/content/notes/trip/deck-embed.md"
if [[ -f "$RAW" ]] && diff -q "$VAULT/notes/trip/deck.html" "$RAW" >/dev/null; then
    ok "raw html copied byte-identical into quartz/static/embeds (notes/ layer preserved)"
else
    no "raw html missing or altered in static dir"
fi
if [[ -f "$STUB" ]] \
   && grep -q 'tags: \[html-embed\]' "$STUB" \
   && grep -q 'title: "My CityU Deck"' "$STUB" \
   && grep -q '(/static/embeds/notes/trip/deck.html)' "$STUB" \
   && grep -q '<iframe src="/static/embeds/notes/trip/deck.html"' "$STUB"; then
    ok "indexed stub generated with title, tag, and /static/ iframe+link path"
else
    no "stub missing or malformed"; [[ -f "$STUB" ]] && sed 's/^/     /' "$STUB"
fi
# raw html must NOT be in content/ (that route serves octet-stream) and the stub
# must not claim a bare deck.md route
if [[ ! -f "$GARDEN/content/notes/trip/deck.html" ]] && [[ ! -f "$GARDEN/content/notes/trip/deck.md" ]]; then
    ok "no content-side html/deck.md (raw html served only from /static/)"
else
    no "unexpected content-side deck.html or deck.md"
fi
teardown

# ── Test 4: --dry-run lists md + html + stub, changes nothing, exits 0 ─────────
setup
printf -- '---\ntitle: hi\n---\n# hi\n' > "$VAULT/notes/trip/hello.md"
cat > "$VAULT/notes/trip/deck.html" <<'HTML'
<html><head><title>Deck</title></head><body>x</body></html>
HTML
OUT=$(bash "$PUBLISH" "notes/trip/" "$VAULT" --dry-run 2>&1); RC=$?
if [[ $RC -eq 0 ]] \
   && echo "$OUT" | grep -q 'md   → content/notes/trip/hello.md' \
   && echo "$OUT" | grep -q 'html → quartz/static/embeds/notes/trip/deck.html' \
   && echo "$OUT" | grep -q 'stub → content/notes/trip/deck-embed.md' \
   && echo "$OUT" | grep -q 'DRY_RUN=yes'; then
    ok "--dry-run lists md + static html + generated stub"
else
    no "--dry-run output incomplete (rc=$RC)"; echo "$OUT" | sed 's/^/     /'
fi
# dry-run must NOT copy anything (content + static) or add a commit
COMMITS=$(git -C "$GARDEN" rev-list --count HEAD)
if [[ -z "$(ls -A "$GARDEN/content")" ]] && [[ ! -d "$GARDEN/quartz/static/embeds" ]] && [[ "$COMMITS" == "1" ]]; then
    ok "--dry-run made no changes (no content, no static embeds, no new commit)"
else
    no "--dry-run mutated the garden (content/static/commits changed)"
fi
teardown

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
