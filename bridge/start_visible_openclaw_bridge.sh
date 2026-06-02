#!/usr/bin/env bash
set -euo pipefail

# Visible OpenClaw Bridge launcher (for Person 1 / real Chrome automation)
#
# This starts the python PTY bridge that keeps an `openclaw` agent/TUI session
# alive in the background (e.g. the "director" lane).
#
# The bridge lets an outer controller feed prompts into the inner agent
# (by writing to input.fifo) and gives a full transcript.log for review.
#
# Typical for director (persistent priority / outreach manager):
#   OPENCLAW_BRIDGE_ROOT="$HOME/.openclaw-person1/sessions/director/state" \
#   OPENCLAW_BRIDGE_CWD="$HOME/person1-openclaw-automation" \
#   ./bridge/start_visible_openclaw_bridge.sh openclaw tui --session director
#
# Or with the wrapper defaults (edit below):
#   ./bridge/start_visible_openclaw_bridge.sh
#
# The inner agent will have access to browser tools attached to your
# real "Person 1" Chrome (the one launched with remote-debugging-port=9222
# on the Chrome-OpenClawAutomation profile).
#
# Prerequisites:
#   - Chrome debug running: see ../bin/start-chrome-person1-debug.sh
#   - openclaw gateway running (usually on 18789)
#   - Good Node active (script forces nvm 22.19+ inside the bridge)
#
# To send input from another terminal / agent:
#   printf 'your prompt here\r' > "$ROOT/input.fifo"
#
# To tail transcript:
#   tail -f "$ROOT/transcript.log"
#
# Safety: Make sure any agent running inside has strong "never send/click
# external without explicit GA/approval + exact text" rules.

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use --delete-prefix 22 --silent 2>/dev/null || true
if command -v nvm >/dev/null 2>&1; then
  NODE_BIN=$(nvm which current 2>/dev/null || echo "")
  if [ -n "$NODE_BIN" ] && [ -d "$(dirname "$NODE_BIN")" ]; then
    export PATH="$(dirname "$NODE_BIN"):$PATH"
  fi
fi

# --- Defaults (override via env vars) ---
# State dir for this session's fifo + transcript. One per persistent agent lane.
DEFAULT_ROOT="$HOME/.openclaw-person1/sessions/director/state"

# CWD for the openclaw process. Usually the repo root or a Codex work dir
# that contains any project-specific prompts, skills, or handoff files.
DEFAULT_CWD="$HOME/person1-openclaw-automation"

ROOT="${OPENCLAW_BRIDGE_ROOT:-$DEFAULT_ROOT}"
CWD="${OPENCLAW_BRIDGE_CWD:-$DEFAULT_CWD}"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/visible_openclaw_bridge.py"

mkdir -p "$ROOT"

# If extra args given, pass them (e.g. "openclaw tui --session foo")
if [ $# -gt 0 ]; then
  exec python3 "$SCRIPT" --root "$ROOT" --cwd "$CWD" --command "$@"
else
  # Default: director TUI session (common case)
  exec python3 "$SCRIPT" --root "$ROOT" --cwd "$CWD" --command openclaw tui --session director
fi
