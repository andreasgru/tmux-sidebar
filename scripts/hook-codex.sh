#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPT_DIR/update-pane-state.sh}"
forward_notify="${TMUX_SIDEBAR_CODEX_NOTIFY_FORWARD:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/adapters/codex.sh}"

codex_event="${1:-}"
if [ -t 0 ]; then
  payload=""
else
  payload="$(cat)"
fi

if [ -x "$forward_notify" ]; then
  printf '%s' "$payload" | "$forward_notify" "$codex_event" || true
fi

parsed="$(
  CODEX_EVENT="$codex_event" PAYLOAD="$payload" python3 - <<'PY'
import json
import os

payload = os.environ.get("PAYLOAD", "").strip()
data = {}
if payload:
    try:
        loaded = json.loads(payload)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

raw_event = str(
    os.environ.get("CODEX_EVENT")
    or data.get("hook_event_name")
    or data.get("event")
    or data.get("type")
    or ""
).strip().lower().replace("_", "-")

notif_type = str(data.get("notification_type") or "").strip().lower()
message = str(data.get("summary") or data.get("transcript_summary") or data.get("message") or "").strip()

if (
    raw_event.startswith("permission")
    or raw_event.startswith("approve")
    or raw_event in ("approval-requested", "approval-needed", "input-required", "idle-prompt")
    or notif_type == "permission_prompt"
):
    status = "needs-input"
elif raw_event.startswith("error") or raw_event.startswith("fail"):
    status = "error"
elif raw_event in ("start", "session-start"):
    status = "running"
else:
    status = "done"

print(status)
print(message)
PY
)"

status="$(printf '%s\n' "$parsed" | sed -n '1p')"
message="$(printf '%s\n' "$parsed" | sed -n '2p')"

exec "$update_helper" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$status" \
  --message "$message"
