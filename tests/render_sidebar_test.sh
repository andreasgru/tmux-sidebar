#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|shell|shell|0
work|@1|editor|%2|claude|claude|1
ops|@3|logs|%9|tail|tail|0
EOF

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%2.json" <<'EOF'
{"pane_id":"%2","app":"claude","status":"needs-input","updated_at":100}
EOF

output="$(bash scripts/render-sidebar.sh)"

case "$output" in
  *"├─ work"* ) ;;
  * ) fail "expected session name in renderer output" ;;
esac

case "$output" in
  *"│  └─ editor"* ) ;;
  * ) fail "expected window name in renderer output" ;;
esac

case "$output" in
  *"│     └─ %2 claude [!]"* ) ;;
  * ) fail "expected pane badge in renderer output" ;;
esac

case "$output" in
  *"│     └─ %2 claude [!]"* ) ;;
  * ) fail "expected active pane marker in renderer output" ;;
esac

case "$output" in
  *"└─ ops"* ) ;;
  * ) fail "expected unicode pane branch continuation in renderer output" ;;
esac
