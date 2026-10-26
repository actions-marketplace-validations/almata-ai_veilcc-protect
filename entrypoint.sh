#!/usr/bin/env bash
# VeilCC Protect — GitHub Action entrypoint.
#   mode=api   : POST the object/IR to the hosted Protection API; passes stay
#                server-side. Matches POST {api-url}/api/protect (multipart + JSON),
#                the same contract the `veil` CLI and console use.
#   mode=local : run the VeilCC plugin on this runner (obfuscate only; air-gapped CI).
set -euo pipefail

: "${VEIL_INPUT:?input 'input' is required (an object .o to seal, or IR .ll/.bc to obfuscate)}"
: "${VEIL_LEVEL:=seal}"
: "${VEIL_OUTPUT:=veil-protected.o}"
: "${VEIL_MODE:=api}"
[ -f "$VEIL_INPUT" ] || { echo "::error::input not found: $VEIL_INPUT"; exit 1; }

is_true() { case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in 1|true|yes|on) return 0;; *) return 1;; esac; }

if [ "$VEIL_MODE" = "local" ]; then
  : "${VEIL_PLUGIN:?mode=local needs 'plugin' (path to libVeilPass.so/.dylib)}"
  : "${VEIL_SYMBOLS:?mode=local needs 'symbols' (e.g. my_fn=max)}"
  command -v opt >/dev/null || { echo "::error::LLVM 'opt' not on PATH"; exit 1; }
  command -v llc >/dev/null || { echo "::error::LLVM 'llc' not on PATH"; exit 1; }
  seed="${VEIL_SEED:-0x$(openssl rand -hex 8)}"   # fresh per-build seed unless pinned
  VEIL_BUILD_SEED="$seed" VEIL_FORCE="$VEIL_SYMBOLS" \
    opt -load-pass-plugin="$VEIL_PLUGIN" -passes=veil-pipeline "$VEIL_INPUT" -S -o veil.veiled.ll
  # Strip Apple-only codegen attrs that upstream llc rejects (no-op elsewhere).
  sed -E -e 's/ ?"probe-stack"="[^"]*"//g' -e 's/,\+zc[mz]//g' veil.veiled.ll > veil.clean.ll
  llc -relocation-model=pic -filetype=obj veil.clean.ll -o "$VEIL_OUTPUT"
  echo "veilcc: local protect -> $VEIL_OUTPUT (seed $seed)"
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "protected=$VEIL_OUTPUT" >> "$GITHUB_OUTPUT"
  exit 0
fi

# ── hosted API mode ──────────────────────────────────────────────────────────
: "${VEIL_API_KEY:?mode=api needs 'api-key'}"
: "${VEIL_API_URL:=https://veilcc.com}"

args=(-sS -X POST
  -H "Authorization: Bearer ${VEIL_API_KEY}"
  -F "binary=@${VEIL_INPUT}"
  -F "level=${VEIL_LEVEL}"
  -F "target=${VEIL_TARGET:-auto-detect}")
[ -n "${VEIL_PROTO:-}" ]        && args+=(-F "proto=${VEIL_PROTO}")
[ -n "${VEIL_SYMBOLS:-}" ]      && args+=(-F "symbols=${VEIL_SYMBOLS}")
[ -n "${VEIL_KEY_PROVIDER:-}" ] && args+=(-F "key_provider=${VEIL_KEY_PROVIDER}")
[ -n "${VEIL_SEED:-}" ]         && args+=(-F "seed=${VEIL_SEED}")
is_true "${VEIL_PERSISTENT:-}"  && args+=(-F "persistent=1")
is_true "${VEIL_ANTI_DEBUG:-}"  && args+=(-F "anti_debug=1")

resp="$(mktemp)"
curl "${args[@]}" "${VEIL_API_URL%/}/api/protect" > "$resp" || { echo "::error::protect API request failed"; exit 1; }

# Parse + base64-decode with python3 (preinstalled on GitHub-hosted runners).
VEIL_OUTPUT="$VEIL_OUTPUT" VEIL_RECEIPT="${VEIL_RECEIPT:-}" python3 - "$resp" <<'PY'
import sys, os, json, base64
resp = json.load(open(sys.argv[1]))
if not resp.get("ok") or not resp.get("artifact_b64"):
    print("::error::" + str(resp.get("error") or "protect failed (no artifact returned)"))
    sys.exit(1)
out = os.environ["VEIL_OUTPUT"]
with open(out, "wb") as f:
    f.write(base64.b64decode(resp["artifact_b64"]))
rec = os.environ.get("VEIL_RECEIPT")
if rec and resp.get("receipt"):
    json.dump(resp["receipt"], open(rec, "w"), indent=2)
q = resp.get("quota") or {}
r = resp.get("receipt") or {}
print(f"veilcc: protected -> {out} (level {r.get('level','?')}, receipt {r.get('receipt_hash','?')})")
if q:
    print(f"        quota: {q.get('used','?')} of {q.get('limit','?')} used this month")
PY

if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "protected=$VEIL_OUTPUT" >> "$GITHUB_OUTPUT"; fi
rm -f "$resp"
