#!/usr/bin/env bash
set -euo pipefail

TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tmux-sidebar-tests.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

output=""
TEST_BIN="$TEST_TMP/bin"
mkdir -p "$TEST_BIN" "$TEST_TMP/tmux"
export PATH="$TEST_BIN:$PATH"
export TEST_TMUX_DATA_DIR="$TEST_TMP/tmux"
: > "$TEST_TMUX_DATA_DIR/list_panes.txt"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  if [ "$actual" != "$expected" ]; then
    fail "expected [$expected], got [$actual]"
  fi
}

run_script() {
  output="$(bash "$@" 2>&1)"
}

assert_file_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$path"; then
    fail "expected [$path] to contain [$expected]"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain [$needle]" ;;
  esac
}

fake_tmux_register_pane() {
  local pane_id="$1"
  local session_name="$2"
  local window_id="$3"
  local window_name="$4"
  local pane_title="$5"
  local pane_current_command="${6:-$5}"
  cat > "$TEST_TMUX_DATA_DIR/pane_${pane_id//%/}.meta" <<EOF
session_name=$session_name
window_id=$window_id
window_name=$window_name
pane_title=$pane_title
pane_current_command=$pane_current_command
EOF
}

fake_tmux_set_tree() {
  cat > "$TEST_TMUX_DATA_DIR/list_panes.txt"
}

fake_tmux_add_sidebar_pane() {
  local pane_id="$1"
  local window_id="$2"
  printf '%s|tmux-sidebar|%s\n' "$pane_id" "$window_id" >> "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
}

fake_tmux_no_sidebar() {
  : > "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
  printf '%%1\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"
  : > "$TEST_TMUX_DATA_DIR/commands.log"
  rm -f "$TEST_TMUX_DATA_DIR"/option_*.txt
}

fake_tmux_sidebar_count() {
  if [ ! -f "$TEST_TMUX_DATA_DIR/toggle_panes.txt" ]; then
    printf '0\n'
    return
  fi
  awk -F'|' '$2=="tmux-sidebar" { count++ } END { print count + 0 }' "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
}

fake_tmux_current_pane() {
  cat "$TEST_TMUX_DATA_DIR/current_pane.txt"
}

fake_tmux_register_main_pane() {
  printf '%s\n' "$1" > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_main_pane.txt"
}

assert_file_not_contains() {
  local path="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$path"; then
    fail "expected [$path] to not contain [$unexpected]"
  fi
}

cat > "$TEST_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

data_dir="${TEST_TMUX_DATA_DIR:?}"
command_name="${1:-}"
shift || true

case "$command_name" in
  display-message)
    format=""
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -p) shift ;;
        -t) target="$2"; shift 2 ;;
        *) format="$1"; shift ;;
      esac
    done
    if [ -z "$target" ] && [ "$format" = '#{pane_id}' ]; then
      cat "$data_dir/current_pane.txt"
      exit 0
    fi
    if [ -z "$target" ] && [ "$format" = '#{window_id}' ]; then
      current_pane="$(cat "$data_dir/current_pane.txt")"
      meta_file="$data_dir/pane_${current_pane//%/}.meta"
      [ -f "$meta_file" ] || exit 1
      . "$meta_file"
      printf '%s\n' "$window_id"
      exit 0
    fi
    if [ -z "$target" ] && [ "$format" = '#{pane_title}' ]; then
      current_pane="$(cat "$data_dir/current_pane.txt")"
      meta_file="$data_dir/pane_${current_pane//%/}.meta"
      [ -f "$meta_file" ] || exit 1
      . "$meta_file"
      printf '%s\n' "$pane_title"
      exit 0
    fi
    meta_file="$data_dir/pane_${target//%/}.meta"
    [ -f "$meta_file" ] || exit 1
    . "$meta_file"
    result="$format"
    result="${result//\#\{session_name\}/$session_name}"
    result="${result//\#\{window_id\}/$window_id}"
    result="${result//\#\{window_name\}/$window_name}"
    result="${result//\#\{pane_title\}/$pane_title}"
    result="${result//\#\{pane_current_command\}/$pane_current_command}"
    if [ "$target" = "$(cat "$data_dir/current_pane.txt")" ]; then
      result="${result//\#\{pane_active\}/1}"
    else
      result="${result//\#\{pane_active\}/0}"
    fi
    printf '%s\n' "$result"
    ;;
  list-panes)
    format="${*: -1}"
    if [[ "$format" == '#{pane_id}|#{pane_title}' || "$format" == '#{pane_id}|#{pane_title}|#{window_id}' ]]; then
      cat "$data_dir/toggle_panes.txt"
    else
      cat "$data_dir/list_panes.txt"
    fi
    ;;
  split-window)
    printf 'split-window %s\n' "$*" >> "$data_dir/commands.log"
    current_pane="$(cat "$data_dir/current_pane.txt")"
    meta_file="$data_dir/pane_${current_pane//%/}.meta"
    window_id="@unknown"
    if [ -f "$meta_file" ]; then
      . "$meta_file"
    fi
    printf '%%99|tmux-sidebar|%s\n' "$window_id" >> "$data_dir/toggle_panes.txt"
    printf '%%99\n'
    ;;
  respawn-pane)
    printf 'respawn-pane %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  set-option)
    printf 'set-option %s\n' "$*" >> "$data_dir/commands.log"
    scope=""
    unset_flag="0"
    value=""
    option_name=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -g|-p)
          scope="$1"
          shift
          ;;
        -u)
          unset_flag="1"
          shift
          ;;
        *)
          if [ -z "$option_name" ]; then
            option_name="$1"
          elif [ -z "$value" ]; then
            value="$1"
          fi
          shift
          ;;
      esac
    done
    option_file="$data_dir/option_${option_name//@/_}.txt"
    if [ "$unset_flag" = "1" ]; then
      rm -f "$option_file"
    else
      printf '%s\n' "$value" > "$option_file"
    fi
    ;;
  show-options)
    option_name="${*: -1}"
    if [ "$option_name" = "-g" ]; then
      for option_file in "$data_dir"/option_*.txt; do
        [ -e "$option_file" ] || exit 0
        option_name="${option_file##*/option_}"
        option_name="${option_name%.txt}"
        option_name="@${option_name#_}"
        printf '%s "%s"\n' "$option_name" "$(cat "$option_file")"
      done
      exit 0
    fi
    option_file="$data_dir/option_${option_name//@/_}.txt"
    if [ ! -f "$option_file" ]; then
      printf 'invalid option: %s\n' "$option_name" >&2
      exit 1
    fi
    cat "$option_file"
    ;;
  set)
    printf 'set %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  kill-pane)
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -f "$data_dir/toggle_panes.txt" ]; then
      grep -Fv "${target}|tmux-sidebar" "$data_dir/toggle_panes.txt" > "$data_dir/toggle_panes.txt.next" || true
      mv "$data_dir/toggle_panes.txt.next" "$data_dir/toggle_panes.txt"
    fi
    ;;
  select-pane)
    printf 'select-pane %s\n' "$*" >> "$data_dir/commands.log"
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target="$2"
          shift 2
          ;;
        -T)
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "$target" ]; then
      printf '%s\n' "$target" > "$data_dir/current_pane.txt"
    fi
    ;;
  select-window)
    printf 'select-window %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  switch-client)
    printf 'switch-client %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  *)
    echo "unsupported fake tmux command: $command_name" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$TEST_BIN/tmux"
