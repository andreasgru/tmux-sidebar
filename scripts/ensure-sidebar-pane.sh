#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0

current_window="$(tmux display-message -p '#{window_id}')"
window_key="${current_window//@/w}"
sidebar_pane_option="@tmux_sidebar_pane_${window_key}"
sidebar_creating_option="@tmux_sidebar_creating_${window_key}"

stored_pane="$(tmux show-options -gv "$sidebar_pane_option" 2>/dev/null || true)"
if [ -n "$stored_pane" ]; then
  stored_sidebar="$(
    tmux list-panes -a -F '#{pane_id}|#{pane_title}|#{window_id}' \
      | awk -F'|' -v target_pane="$stored_pane" -v current_window="$current_window" \
          '$1 == target_pane && $2 == "tmux-sidebar" && $3 == current_window { print $1; exit }'
  )"
  if [ -n "$stored_sidebar" ]; then
    exit 0
  fi
  tmux set-option -g -u "$sidebar_pane_option" 2>/dev/null || true
fi

existing_pane="$(
  tmux list-panes -a -F '#{pane_id}|#{pane_title}|#{window_id}' \
    | awk -F'|' -v current_window="$current_window" '$2 == "tmux-sidebar" && $3 == current_window { print $1; exit }'
)"
if [ -n "$existing_pane" ]; then
  tmux set-option -g "$sidebar_pane_option" "$existing_pane"
  exit 0
fi

creating="$(tmux show-options -gv "$sidebar_creating_option" 2>/dev/null || true)"
[ "$creating" != "1" ] || exit 0

configured_sidebar_width="$(tmux show-options -gv @tmux_sidebar_width 2>/dev/null || true)"
sidebar_width="${TMUX_SIDEBAR_WIDTH:-${configured_sidebar_width:-35}}"
current_pane="$(tmux display-message -p '#{pane_id}')"
sidebar_command="$(sidebar_ui_command "$SCRIPT_DIR")"

tmux set-option -g "$sidebar_creating_option" 1
cleanup() {
  tmux set-option -g -u "$sidebar_creating_option" 2>/dev/null || true
}
trap cleanup EXIT

sidebar_pane="$(
  tmux split-window -h -b -d -f -l "$sidebar_width" -P -F '#{pane_id}' "$sidebar_command"
)"
tmux select-pane -t "$sidebar_pane" -T tmux-sidebar
tmux set-option -g "$sidebar_pane_option" "$sidebar_pane"
tmux select-pane -t "$current_pane"
