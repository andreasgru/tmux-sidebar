# Tmux Sidebar Global Client Design

**Date:** 2026-03-13

**Goal:** Replace the pane-based sidebar with a global, full-height left sidebar implemented as a separate tmux client, while keeping the sidebar open across session changes and making it keyboard-navigable.

## Why the current design is insufficient

The current sidebar is implemented as a tmux pane. A pane is always attached to a specific window, so it cannot satisfy these requirements at the same time:

- global across sessions and windows
- full terminal height
- persistent while switching between sessions
- navigable as its own UI without being tied to the active window layout

That makes the pane model the wrong primitive.

## Chosen architecture

The sidebar will become a dedicated tmux client attached to the same tmux server as the main workflow.

### High-level model

- The main tmux client remains the normal working client.
- A dedicated sidebar session/window hosts the sidebar UI.
- A second tmux client displays that sidebar window on the left.
- The sidebar content remains global by rendering all sessions, windows, and panes from the server.
- Toggling the sidebar shows or hides that dedicated client.

## Interaction model

### Toggle behavior

- `prefix + t` toggles the sidebar client on or off.
- Toggling does not move focus into the sidebar automatically.

### Sidebar navigation

Inside the sidebar client:

- `j/k` and arrow keys move the selection cursor
- `Enter` activates the selected pane in the main client
- `Ctrl+l` leaves the sidebar and returns focus to the main client without changing the selected pane

Selecting a pane:

- does not close the sidebar
- switches the main client to the target session/window/pane
- focuses that exact target pane in the main client

Leaving the sidebar:

- does not close the sidebar
- simply returns keyboard focus to the main client

## Sidebar UI model

The sidebar becomes an interactive TUI, not a passive one-shot renderer.

It needs:

- a tree model of sessions, windows, and panes
- a current selection
- a mapping from visible rows to pane targets
- commands for moving selection and activating the target

## Rendering model

Keep the structured Unicode tree model:

- `├─`, `└─`, and `│`
- sessions at the top level
- windows nested under sessions
- panes nested under windows
- badges for `running`, `needs-input`, `done`, and `error`
- a visible cursor/selection marker independent of the active pane marker

## Focus model

The system must distinguish:

- the active pane in the main client
- the selected row in the sidebar
- the last non-sidebar tmux client to return focus to

Store sidebar runtime state in tmux options or state files:

- sidebar client identifier
- sidebar session/window identifiers
- last main client identifier
- selected tree row or selected pane id

## Refresh model

Refresh remains event-driven.

Triggers:

- tmux structural events
- pane focus changes
- Claude hook updates
- Codex hook updates
- explicit sidebar navigation actions

The sidebar TUI process should re-render on state change instead of polling.

## Practical implementation direction

Use a dedicated tmux session/window for the sidebar navigator, and run a single interactive script inside it.

The script should:

- rebuild the tree model on demand
- render the current frame
- accept keyboard input for movement and activation
- call tmux commands to focus the main client on selection

## Risks and constraints

- This is no longer a simple renderer replacement. It is an interaction-model rewrite.
- A separate tmux client means normal pane navigation commands do not automatically cross between main and sidebar clients.
- The sidebar needs explicit “return to main client” behavior, which will be mapped to `Ctrl+l`.
- The implementation must identify or remember the main client reliably.

## Success criteria

- The sidebar stays visible while switching sessions in the main client.
- The sidebar occupies the full left side height.
- `prefix + t` only toggles visibility.
- The sidebar is keyboard navigable.
- `Enter` focuses the exact selected pane in the main client.
- `Ctrl+l` from inside the sidebar returns focus to the main client without activating a new pane.
- The sidebar remains non-flickering and event-driven.
