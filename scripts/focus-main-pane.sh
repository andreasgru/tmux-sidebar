#!/usr/bin/env bash
set -euo pipefail

main_pane="${1:-$(tmux show-options -gv @tmux_sidebar_main_pane 2>/dev/null || true)}"
[ -n "$main_pane" ] || exit 0

tmux select-pane -t "$main_pane"
