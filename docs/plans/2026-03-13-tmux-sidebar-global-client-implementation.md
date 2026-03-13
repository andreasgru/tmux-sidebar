# Tmux Sidebar Global Client Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the pane-based sidebar with a full-height global left sidebar backed by a separate tmux client, with keyboard navigation and explicit focus handoff to the main client.

**Architecture:** The implementation introduces a dedicated sidebar tmux session/window/client plus a small interactive TUI process that owns tree selection state. Hooks and tmux events update shared state and trigger re-rendering, while selection commands switch the main client to a target pane without closing the sidebar.

**Tech Stack:** tmux, Bash, Python for structured rendering/navigation, tmux hooks, shell tests

---

### Task 1: Replace pane-based toggle with sidebar client lifecycle

**Files:**
- Modify: `scripts/toggle-sidebar.sh`
- Create: `scripts/sidebar-client.sh`
- Create: `tests/sidebar_client_toggle_test.sh`
- Modify: `tests/testlib.sh`

**Step 1: Write the failing test**

```bash
test_toggle_creates_sidebar_client_instead_of_split_pane() {
  fake_tmux_reset_clients

  bash scripts/toggle-sidebar.sh

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-session -d -s tmux-sidebar'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-window -t tmux-sidebar'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'display-popup'
  assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_client_toggle_test.sh`
Expected: FAIL because toggle still uses `split-window`

**Step 3: Write minimal implementation**

- make `toggle-sidebar.sh` create/manage a dedicated sidebar session/window/client
- persist sidebar runtime ids in tmux options
- remove pane-split logic

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_client_toggle_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/toggle-sidebar.sh scripts/sidebar-client.sh tests/sidebar_client_toggle_test.sh tests/testlib.sh
git commit -m "feat: replace pane sidebar with client lifecycle"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 2: Introduce interactive sidebar navigator state

**Files:**
- Create: `scripts/sidebar-ui.py`
- Create: `scripts/sidebar-state.sh`
- Create: `tests/sidebar_ui_state_test.sh`
- Modify: `scripts/render-sidebar.sh`

**Step 1: Write the failing test**

```bash
test_sidebar_ui_builds_selectable_tree_rows() {
  fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|0
work|@1|editor|%2|claude|1
ops|@3|logs|%9|tail|0
EOF

  output="$(python3 scripts/sidebar-ui.py --dump-rows)"

  assert_contains "$output" '"pane_id": "%2"'
  assert_contains "$output" '"kind": "pane"'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: FAIL because no interactive sidebar model exists yet

**Step 3: Write minimal implementation**

- build tree rows from tmux metadata plus pane state
- expose selection rows independently from render output
- keep structured Unicode tree rendering

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/sidebar-ui.py scripts/sidebar-state.sh tests/sidebar_ui_state_test.sh scripts/render-sidebar.sh
git commit -m "feat: add interactive sidebar tree state"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 3: Add keyboard navigation and selection movement

**Files:**
- Modify: `scripts/sidebar-ui.py`
- Create: `tests/sidebar_navigation_test.sh`

**Step 1: Write the failing test**

```bash
test_navigation_moves_selection_without_changing_main_focus() {
  output="$(python3 scripts/sidebar-ui.py --test-nav down down up)"
  assert_contains "$output" '"selected_index": 1'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_navigation_test.sh`
Expected: FAIL because navigation commands are not implemented

**Step 3: Write minimal implementation**

- add selection state
- map `j/k` and arrows to movement
- render a visible selection cursor

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_navigation_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/sidebar-ui.py tests/sidebar_navigation_test.sh
git commit -m "feat: add sidebar keyboard navigation"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 4: Implement pane activation into the main client

**Files:**
- Modify: `scripts/sidebar-ui.py`
- Create: `scripts/focus-main-pane.sh`
- Create: `tests/focus_main_pane_test.sh`
- Modify: `tests/testlib.sh`

**Step 1: Write the failing test**

```bash
test_enter_focuses_exact_target_pane_in_main_client() {
  fake_tmux_set_main_client '%client-main'

  bash scripts/focus-main-pane.sh '%client-main' '%2' '@1' 'work'

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'switch-client -c %client-main -t work'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-window -t @1'
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %2'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/focus_main_pane_test.sh`
Expected: FAIL because pane activation flow is missing

**Step 3: Write minimal implementation**

- track last non-sidebar client
- on `Enter`, switch that client to the target session/window/pane
- keep the sidebar open

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/focus_main_pane_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/focus-main-pane.sh scripts/sidebar-ui.py tests/focus_main_pane_test.sh tests/testlib.sh
git commit -m "feat: activate selected pane from sidebar"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 5: Implement `Ctrl+l` return-to-main-client behavior

**Files:**
- Modify: `scripts/sidebar-ui.py`
- Create: `scripts/focus-main-client.sh`
- Create: `tests/focus_main_client_test.sh`

**Step 1: Write the failing test**

```bash
test_ctrl_l_returns_focus_to_last_main_client_without_selection_change() {
  fake_tmux_set_main_client '%client-main'

  bash scripts/focus-main-client.sh '%client-main'

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'switch-client -c %client-main'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/focus_main_client_test.sh`
Expected: FAIL because return-to-main behavior is not implemented

**Step 3: Write minimal implementation**

- store last main client
- bind `Ctrl+l` inside the sidebar UI to refocus that client
- do not activate a new pane

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/focus_main_client_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/focus-main-client.sh scripts/sidebar-ui.py tests/focus_main_client_test.sh
git commit -m "feat: return from sidebar to main client"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 6: Rewire refresh/hooks for the global client model

**Files:**
- Modify: `scripts/refresh-sidebar.sh`
- Modify: `scripts/update-pane-state.sh`
- Modify: `scripts/clear-pane-state.sh`
- Modify: `sidebar.tmux`
- Create: `tests/sidebar_refresh_global_test.sh`

**Step 1: Write the failing test**

```bash
test_refresh_targets_sidebar_window_or_client_not_worktree_pane() {
  fake_tmux_set_sidebar_client '%client-sidebar'

  bash scripts/refresh-sidebar.sh

  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'send-keys -t tmux-sidebar'
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_refresh_global_test.sh`
Expected: FAIL because refresh still targets the old pane-based model

**Step 3: Write minimal implementation**

- target the global sidebar runtime instead of a normal pane
- refresh through the sidebar UI process
- keep Claude/Codex hook integration intact

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_refresh_global_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/refresh-sidebar.sh scripts/update-pane-state.sh scripts/clear-pane-state.sh sidebar.tmux tests/sidebar_refresh_global_test.sh
git commit -m "feat: refresh global sidebar client on events"
```

If the workspace is still not a git repository, skip this step and continue.

### Task 7: Install-time wiring and live verification

**Files:**
- Modify: `scripts/install-live.sh`
- Modify: `README.md`
- Test: `tests/sidebar_client_toggle_test.sh`

**Step 1: Write the failing test**

```bash
test_install_docs_describe_global_left_sidebar_client() {
  assert_file_contains "README.md" "global left sidebar client"
  assert_file_contains "README.md" "Ctrl+l"
}
```

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/hook_examples_test.sh`
Expected: FAIL because docs still describe the pane-based sidebar

**Step 3: Write minimal implementation**

- update docs and live installer expectations
- keep hook wiring intact
- verify tmux config loads the new sidebar behavior

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/hook_examples_test.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/install-live.sh README.md
git commit -m "docs: update installation for global sidebar client"
```

If the workspace is still not a git repository, skip this step and continue.
