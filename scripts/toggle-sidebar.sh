#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
ensure_script="$SCRIPT_DIR/ensure-sidebar-pane.sh"

clear_sidebar_state_options() {
  tmux show-options -g 2>/dev/null \
    | awk '/^@tmux_sidebar_(pane|creating)_/ { print $1 }' \
    | while IFS= read -r option_name; do
        [ -n "$option_name" ] || continue
        tmux set-option -g -u "$option_name"
      done
}

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
sidebar_panes="$(
  tmux list-panes -a -F '#{pane_id}|#{pane_title}' \
    | awk -F'|' '$2 == "tmux-sidebar" { print $1 }'
)"

if [ "$enabled" = "1" ] && [ -z "$sidebar_panes" ]; then
  clear_sidebar_state_options
  enabled="0"
fi

if [ "$enabled" = "1" ]; then
  tmux set-option -g @tmux_sidebar_enabled 0
  printf '%s\n' "$sidebar_panes" \
    | while IFS= read -r pane_id; do
        [ -n "$pane_id" ] || continue
        tmux kill-pane -t "$pane_id"
      done
  clear_sidebar_state_options
  exit 0
fi

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
current_title="$(tmux display-message -p '#{pane_title}' 2>/dev/null || true)"
if [ -n "$current_pane" ] && [ "$current_title" != "tmux-sidebar" ]; then
  tmux set-option -g @tmux_sidebar_main_pane "$current_pane"
fi

tmux set-option -g @tmux_sidebar_enabled 1
bash "$ensure_script"
