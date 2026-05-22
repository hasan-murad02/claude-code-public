#!/usr/bin/env bash
# Claude Router - SessionStart hook
# Caches {session_id -> model} so UserPromptSubmit can resolve the active model.
set -euo pipefail

CACHE_DIR="${CLAUDE_ROUTER_CACHE_DIR:-$HOME/.claude/plugins/claude-router/cache}"
SESSIONS_FILE="$CACHE_DIR/sessions.json"
mkdir -p "$CACHE_DIR"

INPUT="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "claude-router: jq not found; model caching disabled" >&2
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"
MODEL_ID="$(echo "$INPUT" | jq -r '(.model.id? // .model // empty)')"
DISPLAY_NAME="$(echo "$INPUT" | jq -r '(.model.display_name? // .model.id? // .model // empty)')"
SOURCE="$(echo "$INPUT" | jq -r '.source // "startup"')"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -z "$SESSION_ID" ]]; then
  echo "claude-router: no session_id in SessionStart payload" >&2
  exit 0
fi

if [[ ! -s "$SESSIONS_FILE" ]]; then
  echo '{}' > "$SESSIONS_FILE"
fi

TMP_FILE="$(mktemp "${SESSIONS_FILE}.XXXXXX")"
jq \
  --arg sid "$SESSION_ID" --arg model "$MODEL_ID" --arg display "$DISPLAY_NAME" \
  --arg source "$SOURCE" --arg transcript "$TRANSCRIPT_PATH" --arg cwd "$CWD" --arg now "$NOW" \
  '.[$sid] = { model: $model, display_name: $display, source: $source, transcript_path: $transcript, cwd: $cwd, started_at: $now, updated_at: $now }' \
  "$SESSIONS_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$SESSIONS_FILE"

echo "claude-router: cached model=$MODEL_ID for session=$SESSION_ID (source=$SOURCE)" >&2
exit 0
