# Tmux Sidebar Mirrored Pane Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current single-window sidebar behavior with a mirrored left sidebar pane that auto-exists in every visited tmux window while enabled, with interactive navigation and tmux-only focus semantics.

**Architecture:** The sidebar remains a pane, but its lifecycle becomes window-aware and mirrored across visited windows. A global enabled flag controls whether windows should host a sidebar. Hooks ensure sidebar presence on window/session entry, and the sidebar UI becomes an interactive pane-local navigator using a structured Unicode tree model and event-driven refresh.

**Tech Stack:** tmux, Bash, Python for structured rendering/navigation, tmux hooks, shell tests

---

### Task 1: Introduce global enabled state and mirrored pane lifecycle

**Files:**
- Modify: `scripts/toggle-sidebar.sh`
- Create: `scripts/ensure-sidebar-pane.sh`
- Create: `tests/ensure_sidebar_pane_test.sh`
- Modify: `tests/testlib.sh`

**Step 1: Write the failing test**

```bash
test_toggle_enables_sidebar_globally_and_creates_left_pane() {
  fake_tmux_no_sidebar

  bash scripts/toggle-sidebar.sh

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -l 40'
}
```

Add a second test:

```bash
test_ensure_sidebar_creates_missing_pane_in_current_window() {
  fake_tmux_no_sidebar
  printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

  bash scripts/ensure-sidebar-pane.sh

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -l 40'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ensure_sidebar_pane_test.sh`
Expected: FAIL because mirrored lifecycle is not implemented

**Step 3: Write minimal implementation**

- store a global enabled flag
- create/remove sidebar pane in the current window
- preserve focus in the main pane

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/ensure_sidebar_pane_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/toggle-sidebar.sh scripts/ensure-sidebar-pane.sh tests/ensure_sidebar_pane_test.sh tests/testlib.sh
git commit -m "feat: add mirrored sidebar pane lifecycle"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 2: Auto-create sidebar on window/session entry

**Files:**
- Modify: `sidebar.tmux`
- Create: `tests/sidebar_hooks_test.sh`

**Step 1: Write the failing test**

```bash
test_tmux_hooks_ensure_sidebar_on_window_entry() {
  assert_file_contains "sidebar.tmux" 'client-session-changed'
  assert_file_contains "sidebar.tmux" 'window-pane-changed'
  assert_file_contains "sidebar.tmux" 'ensure-sidebar-pane.sh'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_hooks_test.sh`
Expected: FAIL because hooks do not enforce mirrored presence

**Step 3: Write minimal implementation**

- add hooks that call `ensure-sidebar-pane.sh` when entering/changing windows or sessions
- keep refresh hooks in place

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_hooks_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add sidebar.tmux tests/sidebar_hooks_test.sh
git commit -m "feat: auto-create sidebar on window and session entry"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 3: Make the sidebar UI interactive inside the pane

**Files:**
- Create: `scripts/sidebar-ui.py`
- Create: `tests/sidebar_ui_state_test.sh`
- Modify: `scripts/render-sidebar.sh`

**Step 1: Write the failing test**

