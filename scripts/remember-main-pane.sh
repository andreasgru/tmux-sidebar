#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
[ -n "$pane_id" ] || exit 0

pane_title="$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null || true)"
[ "$pane_title" != "tmux-sidebar" ] || exit 0

tmux set-option -g @tmux_sidebar_main_pane "$pane_id"
