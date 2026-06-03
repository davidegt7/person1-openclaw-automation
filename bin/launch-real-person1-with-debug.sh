#!/bin/bash
set -euo pipefail

echo "=== Launch daily Person 1 Chrome with remote debugging for OpenClaw ==="
echo "This will start your *main* Chrome (Default profile) with --remote-debugging-port=9222"
echo "IMPORTANT: Quit your current Chrome completely first (fully, not just windows)."
echo "Chrome should restore your tabs after launch."
echo ""
echo "Use this when you want the automation to see your *exact* daily Person 1 session"
echo "(all your open tabs, cookies, logins for X, Gmail, Notion, Google Sheets, etc.)."
echo "Alternative: the dedicated profile launcher (start-chrome-person1-debug.sh) for isolation."
echo ""

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
USER_DATA="/Users/david/Library/Application Support/Google/Chrome"

exec "$CHROME" \
  --user-data-dir="$USER_DATA" \
  --profile-directory="Default" \
  --remote-debugging-port=9222 \
  --no-first-run \
  --no-default-browser-check \
  --disable-features=MediaRouter,Translate \
  "$@"
