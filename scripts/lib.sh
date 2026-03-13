#!/usr/bin/env bash
set -euo pipefail

print_state_dir() {
  printf '%s\n' "${TMUX_SIDEBAR_STATE_DIR:-$HOME/.tmux-sidebar/state}"
}

sidebar_render_command() {
  local script_dir="$1"
  printf 'bash -lc %q' "\"$script_dir/render-sidebar.sh\"; exec cat"
}

sidebar_ui_command() {
  local script_dir="$1"
  printf 'python3 %q' "$script_dir/sidebar-ui.py"
}

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

json_get_string() {
  local path="$1"
  local key="$2"
  sed -n "s/.*\"$key\":\"\\([^\"]*\\)\".*/\\1/p" "$path"
}

json_get_number() {
  local path="$1"
  local key="$2"
  sed -n "s/.*\"$key\":\\([0-9][0-9]*\\).*/\\1/p" "$path"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  "$@"
fi
