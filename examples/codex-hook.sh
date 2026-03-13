#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
STATUS="${CODEX_STATUS:-done}"
MESSAGE="${CODEX_MESSAGE:-}"

exec "$PLUGIN_DIR/scripts/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$STATUS" \
  --message "$MESSAGE"
