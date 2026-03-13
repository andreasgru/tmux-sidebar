# Tmux Sidebar Mirrored Pane Design

**Date:** 2026-03-13

**Goal:** Implement a tmux-only left sidebar that behaves globally by mirroring itself into each visited window, stays full height, remains open across session/window changes, and supports interactive navigation.

## Why the separate-client plan is wrong here

The user is running Alacritty and wants a tmux-only solution with no external terminal integration. A separate tmux client would require focus behavior outside tmux's control, which breaks the `Ctrl+l` return-to-main expectation.

That makes the separate-client plan a mismatch for the actual constraints.

## Chosen architecture

Use a mirrored sidebar pane in each visited tmux window.

### Core model

- Every window that the user visits can host a left sidebar pane.
- The sidebar pane is recreated automatically when entering a window that does not yet have one.
- The sidebar pane occupies the full height of the window and sits on the left.
- The main content remains on the right.
- Toggling controls whether the mirrored sidebar should exist across windows.

This is not a single global tmux object. It is a synchronized per-window sidebar that behaves globally from the user's point of view.

## Interaction model

- `prefix + t` toggles the sidebar on or off globally
- if enabled, entering a window without a sidebar auto-creates it
- the sidebar stays open while moving between sessions/windows
- the sidebar can be focused manually
- inside the sidebar:
  - `j/k` or arrows move selection
  - `Enter` focuses the selected target pane
  - `Ctrl+l` moves focus out of the sidebar to the main pane in the same window
- selecting a pane does not close the sidebar

## Sidebar pane behavior

- left split with fixed width
- full window height
- dedicated pane title, for example `tmux-sidebar`
- one-shot/event-driven render, no polling loop
- per-window sidebar pane id tracked in tmux options or discoverable by title

## Synchronization model

Global enabled state:

- stored in a tmux global option such as `@tmux_sidebar_enabled`

Per-window sidebar runtime:

- tracked by pane title and/or pane-local option
- when visiting a window:
  - if sidebar is enabled and window lacks a sidebar pane, create one
  - if sidebar is disabled and window has a sidebar pane, remove it

## Rendering model

Use a structured Unicode tree renderer:

- sessions
- windows
- panes
- `├─`, `└─`, `│`
- selection cursor
- active pane marker
- badges for agent status

## Refresh model

Refresh remains event-driven:

- pane focus changes
- session/window changes
- pane creation and pane exit
- Claude hook updates
- Codex hook updates
- sidebar navigation actions

Refresh should target all visible sidebar panes or at least the sidebar pane for the current window.

## Focus behavior

Inside a sidebar pane:

- `Ctrl+l` should focus the main pane in that same window, not another client
- `Enter` should:
  - switch to the selected session/window
  - focus the selected pane
  - preserve sidebar presence in the destination window

## Success criteria

- sidebar appears on the left
- sidebar spans the full height of each window
- toggling once keeps it present while switching sessions/windows
- windows missing a sidebar get one automatically when entered
- no flicker or polling loop
- interactive tree navigation works
- `Ctrl+l` leaves the sidebar into the main pane
- `Enter` focuses the selected target pane and keeps the sidebar open
