#!/bin/bash
set -euo pipefail

# Opens the durable automation Chrome profile on the services that should stay
# logged in for browser automation.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT_DIR/bin/start-chrome-person1-debug.sh"

"$LAUNCHER" "https://www.instagram.com/"

sleep 2

open -na "Google Chrome" --args \
  --user-data-dir="$HOME/Library/Application Support/Google/Chrome-OpenClawAutomation" \
  --profile-directory=Default \
  --new-tab "https://x.com/" \
  --new-tab "https://mail.google.com/" \
  --new-tab "https://www.notion.so/" \
  --new-tab "https://www.canva.com/" \
  --new-tab "https://chatgpt.com/"
