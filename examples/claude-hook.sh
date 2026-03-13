#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
EVENT_NAME="${CLAUDE_HOOK_EVENT_NAME:-}"

status="running"
message=""

case "$EVENT_NAME" in
  Notification|PermissionRequest)
    status="needs-input"
    message="${CLAUDE_NOTIFICATION_MESSAGE:-$EVENT_NAME}"
    ;;
  Stop)
    status="done"
    ;;
  SessionEnd)
    status="idle"
    ;;
esac

exec "$PLUGIN_DIR/scripts/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app claude \
  --status "$status" \
  --message "$message"
