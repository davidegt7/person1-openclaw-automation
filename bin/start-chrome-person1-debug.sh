#!/bin/bash
set -euo pipefail

# Launches the persistent "Person 1" Chrome instance with remote debugging enabled.
# This is the browser profile used for "user" / existing-session attaches in OpenClaw.
# It preserves your real logins (Gmail, Instagram, etc.) in the Chrome-OpenClawAutomation profile.
#
# Why remote-debugging-port=9222?
#   - Allows OpenClaw (and the attached agents) to control/observe this Chrome via CDP.
#   - The "user" profile in openclaw.json / tools points at an already-running Chrome on this port.
#
# Usage:
#   ./bin/start-chrome-person1-debug.sh &
#   # or from anywhere:
#   ~/person1-openclaw-automation/bin/start-chrome-person1-debug.sh
#
# To kill later:
#   pkill -f "Chrome-OpenClawAutomation.*9222" || true
#
# IMPORTANT:
# - Keep this Chrome window/profile open while running automation agents that target "user".
# - Do not use this profile for your daily casual browsing if you want to keep automation separate.
# - The profile dir lives at: ~/Library/Application Support/Google/Chrome-OpenClawAutomation
# - Logs from launcher often go to /tmp/person1-launch.log or /tmp/auto-cdp.log (depending on caller)

USER_DATA_DIR="$HOME/Library/Application Support/Google/Chrome-OpenClawAutomation"
LOG_FILE="${TMPDIR:-/tmp}/person1-chrome-debug.log"

mkdir -p "$(dirname "$USER_DATA_DIR")"

echo "[$(date)] Starting Person 1 Chrome debug instance..." | tee -a "$LOG_FILE"

exec /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$USER_DATA_DIR" \
  --profile-directory=Default \
  >>"$LOG_FILE" 2>&1
