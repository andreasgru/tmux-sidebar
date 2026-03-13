#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" <<'EOF'
{"pane_id":"%7","app":"claude","status":"needs-input","updated_at":100}
EOF

bash scripts/clear-pane-state.sh "%7"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"idle"'

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" <<'EOF'
{"pane_id":"%8","app":"claude","status":"running","updated_at":100}
EOF

bash scripts/clear-pane-state.sh "%8"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" '"status":"running"'
