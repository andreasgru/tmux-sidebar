#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
fake_tmux_register_pane "%7" "work" "@2" "editor" "Claude"

bash scripts/update-pane-state.sh \
  --pane "%7" \
  --app claude \
  --status needs-input \
  --message "Permission request"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"needs-input"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"app":"claude"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"session_name":"work"'
