#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEBHOOK_URL="${WEBHOOK_URL:-http://127.0.0.1:8000/api/webhooks/stripe}"
PYTHON_BIN="${SCRIPT_DIR}/.venv/bin/python"

if [[ -z "${STRIPE_WEBHOOK_SECRET:-}" && -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

if [[ -z "${STRIPE_WEBHOOK_SECRET:-}" ]]; then
  echo "ERROR: STRIPE_WEBHOOK_SECRET is not set." >&2
  exit 1
fi

sign_payload() {
  local ts="$1"
  local body="$2"
  TS="$ts" BODY="$body" "$PYTHON_BIN" - <<'PY'
import hashlib, hmac, os
ts = os.environ["TS"]
body = os.environ["BODY"]
secret = os.environ["STRIPE_WEBHOOK_SECRET"].encode("utf-8")
msg = f"{ts}.{body}".encode("utf-8")
print(hmac.new(secret, msg, hashlib.sha256).hexdigest())
PY
}

assert_status() {
  local label="$1"
  local expected="$2"
  shift 2
  local output
  output="$("$@")"
  local code="${output##*$'\n'}"
  local body="${output%$'\n'*}"
  echo "=== ${label} ==="
  echo "HTTP ${code}: ${body}"
  if [[ "$code" != "$expected" ]]; then
    echo "FAIL: expected HTTP ${expected}, got ${code}" >&2
    exit 1
  fi
}

ORIG_BODY='{"id":"evt_test_negative","type":"payment_intent.succeeded","data":{"object":{"id":"pi_test","metadata":{"order_id":"ORD-FAKE"}}}}'
TAMPERED_BODY='{"id":"evt_test_negative","type":"payment_intent.succeeded","data":{"object":{"id":"pi_tampered","metadata":{"order_id":"ORD-FAKE"}}}}'

NOW_TS="$(date +%s)"
VALID_SIG="$(sign_payload "$NOW_TS" "$ORIG_BODY")"
MODIFIED_SIG="0000${VALID_SIG:4}"

OLD_TS="$((NOW_TS - 600))"
OLD_SIG="$(sign_payload "$OLD_TS" "$ORIG_BODY")"

# 1. Missing Stripe-Signature header
assert_status "1. Missing Stripe-Signature header" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$ORIG_BODY"

# 2. Forged / tampered request body (signed for ORIG_BODY, sent with TAMPERED_BODY)
assert_status "2. Forged / tampered body" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${NOW_TS},v1=${VALID_SIG}" \
  -d "$TAMPERED_BODY"

# 3. Modified signature
assert_status "3. Modified Stripe-Signature" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${NOW_TS},v1=${MODIFIED_SIG}" \
  -d "$ORIG_BODY"

# 4. Stale timestamp (>300s tolerance)
assert_status "4. Stale timestamp (t - 600s)" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${OLD_TS},v1=${OLD_SIG}" \
  -d "$ORIG_BODY"

echo "All negative webhook signature tests returned HTTP 400."
