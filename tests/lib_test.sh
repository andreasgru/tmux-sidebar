#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

unset TMUX_SIDEBAR_STATE_DIR
run_script scripts/lib.sh print_state_dir
assert_eq "$output" "$HOME/.tmux-sidebar/state"
