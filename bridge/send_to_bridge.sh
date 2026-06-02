#!/usr/bin/env bash
set -euo pipefail

# Send a prompt to a running visible OpenClaw bridge's input fifo.
# The bridge will inject it (as if typed + Enter) into the inner openclaw session.
#
# Usage:
#   ./bridge/send_to_bridge.sh "exact prompt text here"
#   echo "multi line
#   prompt" | ./bridge/send_to_bridge.sh
#
# Or override the root:
#   OPENCLAW_BRIDGE_ROOT=~/.openclaw-person1/sessions/lead-scout/state ./bridge/send_to_bridge.sh "..."

ROOT="${OPENCLAW_BRIDGE_ROOT:-$HOME/.openclaw-person1/sessions/director/state}"
FIFO="$ROOT/input.fifo"

if [[ ! -p "$FIFO" ]]; then
  echo "Bridge input pipe is not running: $FIFO" >&2
  echo "Start the bridge first (see start_visible_openclaw_bridge.sh)." >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  printf '%s\r' "$*" > "$FIFO"
else
  data="$(cat)"
  printf '%s\r' "$data" > "$FIFO"
fi
