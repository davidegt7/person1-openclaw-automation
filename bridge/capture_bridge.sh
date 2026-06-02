#!/usr/bin/env bash
set -euo pipefail

# Tail the transcript of a running (or previous) visible OpenClaw bridge session.
# Useful for reviewing what the inner agent saw/did, debugging attach issues, etc.
#
# Usage:
#   ./bridge/capture_bridge.sh 200          # last 200 lines
#   ./bridge/capture_bridge.sh | less -S
#   tail -f $(./bridge/capture_bridge.sh --path)   # for live follow

ROOT="${OPENCLAW_BRIDGE_ROOT:-$HOME/.openclaw-person1/sessions/director/state}"
TRANSCRIPT="$ROOT/transcript.log"

if [[ "$1" == "--path" ]]; then
  echo "$TRANSCRIPT"
  exit 0
fi

if [[ ! -f "$TRANSCRIPT" ]]; then
  echo "No transcript yet: $TRANSCRIPT" >&2
  exit 1
fi

tail -n "${1:-120}" "$TRANSCRIPT"
