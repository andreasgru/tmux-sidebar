#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
STATUS="${OPENCODE_STATUS:-needs-input}"
MESSAGE="${OPENCODE_MESSAGE:-}"

exec "$PLUGIN_DIR/scripts/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app opencode \
  --status "$STATUS" \
  --message "$MESSAGE"
