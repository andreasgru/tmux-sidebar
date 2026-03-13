# Tmux Sidebar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a tmux plugin that toggles a right-hand sidebar showing a session/window/pane tree with pane-level agent status badges and automatic badge clearing on focus.

**Architecture:** The plugin is a shell-based tmux extension with a dedicated sidebar pane, a file-backed pane state store under `~/.tmux-sidebar/state`, and helper scripts for rendering, toggling, state updates, and focus clearing. Agent apps report explicit pane status through their hook systems, and the renderer merges tmux metadata with the stored pane state.

**Tech Stack:** tmux, POSIX shell/Bash, plain-text rendering, shell-based tests

---

### Task 1: Bootstrap plugin layout and shell test harness

**Files:**
- Create: `sidebar.tmux`
- Create: `scripts/lib.sh`
- Create: `tests/testlib.sh`
- Create: `tests/run.sh`
- Create: `tests/lib_test.sh`

**Step 1: Write the failing test**

```bash
# tests/lib_test.sh
test_default_state_dir() {
  unset TMUX_SIDEBAR_STATE_DIR
  run_script scripts/lib.sh print_state_dir
  assert_eq "$output" "$HOME/.tmux-sidebar/state"
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/lib_test.sh`
Expected: FAIL because `scripts/lib.sh` and the helper functions do not exist yet

**Step 3: Write minimal implementation**

```bash
# scripts/lib.sh
#!/usr/bin/env bash
set -euo pipefail

print_state_dir() {
  printf '%s\n' "${TMUX_SIDEBAR_STATE_DIR:-$HOME/.tmux-sidebar/state}"
}

"$@"
```

```bash
# tests/testlib.sh
run_script() {
  output="$(bash "$@" 2>&1)"
}
```

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/lib_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add sidebar.tmux scripts/lib.sh tests/testlib.sh tests/run.sh tests/lib_test.sh
git commit -m "chore: bootstrap tmux sidebar plugin skeleton"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 2: Add failing tests for pane state updates

**Files:**
- Create: `scripts/update-pane-state.sh`
- Create: `tests/update_pane_state_test.sh`
- Modify: `tests/testlib.sh`
- Modify: `tests/run.sh`

**Step 1: Write the failing test**

```bash
test_writes_pane_state_file() {
  export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
  fake_tmux_register_pane "%7" "work" "@2" "editor" "vim"

  bash scripts/update-pane-state.sh \
    --pane "%7" \
    --app claude \
    --status needs-input \
    --message "Permission request"

  assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"needs-input"'
  assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"app":"claude"'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/update_pane_state_test.sh`
Expected: FAIL because `scripts/update-pane-state.sh` and fake tmux helpers are missing

**Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

pane_id=""
app=""
status=""
message=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pane) pane_id="$2"; shift 2 ;;
    --app) app="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --message) message="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

meta="$(tmux display-message -p -t "$pane_id" '#{session_name}|#{window_id}|#{window_name}|#{pane_current_command}')"
[ -n "$meta" ] || exit 0

state_dir="${TMUX_SIDEBAR_STATE_DIR:-$HOME/.tmux-sidebar/state}"
mkdir -p "$state_dir"
tmp_file="$(mktemp "$state_dir/.pane.XXXXXX")"
printf '{"pane_id":"%s","app":"%s","status":"%s","message":"%s","updated_at":"%s"}' \
  "$pane_id" "$app" "$status" "$message" "$(date +%s)" > "$tmp_file"
