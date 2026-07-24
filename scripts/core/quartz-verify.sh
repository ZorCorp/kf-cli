#!/bin/bash
# Poll-verify a Quartz page is live (HTTP 200). Extensionless, CJK percent-encoded.
# Usage: quartz-verify.sh <url-path-after-domain> [VAULT_PATH]
#   e.g. quartz-verify.sh "notes/內蒙古之旅/00-行程總覽"
set -e
URL_PATH="$1"
VAULT_PATH="${2:-$(pwd)}"

CONFIG_FILE="$VAULT_PATH/.claude/config.local.json"
QUARTZ_URL=""
[[ -f "$CONFIG_FILE" ]] && QUARTZ_URL=$(jq -r '.quartz_url // empty' "$CONFIG_FILE")
if [[ -z "$QUARTZ_URL" ]]; then
    echo "❌ quartz_url not set — run /kf-cli:setup"
    exit 1
fi

# Percent-encode the path (keep slashes)
ENC=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe='/'))" "$URL_PATH")
FULL_URL="$QUARTZ_URL/$ENC"

echo "🔍 Verifying: $FULL_URL"
MAX_RETRIES=48   # 48 * 5s = 4 min (Actions build 1.5–3 min)
RETRY_DELAY=5
for ((i=1; i<=MAX_RETRIES; i++)); do
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" -L "$FULL_URL" 2>/dev/null || echo "000")
    if [[ "$HTTP" == "200" ]]; then
        echo "✅ Live (HTTP 200)"
        echo "VERIFIED_URL=$FULL_URL"
        exit 0
    fi
    echo "  Attempt $i/$MAX_RETRIES — HTTP $HTTP (waiting ${RETRY_DELAY}s)"
    sleep "$RETRY_DELAY"
done
echo "⚠️  Not reachable after $((MAX_RETRIES*RETRY_DELAY))s (Actions may still be building)"
echo "UNVERIFIED_URL=$FULL_URL"
exit 0
