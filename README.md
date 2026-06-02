# person1-openclaw-automation

Automation bridge + Chrome debug setup for **Person 1** (your primary logged-in Chrome profile) using OpenClaw.

This repo captures the minimal, battle-tested pieces needed to run persistent, realistic browser agents against your real accounts (Instagram, Gmail, X, etc.) while keeping a strong human approval gate ("GA") before any external action.

## What "Person 1" means here

- A dedicated Chrome user data dir: `~/Library/Application Support/Google/Chrome-OpenClawAutomation`
- Launched with `--remote-debugging-port=9222`
- This is the instance that OpenClaw's `user` / `existing-session` profile attaches to.
- It carries your real cookies and logins. The automation agents (director, lead scouts, etc.) see the exact same tabs, sessions, and UI language as you do when you use it manually.

## Core components

### 1. Chrome debug launcher

`bin/start-chrome-person1-debug.sh`

- Starts the real Chrome on the automation profile with CDP debugging port open.
- Must be running (visible or minimized) for any "user" profile attach to succeed.
- You can have your normal Chrome(s) running at the same time; this is a separate profile.

Launch it in background:

```bash
./bin/start-chrome-person1-debug.sh &
# or
nohup ./bin/start-chrome-person1-debug.sh >/tmp/person1-chrome.log 2>&1 &
```

Check it's listening:

```bash
curl -s http://127.0.0.1:9222/json/version | head -c 200
```

### 2. Visible OpenClaw Bridge (the key piece)

`bridge/visible_openclaw_bridge.py` + `bridge/start_visible_openclaw_bridge.sh`

This is **not** the OpenClaw gateway or TUI itself.

It is a PTY + named-pipe (fifo) wrapper that:

- Forks and runs `openclaw tui --session <name>` (or any openclaw command) inside a pty.
- Exposes `input.fifo` so an external controller can inject full prompts (the outer Grok / Codex writes the next instruction here).
- Captures **everything** the inner openclaw session prints (tool calls, thoughts, snapshots, errors) into `transcript.log`.
- Forces Node 22.19+ (via nvm) because agent execution and browser tools are picky.

Why the bridge?

- Lets a long-running "director" agent stay alive with full conversation history and model context across many turns/hours/days.
- The outer system can drive it asynchronously by writing to the fifo instead of exec'ing a whole new openclaw chat every time.
- Gives a complete audit transcript (critical when the agent is touching real accounts).

Example launch for the Director lane:

```bash
mkdir -p ~/.openclaw-person1/sessions/director/state

OPENCLAW_BRIDGE_ROOT="$HOME/.openclaw-person1/sessions/director/state" \
OPENCLAW_BRIDGE_CWD="$HOME/person1-openclaw-automation" \
./bridge/start_visible_openclaw_bridge.sh
```

Then from anywhere (another terminal, a script, or the outer agent):

```bash
./bridge/send_to_bridge.sh 'Status report. What are you working on right now?'
./bridge/capture_bridge.sh 50
```

The inner agent (running inside openclaw tui --session director) has access to the full OpenClaw toolset, including browser actions on the attached Person 1 Chrome.

### 3. Helper scripts

- `bridge/send_to_bridge.sh` — push a prompt into the running session.
- `bridge/capture_bridge.sh` — read recent (or all) transcript output.

Both respect `OPENCLAW_BRIDGE_ROOT`.

## Realistic input / anti-detection notes

When the inner agent performs browser work on Instagram, X, etc. it is instructed to use only human-like methods:

- `page.keyboard.type("text", {delay: 30-120})` — one character at a time with jitter.
- Occasional 200-400ms pauses.
- Hover before click, small mouse moves, realistic timing.
- **No** `page.fill()`, no direct `element.value = ...`, no bulk paste that bypasses the editor model, no `evaluate` that mutates React state unless the site explicitly requires it and it has been proven safe.

This was developed after observing that Draft.js (X) and similar controlled editors require trusted hardware-level events for the internal model to update (so buttons enable and the real mutation fires).

The same principle applies to Instagram's "Mensaje" / message composer flows.

## Gateway

The OpenClaw gateway (usually `openclaw gateway --port 18789`) must be running for the TUI / agent sessions and for the browser plugin tools.

A launchd plist usually keeps it alive: `~/Library/LaunchAgents/ai.openclaw.gateway.plist`

Restart if needed:

```bash
openclaw gateway restart
```

## Typical workflow (Director + outreach)

1. Ensure Chrome Person 1 debug is running.
2. Ensure gateway is up.
3. Launch (or re-attach to) the director bridge.
4. Outer agent does research, drafts exact message + recipient + platform.
5. Outer agent surfaces a big "FOR APPROVAL" block with the exact text.
6. Human says "GA" (go ahead) or pastes the exact approved text.
7. Only then does the director (or a one-shot task) get told to execute the send using realistic input.
8. Everything is logged in the transcript for that session.

Never remove the approval gate.

## Chrome profile gotchas

- "Chrome MCP existing-session attach for profile 'user' could not connect" → the 9222 Chrome on the OpenClawAutomation profile is not running, or crashed, or another Chrome took the port.
- After gateway / config changes, start a **fresh** openclaw session (new --session name) so the sandbox/tool context picks up the new browser defaults.
- Snapshots can be slow; use them when you need the a11y/aria tree for clicking.

## Making this portable / your machine

The scripts use `$HOME` everywhere. Clone this repo to `~/person1-openclaw-automation` (or anywhere) and the launchers will still work as long as:

- You have nvm + Node 22.19+
- You have openclaw installed globally (`npm install -g openclaw` or equivalent)
- Your Chrome profile data lives where the launcher points (or edit the USER_DATA_DIR)

## Safety & red lines (copied from workspace AGENTS)

- No external actions (DMs, posts, follows, emails) without explicit "GA" + the exact payload shown back to the human first.
- The bridge + agent only make the *mechanism* reliable; the policy lives in the prompts.
- If the agent gets stuck (locator timeouts on "Mensaje", composer model not updating, etc.), it must stop and report rather than guess or force.

## Related

- OpenClaw docs / gateway / TUI (the installed `openclaw` binary)
- Your main workspace AGENTS.md, MEMORY.md, daily memory/ files
- The various dated Codex/ sessions that evolved these patterns (director, lead-scout-fresh, etc.)

---

This setup exists so you can have a persistent "second brain" director that can research, draft, and (only with your GA) execute real outreach and content work on your real accounts, using the same browser session you trust, with full transcripts and realistic input that respects the platforms' anti-bot signals as much as possible.
