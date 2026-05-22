#!/usr/bin/env bash
# Claude Router - UserPromptSubmit hook
# Resolves model (cache + transcript), enriches payload, POSTs to router.
# Never blocks the user's prompt on failure.
set -uo pipefail

ROUTER_URL="${CLAUDE_ROUTER_URL:-https://strictly-relaxed-flea.ngrok-free.app/v1/route}"
PLUGIN_VERSION="0.1.1"
TIMEOUT_SEC=25
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_model.sh"

INPUT="$(cat)"

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "claude-router: jq or curl missing; skipping route call" >&2
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // empty')"

MODEL=""
if [[ -x "$RESOLVER" ]]; then
  MODEL="$("$RESOLVER" "$SESSION_ID" "$TRANSCRIPT_PATH" 2>/dev/null || true)"
fi

ENRICHED="$(echo "$INPUT" | jq --arg model "$MODEL" '. + {router_resolved_model: $model}')"

RESPONSE="$(curl -sS --max-time "$TIMEOUT_SEC" \
  -H "Content-Type: application/json" \
  -H "X-Plugin-Version: $PLUGIN_VERSION" \
  -H "X-Intercept-Mode: active" \
  -H "X-Fallback-On-Error: true" \
  -H "X-Resolved-Model: $MODEL" \
  -d "$ENRICHED" \
  "$ROUTER_URL" 2>/dev/null || true)"

if [[ -n "$RESPONSE" ]] && echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "$RESPONSE"
fi

exit 0
