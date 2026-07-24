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

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