mv "$tmp_file" "$state_dir/pane-$pane_id.json"
```

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/update_pane_state_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/update-pane-state.sh tests/update_pane_state_test.sh tests/testlib.sh tests/run.sh
git commit -m "feat: add pane state update helper"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 3: Add timestamp ordering and clear-on-focus behavior

**Files:**
- Create: `scripts/clear-pane-state.sh`
- Create: `tests/clear_pane_state_test.sh`
- Modify: `scripts/update-pane-state.sh`

**Step 1: Write the failing test**

```bash
test_clear_focus_only_removes_transient_status() {
  export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
  mkdir -p "$TMUX_SIDEBAR_STATE_DIR"
  printf '%s' '{"pane_id":"%7","app":"claude","status":"needs-input","updated_at":100}' \
    > "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json"

  bash scripts/clear-pane-state.sh "%7"

  assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"idle"'
}
```

Add a second test for ordering:

```bash
test_older_update_does_not_replace_newer_status() {
  # write a newer file first, then attempt older update with --updated-at 50
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/clear_pane_state_test.sh tests/update_pane_state_test.sh`
Expected: FAIL because clear behavior and timestamp comparison are not implemented

**Step 3: Write minimal implementation**

```bash
# scripts/clear-pane-state.sh
#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:?pane id required}"
state_file="${TMUX_SIDEBAR_STATE_DIR:-$HOME/.tmux-sidebar/state}/pane-$pane_id.json"
[ -f "$state_file" ] || exit 0

case "$(grep -o '"status":"[^"]*"' "$state_file" | cut -d'"' -f4)" in
  needs-input|done)
    perl -0pi -e 's/"status":"[^"]*"/"status":"idle"/' "$state_file"
    ;;
esac
```

Extend `scripts/update-pane-state.sh` to accept `--updated-at` and ignore stale writes.

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/clear_pane_state_test.sh tests/update_pane_state_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/clear-pane-state.sh scripts/update-pane-state.sh tests/clear_pane_state_test.sh tests/update_pane_state_test.sh
git commit -m "feat: add pane status lifecycle helpers"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 4: Render the session/window/pane tree with badges

**Files:**
- Create: `scripts/render-sidebar.sh`
- Create: `tests/render_sidebar_test.sh`
- Modify: `scripts/lib.sh`

**Step 1: Write the failing test**

```bash
test_render_tree_includes_panes_and_badges() {
  fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|1
work|@1|editor|%2|claude|0
ops|@3|logs|%9|tail|0
EOF

  mkdir -p "$TEST_TMP/state"
  printf '%s' '{"pane_id":"%2","app":"claude","status":"needs-input","updated_at":100}' \
    > "$TEST_TMP/state/pane-%2.json"

  output="$(TMUX_SIDEBAR_STATE_DIR=$TEST_TMP/state bash scripts/render-sidebar.sh)"

  assert_contains "$output" "work"
  assert_contains "$output" "editor"
  assert_contains "$output" "%2 claude"
  assert_contains "$output" "needs-input"
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/render_sidebar_test.sh`
Expected: FAIL because the renderer does not exist

**Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

state_dir="${TMUX_SIDEBAR_STATE_DIR:-$HOME/.tmux-sidebar/state}"
tmux list-panes -a -F '#{session_name}|#{window_id}|#{window_name}|#{pane_id}|#{pane_title}|#{pane_active}' |
awk -F'|' '
  {
    if (!seen_session[$1]++) print $1
    if (!seen_window[$1 FS $2]++) print "  " $3
    print "    " $4 " " $5
  }
'
```

Then extend it to merge badge state from `pane-*.json`, mark the active pane, and prune stale pane files.

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/render_sidebar_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/render-sidebar.sh scripts/lib.sh tests/render_sidebar_test.sh
git commit -m "feat: render tmux sidebar tree with pane badges"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 5: Implement sidebar toggle and tmux hooks

**Files:**
- Create: `scripts/toggle-sidebar.sh`
- Create: `tests/toggle_sidebar_test.sh`
- Modify: `sidebar.tmux`
- Modify: `scripts/render-sidebar.sh`

**Step 1: Write the failing test**

```bash
test_toggle_opens_sidebar_once_and_then_closes_it() {
  fake_tmux_no_sidebar

  bash scripts/toggle-sidebar.sh
  assert_eq "$(fake_tmux_sidebar_count)" "1"

  bash scripts/toggle-sidebar.sh
  assert_eq "$(fake_tmux_sidebar_count)" "0"
}
```

Add a second test:

```bash
test_sidebar_tmux_file_binds_prefix_shift_s() {
  assert_file_contains "sidebar.tmux" 'bind-key S'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/toggle_sidebar_test.sh`
Expected: FAIL because toggle logic and tmux wiring are missing

**Step 3: Write minimal implementation**

```bash
# sidebar.tmux
bind-key S run-shell "~/.tmux/plugins/tmux-sidebar/scripts/toggle-sidebar.sh"
set-hook -g pane-focus-in 'run-shell "~/.tmux/plugins/tmux-sidebar/scripts/clear-pane-state.sh #{pane_id}"'
```

```bash
# scripts/toggle-sidebar.sh
#!/usr/bin/env bash
set -euo pipefail

sidebar_pane="$(tmux list-panes -a -F '#{pane_id} #{pane_title}' | awk '$2=="tmux-sidebar"{print $1; exit}')"
if [ -n "${sidebar_pane:-}" ]; then
  tmux kill-pane -t "$sidebar_pane"
  exit 0
fi

tmux split-window -h -l 40 -P -F '#{pane_id}' \
  "bash scripts/render-sidebar.sh"
tmux select-pane -T tmux-sidebar
```

Refine the implementation so the sidebar pane continuously redraws or refreshes via tmux hooks without stealing focus from the user.

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/toggle_sidebar_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add sidebar.tmux scripts/toggle-sidebar.sh scripts/render-sidebar.sh tests/toggle_sidebar_test.sh
git commit -m "feat: add tmux sidebar toggle and focus hooks"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 6: Document hook integration for Claude, Codex, and OpenCode

**Files:**
- Create: `README.md`
- Create: `examples/claude-hook.sh`
- Create: `examples/codex-hook.sh`
- Create: `examples/opencode-hook.sh`
- Test: `tests/update_pane_state_test.sh`

**Step 1: Write the failing test**

```bash
test_examples_call_update_helper_with_expected_status_values() {
  assert_file_contains "examples/claude-hook.sh" "update-pane-state.sh"
  assert_file_contains "examples/codex-hook.sh" "--status done"
  assert_file_contains "examples/opencode-hook.sh" "--status needs-input"
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/update_pane_state_test.sh tests/toggle_sidebar_test.sh`
Expected: FAIL because the integration examples and documentation do not exist

**Step 3: Write minimal implementation**

```bash
# examples/claude-hook.sh
#!/usr/bin/env bash
exec ~/.tmux/plugins/tmux-sidebar/scripts/update-pane-state.sh \
  --pane "$TMUX_PANE" \
  --app claude \
  --status "${1:?status required}"
```

Document:
- installation path
- `run-shell` binding
- state directory location
- supported statuses
- sample hook wiring for each app

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/update_pane_state_test.sh tests/toggle_sidebar_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add README.md examples/claude-hook.sh examples/codex-hook.sh examples/opencode-hook.sh
git commit -m "docs: add tmux sidebar installation and hook examples"
```

If the workspace is still not a git repository, skip this step and continue.
