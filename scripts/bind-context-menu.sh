#!/usr/bin/env bash
set -euo pipefail

CDPATH= cd -- "$(dirname "$0")" || exit 1
. ./lib.sh
SCRIPTS_DIR="$(pwd)"
SIDEBAR_STATE="$(print_state_dir)"

# Write a tmux command file that registers our MouseDown3Pane binding.
# We source-file it because the binding uses { } blocks that bash can't pass directly.
bind_file="$SIDEBAR_STATE/bind-mouse.tmux"
mkdir -p "$SIDEBAR_STATE"

cat > "$bind_file" <<TMUX
bind-key -T root MouseDown3Pane if-shell -F "#{m:Sidebar,#{pane_title}}" { if-shell "bash $SCRIPTS_DIR/show-context-menu.sh #{pane_id} #{mouse_y}" { source-file "$SIDEBAR_STATE/menu-cmd.tmux" } } { if-shell -F -t= "#{||:#{mouse_any_flag},#{&&:#{pane_in_mode},#{?#{m/r:(copy|view)-mode,#{pane_mode}},0,1}}}" { select-pane -t= ; send-keys -M } { display-menu -T "#[align=centre]#{pane_index} (#{pane_id})" -t= -xM -yM "Horizontal Split" h { split-window -h } "Vertical Split" v { split-window -v } "" "" "" "Swap Up" u { swap-pane -U } "Swap Down" d { swap-pane -D } "" "" "" Kill X { kill-pane } Respawn R { respawn-pane -k } "#{?pane_marked,Unmark,Mark}" m { select-pane -m } "#{?window_zoomed_flag,Unzoom,Zoom}" z { resize-pane -Z } } }
TMUX

tmux source-file "$bind_file"
