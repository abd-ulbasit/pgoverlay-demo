#!/usr/bin/env bash
# Brings up a fresh public TCP tunnel to the local pgoverlay proxy and rewires
# everything that depends on the (random, per-session) tunnel address:
#   - GitHub Actions repo variable PGOVERLAY_PROXY_HOST (pr-db-check workflow)
#   - Vercel env vars PGOVERLAY_HOST / PGOVERLAY_PORT   (preview + production)
#   - redeploys the latest preview & production so they pick the new address
#
# Free pinggy tunnels last 60 minutes — rerun this when the tunnel dies.
# Requires: gh (authed), node, vercel CLI (linked: .vercel/project.json).
set -euo pipefail
cd "$(dirname "$0")/.."

PROXY_PORT="${PROXY_PORT:-6432}"
LOG="$(mktemp)"

# accept-new: trust pinggy's host key the first time and refuse a changed one
# afterwards (StrictHostKeyChecking=no accepted any key, so anyone in the path
# could have taken the tunnel, and the database connections in it).
ssh -T -p 443 -R0:localhost:"$PROXY_PORT" \
    -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 \
    -o ExitOnForwardFailure=yes tcp@a.pinggy.io >"$LOG" 2>&1 &
TUNNEL_PID=$!
trap 'kill $TUNNEL_PID 2>/dev/null || true' EXIT

ADDR=""
for _ in $(seq 1 30); do
    ADDR="$(grep -o 'tcp://[^[:space:]]*' "$LOG" | head -1 | sed 's|tcp://||' | tr -d '\r' || true)"
    [ -n "$ADDR" ] && break
    sleep 1
done
[ -n "$ADDR" ] || { echo "tunnel address never appeared:"; cat "$LOG"; exit 1; }
HOST="${ADDR%%:*}" PORT="${ADDR##*:}"
echo "tunnel up: $ADDR (pid $TUNNEL_PID)"

gh variable set PGOVERLAY_PROXY_HOST --body "$ADDR"
echo "github var PGOVERLAY_PROXY_HOST=$ADDR"

node scripts/vercel-env-upsert.js "PGOVERLAY_HOST=$HOST" "PGOVERLAY_PORT=$PORT" |
while read -r env url; do
    echo "redeploying $env ($url)"
    vercel redeploy "$url" >/dev/null 2>&1 || echo "  redeploy failed for $url (do it manually)"
done

echo "rewired. tunnel stays up in the foreground; Ctrl-C (or 60-min expiry) kills it."
wait "$TUNNEL_PID"
