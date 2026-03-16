#!/usr/bin/env bash
set -euo pipefail

CDPATH= cd -- "$(dirname "$0")" || exit 1
SCRIPT_DIR="$(pwd)"
. ./testlib.sh

SIDEBAR_UI="$SCRIPT_DIR/../scripts/sidebar-ui.py"

dump_menu() {
    python3 "$SIDEBAR_UI" --dump-menu-args "$@" 2>/dev/null
}

test_session_menu_contains_expected_items() {
    output="$(dump_menu session "main" "")"
    assert_contains "$output" "Switch to"
    assert_contains "$output" "Rename"
    assert_contains "$output" "New Window"
    assert_contains "$output" "Detach"
    assert_contains "$output" "Kill Session"
    assert_contains "$output" "confirm-before"
    assert_contains "$output" "main"
}

test_window_menu_contains_expected_items() {
    output="$(dump_menu window "main" "@3")"
    assert_contains "$output" "Select"
    assert_contains "$output" "Rename"
    assert_contains "$output" "New Window After"
    assert_contains "$output" "Split Horizontal"
    assert_contains "$output" "Split Vertical"
    assert_contains "$output" "Kill Window"
    assert_contains "$output" "@3"
}

test_pane_menu_contains_expected_items() {
    output="$(dump_menu pane "main" "%5")"
    assert_contains "$output" "Select"
    assert_contains "$output" "Zoom"
    assert_contains "$output" "Split Horizontal"
    assert_contains "$output" "Split Vertical"
    assert_contains "$output" "Break to Window"
    assert_contains "$output" "Mark"
    assert_contains "$output" "Kill Pane"
    assert_contains "$output" "%5"
}

test_session_name_with_spaces_is_quoted() {
    output="$(dump_menu session "my project" "")"
    assert_contains "$output" "'my project'"
}

test_menu_position_is_set() {
    output="$(dump_menu session "test" "")"
    assert_contains "$output" "10"
    assert_contains "$output" "5"
}

test_m_key_returns_context_menu_action() {
    output="$(python3 -c "
import sys; sys.path.insert(0, '$(dirname "$SIDEBAR_UI")')
from importlib.machinery import SourceFileLoader
mod = SourceFileLoader('sidebar_ui', '$SIDEBAR_UI').load_module()
result = mod.process_keypress(ord('m'), '%0', [], '', {})
print(result[2])
" 2>/dev/null)"
    assert_eq "$output" "context_menu"
}

test_get_pane_offset_fallback_without_tmux() {
    output="$(TMUX_PANE= python3 -c "
import sys; sys.path.insert(0, '$(dirname "$SIDEBAR_UI")')
from importlib.machinery import SourceFileLoader
mod = SourceFileLoader('sidebar_ui', '$SIDEBAR_UI').load_module()
print(mod.get_pane_offset())
" 2>/dev/null)"
    assert_eq "$output" "(0, 0)"
}

test_session_menu_contains_expected_items
test_window_menu_contains_expected_items
test_pane_menu_contains_expected_items
test_session_name_with_spaces_is_quoted
test_menu_position_is_set
test_m_key_returns_context_menu_action
test_get_pane_offset_fallback_without_tmux