```bash
test_sidebar_ui_builds_unicode_tree_and_selectable_rows() {
  fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|0
work|@1|editor|%2|claude|1
ops|@3|logs|%9|tail|0
EOF

  output="$(python3 scripts/sidebar-ui.py --dump-render)"

  assert_contains "$output" '├─ work'
  assert_contains "$output" '│     └─ > %2 claude'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: FAIL because the interactive UI does not exist yet

**Step 3: Write minimal implementation**

- build a structured tree model
- expose selection state
- render Unicode tree lines

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/sidebar-ui.py tests/sidebar_ui_state_test.sh scripts/render-sidebar.sh
git commit -m "feat: add interactive sidebar tree UI"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 4: Add keyboard navigation and `Ctrl+l` focus escape

**Files:**
- Modify: `scripts/sidebar-ui.py`
- Create: `scripts/focus-main-pane.sh`
- Create: `tests/sidebar_navigation_test.sh`
- Create: `tests/focus_main_pane_test.sh`

**Step 1: Write the failing test**

```bash
test_ctrl_l_from_sidebar_focuses_main_pane_in_same_window() {
  fake_tmux_register_main_pane '%1'

  bash scripts/focus-main-pane.sh '%1'

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
}
```

Add a navigation test:

```bash
test_navigation_moves_selection_cursor() {
  output="$(python3 scripts/sidebar-ui.py --test-nav down up)"
  assert_contains "$output" '"selected_index": 0'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_navigation_test.sh tests/focus_main_pane_test.sh`
Expected: FAIL because interactive movement and `Ctrl+l` escape are missing

**Step 3: Write minimal implementation**

- add navigation state and bindings
- make `Ctrl+l` focus the main pane in the current window

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_navigation_test.sh tests/focus_main_pane_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/sidebar-ui.py scripts/focus-main-pane.sh tests/sidebar_navigation_test.sh tests/focus_main_pane_test.sh
git commit -m "feat: add sidebar navigation and focus escape"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 5: Activate selected pane and preserve mirrored sidebar

**Files:**
- Modify: `scripts/sidebar-ui.py`
- Modify: `scripts/ensure-sidebar-pane.sh`
- Create: `tests/sidebar_activate_selection_test.sh`

**Step 1: Write the failing test**

```bash
test_enter_switches_to_target_pane_and_preserves_sidebar_in_destination() {
  bash scripts/sidebar-activate-selection.sh 'work' '@1' '%2'

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'switch-client -t work'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-window -t @1'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %2'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'ensure-sidebar-pane.sh'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_activate_selection_test.sh`
Expected: FAIL because target activation does not preserve mirrored presence yet

**Step 3: Write minimal implementation**

- add explicit selection activation
- switch to target session/window/pane
- ensure sidebar exists in the destination window

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_activate_selection_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/sidebar-ui.py scripts/ensure-sidebar-pane.sh tests/sidebar_activate_selection_test.sh
git commit -m "feat: activate selected pane with mirrored sidebar preservation"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 6: Rewire refresh/update flow for mirrored panes

**Files:**
- Modify: `scripts/refresh-sidebar.sh`
- Modify: `scripts/update-pane-state.sh`
- Modify: `scripts/clear-pane-state.sh`
- Create: `tests/sidebar_refresh_global_test.sh`

**Step 1: Write the failing test**

```bash
test_refresh_updates_sidebar_in_current_window_without_polling() {
  fake_tmux_register_sidebar_pane '%99'

  bash scripts/refresh-sidebar.sh

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'respawn-pane -k -t %99'
  assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'sleep 1'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_refresh_global_test.sh`
Expected: FAIL if refresh does not correctly target the mirrored pane model

**Step 3: Write minimal implementation**

- refresh the current window's sidebar pane
- keep event-driven updates
- never restore polling

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_refresh_global_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/refresh-sidebar.sh scripts/update-pane-state.sh scripts/clear-pane-state.sh tests/sidebar_refresh_global_test.sh
git commit -m "feat: refresh mirrored sidebar panes on events"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 7: Update docs and live installer for mirrored pane behavior

**Files:**
- Modify: `scripts/install-live.sh`
- Modify: `README.md`
- Test: `tests/hook_examples_test.sh`

**Step 1: Write the failing test**

```bash
test_docs_describe_mirrored_left_sidebar_behavior() {
  assert_file_contains "README.md" "mirrored"
  assert_file_contains "README.md" "Ctrl+l"
  assert_file_contains "README.md" "auto-created"
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/hook_examples_test.sh`
Expected: FAIL because docs still describe the previous model

**Step 3: Write minimal implementation**

- update docs and installer notes
- keep tmux/Claude/Codex hook wiring intact

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/hook_examples_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/install-live.sh README.md
git commit -m "docs: update mirrored sidebar installation and behavior"
```

If the workspace is still not a git repository, skip this step and continue.
