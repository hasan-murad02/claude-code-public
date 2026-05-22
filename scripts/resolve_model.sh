#!/usr/bin/env bash
# Claude Router - resolve_model.sh <session_id> [transcript_path]
# Cache lookup first, then transcript fallback (overrides cache to catch /model swaps).
set -uo pipefail

SESSION_ID="${1:-}"
TRANSCRIPT_PATH="${2:-}"
CACHE_DIR="${CLAUDE_ROUTER_CACHE_DIR:-$HOME/.claude/plugins/claude-router/cache}"
SESSIONS_FILE="$CACHE_DIR/sessions.json"

if [[ -z "$SESSION_ID" ]] || ! command -v jq >/dev/null 2>&1; then
  echo ""
  exit 0
fi

MODEL=""
if [[ -s "$SESSIONS_FILE" ]]; then
  MODEL="$(jq -r --arg sid "$SESSION_ID" '.[$sid].model // empty' "$SESSIONS_FILE" 2>/dev/null || true)"
fi

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  TRANSCRIPT_MODEL="$(jq -r 'select(.type=="assistant") | .message.model? // empty' "$TRANSCRIPT_PATH" 2>/dev/null | grep -v '^$' | tail -n 1 || true)"
  if [[ -n "$TRANSCRIPT_MODEL" ]]; then
    MODEL="$TRANSCRIPT_MODEL"
    if [[ -s "$SESSIONS_FILE" ]]; then
      NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      TMP_FILE="$(mktemp "${SESSIONS_FILE}.XXXXXX")"
      jq --arg sid "$SESSION_ID" --arg model "$MODEL" --arg now "$NOW" \
        '.[$sid] = ((.[$sid] // {}) + {model: $model, updated_at: $now})' \
        "$SESSIONS_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$SESSIONS_FILE"
    fi
  fi
fi

echo "$MODEL"
exit 0
