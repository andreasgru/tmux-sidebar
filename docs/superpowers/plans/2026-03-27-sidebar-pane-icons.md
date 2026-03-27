# Sidebar Pane Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pane icons to the sidebar with agent icons first, then generalized app icons, while keeping the feature dependency-free and reliable across terminals.

**Architecture:** Keep icon classification and theme data in `scripts/ui/sidebar_ui_lib/status.py`, where pane/app detection already lives. Keep row composition in `scripts/ui/sidebar_ui_lib/tree.py`, which already joins pane labels and badges. Use an ASCII-safe default theme and a richer optional Unicode theme, both implemented as built-in string tables with tmux option overrides.

**Tech Stack:** Bash tests, Python 3 curses UI, tmux options, fake tmux test framework

---

### Task 1: Plan And Detection Surface

**Files:**
- Create: `docs/superpowers/plans/2026-03-27-sidebar-pane-icons.md`
- Modify: `scripts/ui/sidebar_ui_lib/status.py`
- Test: `tests/ui/sidebar_ui_state_test.sh`

- [ ] **Step 1: Write the failing test**

Add an end-to-end assertion in `tests/ui/sidebar_ui_state_test.sh` that a known agent pane renders with a prepended icon before the agent label.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: FAIL because pane text still contains only the label and badge, without an icon.

- [ ] **Step 3: Write minimal implementation**

Add the smallest icon theme/config helpers in `scripts/ui/sidebar_ui_lib/status.py` and compose them into pane rows in `scripts/ui/sidebar_ui_lib/tree.py` so known agent app ids render with built-in icon strings.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: PASS with the agent pane showing the new icon.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-03-27-sidebar-pane-icons.md tests/ui/sidebar_ui_state_test.sh scripts/ui/sidebar_ui_lib/status.py scripts/ui/sidebar_ui_lib/tree.py
git commit -m "feat: add sidebar agent icons"
```

### Task 2: Row Composition And Theme Option

**Files:**
- Modify: `scripts/ui/sidebar_ui_lib/status.py`
- Modify: `scripts/ui/sidebar_ui_lib/tree.py`
- Test: `tests/ui/sidebar_ui_state_test.sh`

- [ ] **Step 1: Write the failing test**

Add assertions that the icon is prepended in the final pane row text, ahead of the display label and before any badge.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: FAIL because row composition still omits the icon or places it in the wrong order.

- [ ] **Step 3: Write minimal implementation**

Compose pane text in `tree.py` using a dedicated helper from `status.py`, preserving existing label and badge behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: PASS with the icon, label, and badge in the intended order.

- [ ] **Step 5: Commit**

```bash
git add tests/ui/sidebar_ui_state_test.sh scripts/ui/sidebar_ui_lib/status.py scripts/ui/sidebar_ui_lib/tree.py
git commit -m "feat: render pane icons in sidebar rows"
```

### Task 3: General App Classification

**Files:**
- Modify: `scripts/ui/sidebar_ui_lib/status.py`
- Test: `tests/ui/sidebar_ui_state_test.sh`

- [ ] **Step 1: Write the failing test**

Add tests for non-agent panes such as shells, `node`, `lazygit`, `yazi`, `ranger`, `bb`, `clojure`, and `java`, plus a generic unknown fallback under the default icon theme.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: FAIL because non-agent pane commands do not yet map to icon-bearing canonical app ids.

- [ ] **Step 3: Write minimal implementation**

Add canonical app normalization and alias detection in `status.py`, keeping agent detection precedence intact and falling back to a generic unknown app id/icon only when icon mode is enabled.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: PASS for all mapped apps and the unknown fallback.

- [ ] **Step 5: Commit**

```bash
git add tests/ui/sidebar_ui_state_test.sh scripts/ui/sidebar_ui_lib/status.py scripts/ui/sidebar_ui_lib/tree.py
git commit -m "feat: add sidebar icons for common apps"
```

### Task 4: Configuration And Documentation

**Files:**
- Modify: `scripts/ui/sidebar_ui_lib/status.py`
- Modify: `README.md`
- Test: `tests/ui/sidebar_ui_state_test.sh`

- [ ] **Step 1: Write the failing test**

Add tests for the icon theme option and one per-app icon override through tmux options.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: FAIL because icon options are not yet read from tmux.

- [ ] **Step 3: Write minimal implementation**

Support a default theme option plus per-app icon overrides in `status.py`, then document the configuration in `README.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/ui/sidebar_ui_state_test.sh`
Expected: PASS with option-driven icons.

- [ ] **Step 5: Commit**

```bash
git add tests/ui/sidebar_ui_state_test.sh scripts/ui/sidebar_ui_lib/status.py README.md
git commit -m "docs: document sidebar icon options"
```

### Task 5: Full Verification

**Files:**
- Modify: `tests/ui/sidebar_ui_filter_option_test.sh`
- Modify: `tests/ui/sidebar_ui_hide_panes_test.sh`
- Test: `tests/run.sh`

- [ ] **Step 1: Write the failing test**

Add any missing regression checks so filter and hide-panes behaviors still work with icon-prefixed pane labels.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/ui/sidebar_ui_hide_panes_test.sh tests/ui/sidebar_ui_filter_option_test.sh`
Expected: PASS if the new assertions reveal no regression, otherwise FAIL with the interaction that needs fixing.

- [ ] **Step 3: Write minimal implementation**

Adjust only the pieces needed to keep filter, hide-panes, and truncation behavior stable with icons enabled.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh`
Expected: PASS for the full suite.

- [ ] **Step 5: Commit**

```bash
git add tests/ui/sidebar_ui_hide_panes_test.sh tests/ui/sidebar_ui_filter_option_test.sh scripts/ui/sidebar_ui_lib/status.py scripts/ui/sidebar_ui_lib/tree.py README.md
git commit -m "test: cover sidebar icon regressions"
```
