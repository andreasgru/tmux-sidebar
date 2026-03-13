# Tmux Sidebar Design

**Date:** 2026-03-13

**Goal:** Build a tmux plugin that toggles a right-hand sidebar showing a session/window/pane tree, with pane-level badges for Claude, Codex, and OpenCode activity.

## Summary

The plugin renders a plain-text sidebar inside a dedicated tmux pane. It shows tmux sessions, windows, and panes in a nested tree, similar to the user's current sidebar, but extended to include panes and pane-level agent status.

Agent status is driven by explicit app hooks, not by process inspection or output parsing. Each supported app writes pane-specific state into a shared local state directory. The sidebar renderer reads that state and decorates panes with transient badges such as `needs-input` and `done`. Those transient badges clear automatically when the user focuses the pane.

## Chosen Approach

Variant 1 was selected: a pure tmux plugin backed by file state.

### Why this variant

- Hook integrations already exist conceptually through app hook systems like the current `peon-ping` setup.
- The tmux plugin can stay independent from any one app implementation.
- File-backed state is simple to inspect, debug, and test.
- No background daemon is required.
- Focus-based clearing is straightforward with tmux hooks.

### Rejected variants

- Pure inference from pane contents or running processes is not reliable enough.
- Tmux user options are attractive but harder to update reliably from external hook invocations.
- A local daemon is more infrastructure than the first version needs.

## UX

- Toggle key: `<prefix>S`
- Sidebar placement: right side of the current tmux client
- Sidebar type: dedicated tmux pane owned by the plugin
- Default width: fixed, configurable later if needed
- Rendering style: plain text tree, no special dependencies

### Visual structure

- Session line
- Window lines indented under each session
- Pane lines indented under each window

Each pane line includes:

- Pane index or tmux pane id
- Pane title or current command
- Compact app label when state exists: `claude`, `codex`, or `opencode`
- Status badge for `running`, `needs-input`, `done`, or `error`
- Active marker for the currently focused session/window/pane

## Architecture

### Plugin entrypoints

- `sidebar.tmux`
  - Installs key bindings
  - Registers tmux hooks
  - Defines plugin options
- `scripts/toggle-sidebar.sh`
  - Opens or closes the dedicated sidebar pane
- `scripts/render-sidebar.sh`
  - Reads tmux metadata and pane state, then prints the tree
- `scripts/update-pane-state.sh`
  - Shared hook helper that updates pane state atomically
- `scripts/clear-pane-state.sh`
  - Clears transient status when a pane gains focus

### State storage

The plugin stores pane state under a local directory such as:

- `~/.tmux-sidebar/state/`

State is keyed by pane id. A flat structure is sufficient for v1:

- `pane-%123.json`

Each pane state file contains:

- `pane_id`
- `session_name`
- `window_id`
- `window_name`
- `app`
- `status`
- `updated_at`
- `message`

### Status model

Supported statuses:

- `idle`
- `running`
- `needs-input`
- `done`
- `error`

Transient statuses:

- `needs-input`
- `done`

Persistent until replaced:

- `running`
- `error`

If multiple updates race, the newest `updated_at` wins.

## Runtime Flow

### Hook update flow

1. Claude, Codex, or OpenCode emits a hook event.
2. The app-specific hook script calls `scripts/update-pane-state.sh`.
3. The helper resolves the target pane and tmux metadata.
4. The helper writes the updated pane state atomically.
5. The sidebar pane refreshes and displays the new badge.

Example call shape:

```bash
scripts/update-pane-state.sh \
  --pane "$TMUX_PANE" \
  --app claude \
  --status needs-input \
  --message "Permission request"
```

### Focus clearing flow

1. Tmux focus changes to a pane.
2. A tmux hook invokes `scripts/clear-pane-state.sh <pane_id>`.
3. The helper removes only transient statuses for that pane.
4. `running` and `error` remain intact.

### Render flow

The renderer combines:

- `tmux list-sessions`
- `tmux list-windows`
- `tmux list-panes`
- Pane state files in `~/.tmux-sidebar/state/`

It then prints a nested tree with badges and active markers.

## Error Handling

- If a hook fires without a valid pane id, the update is ignored cleanly.
- If tmux metadata for a pane cannot be resolved, the update helper exits without corrupting state.
- If a pane state file is malformed, the renderer skips it and continues.
- If a pane no longer exists, its stale state file is removed during render or cleanup.
- If the sidebar pane is missing, toggle recreates it.
- If an app has no hook integration yet, its pane simply has no badge.

## Testing Strategy

Implementation should follow TDD.

### State update tests

- Writes the expected pane state file for a valid pane
- Rejects missing or invalid pane identifiers safely
- Prefers newer timestamps over older updates

### Clear-on-focus tests

- Clears `done`
- Clears `needs-input`
- Preserves `running`
- Preserves `error`

### Render tests

- Produces nested `session -> window -> pane` output
- Displays badges for matching pane state
- Marks active pane correctly
- Ignores or prunes stale pane state

### Toggle tests

- Opens the sidebar when absent
- Closes the sidebar when present
- Identifies the dedicated sidebar pane without closing unrelated panes

## Constraints and Assumptions

- The current workspace is not a git repository, so this design document cannot be committed here.
- The first version should prioritize portability and simple shell-based implementation.
- Hook integration for each supported app will conform to the same pane-status contract.

## Next Step

Create a detailed implementation plan covering plugin bootstrap, state helpers, rendering, toggle behavior, and tests using test-first steps.
