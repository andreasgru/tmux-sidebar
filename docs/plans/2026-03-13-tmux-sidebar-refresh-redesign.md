# Tmux Sidebar Refresh Redesign

**Date:** 2026-03-13

**Goal:** Move the sidebar to the left, remove polling-based flicker, and upgrade rendering to a structured Unicode tree.

## Design

- Sidebar placement moves from a right-side split to a left-side split.
- The infinite redraw loop is removed. The sidebar becomes event-driven.
- A dedicated refresh helper targets the sidebar pane and reruns the renderer only when needed.
- The renderer switches from streaming output directly from `list-panes` to a structured model:
  - collect sessions, windows, panes, and pane state
  - normalize into a tree
  - render using Unicode box-drawing characters

## Refresh model

Refresh triggers:

- opening the sidebar
- focus changes
- pane state updates from Claude/Codex hooks
- tmux hooks for pane/window/session changes

Refresh behavior:

- store the sidebar pane id in a tmux option
- `refresh-sidebar.sh` looks up that pane id and `respawn-pane -k` with a one-shot renderer command
- no periodic loop
- no full terminal clear

## Expected UX changes

- toggle remains on `<prefix>t`
- sidebar appears on the left
- tree uses `├─`, `└─`, and `│`
- random flicker from one-second polling disappears

## Implementation notes

- existing tests should be extended, not replaced
- rendering stability matters more than micro-optimizing shell commands
- the installed live plugin must be refreshed after workspace verification
