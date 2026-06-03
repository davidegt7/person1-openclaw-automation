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

## Essential Commands & Usage for B-roll Library + Creator Outreach (Current Active Work)

This repo's Chrome + bridge setup is the foundation for two main ongoing projects:

1. **Bitcoin Media Asset Library** — building and maintaining 30+ evergreen reusable b-roll assets (mining rigs, spinning coins, trading screens, macro networks, etc.) for turning long-form podcast/YouTube episodes into shorts/reels. Assets live on the volume at `/Volumes/2 TB WD /Video Editing/Bitcoin Media Asset Library/` (and mirrored in Codex outputs/). Strict naming, CSV metadata in 90_METADATA/, project packs in 05_PROJECT_READY_PACKS/.

2. **Creator Video Editing Lead Outreach** — discovering podcasters/YouTubers (finance, crypto/Bitcoin, mental health, entrepreneurship niches) via X tools, maintaining the master list in `creator_video_editing_leads.xlsx` + `.csv` (45 leads total, managed via `build_leads.mjs` in the work/ dirs), preparing *unique varied human-sounding* DMs/emails (no templates), sending via the real Person 1 Chrome (X app DM composer or email), updating the spreadsheet and Notion (Creator-Outreach-Project-Files page), logging everything.

The "director" persistent agent + one-shot `openclaw agent` runs with specific `--session-key` use the Person 1 Chrome (via `profile="user"` or existing-session attach to the 9222 instance) for realistic browser work.

### Launching the Right Chrome (pick one; must be running for any "user" attach)

**Dedicated automation profile (clean separation, recommended for most scripted work):**

```bash
~/person1-openclaw-automation/bin/start-chrome-person1-debug.sh &
```

**Real daily "Person 1" profile (sees your exact open tabs, cookies, logged-in X/Gmail/Notion/Sheets state — used heavily for outreach DMs):**

```bash
~/person1-openclaw-automation/bin/launch-real-person1-with-debug.sh &
```

**Always:**
- Quit *all* Chrome instances completely first (not just windows) so the port is free and tabs can restore.
- Verify:
  ```bash
  curl -s http://127.0.0.1:9222/json/version | head -c 200
  ```
- Keep the window/profile running (can minimize) while agents run.
- Open your target tabs in *that* profile beforehand (the Canva design, x.com, the Notion page, the Google Sheet version of the leads xlsx) for the agent to target specific tabs by ref or URL.

### Running the Bridge for Persistent "Director" / Long-running Outreach Agent

See the Visible OpenClaw Bridge section above for launch.

Common for director (the persistent brain that does research + surfaces exact messages for GA):

```bash
OPENCLAW_BRIDGE_ROOT="$HOME/.openclaw-person1/sessions/director/state" \
OPENCLAW_BRIDGE_CWD="$HOME/person1-openclaw-automation" \
./bridge/start_visible_openclaw_bridge.sh
```

Feed it from another terminal / outer agent / Codex:

```bash
./bridge/send_to_bridge.sh 'Status report or next prompt with full exact approved text here'
./bridge/capture_bridge.sh 100
```

The inner agent gets the browser tools on your Person 1 Chrome + full history.

### One-shot or Resumable `openclaw agent` for Specific Batches (Direct, No Bridge)

These use a named `--session-key` for trajectory continuity across turns (great for long tasks like downloading 10-20 b-roll or processing a batch of 10 leads).

**For Canva / real editor b-roll automation (the original hard problem):**

Use or adapt the resume script pattern from the workspace:

```bash
env OPENCLAW_STATE_DIR="/path/to/your/work/openclaw-state" \
  openclaw agent \
  --agent main \
  --session-key "agent:main:canva-bitcoin-broll-direct" \
  --thinking medium \
  --timeout 3600 \
  --message "Chrome with remote debugging (port 9222, the right profile) is running and the target Canva design tab is open. Use the real browser tool / Canva editor (not just connector). Search Videos for queries like 'bitcoin mining rig farm', 'bitcoin spinning coin loop', etc. Download MP4 1080p. Process files: move from Downloads, rename per convention (broll_..._canva_2026-06-02_NNN.mp4), append to 90_METADATA CSVs exactly matching seed style, mv to correct 02_BROLL subfolder, update sources.txt + handoff md, verify counts. Do not overwrite."
```

(Full prompts are in the workspace resume-canva-broll-agent.sh and related handoff mds. Inspect the library README + CSVs first.)

**For Creator Outreach DM / Notion / Sheet batch (the 10 X leads):**

```bash
openclaw agent --agent main --session-key "outreach-x-leads-10-more-2026-06-02" \
  --thinking medium --timeout 3600 \
  --message "The creator_video_editing_leads.xlsx and CSV have been updated with 10 new leads from X research (the highest numbered ones...). 

The 10 are: [list with handles, YT, niche]

Read the xlsx for full details, emails if any (mostly use X), why qualified, suggested subject/angle.

Task:
- Use the browser tool (openclaw profile, CDP if needed) to go to x.com.
- For each of the 10, search or go to their profile by handle.
- Send a unique, natural, human-sounding DM (not template-like, switch up greeting, hook from their recent content or bio, the value of editing long form to shorts/reels for growth, personal touch, soft offer like 'happy to make a free sample clip from one of your recent episodes or a specific post you made about content').
- Vary the wording, length, angle for each so they don't seem from a bot or mass campaign. Reference something specific if possible from their X.
- After sending each, note it.
- Also, open the Notion Creator Outreach page (...), and add the 10 new leads as new entries or database items with key fields (name, X, niche, why, status 'X DM sent [date]', etc.).
- If email is in the lead data, craft a varied email body..., and if possible 'send' or note the draft.
- Update the spreadsheet status column for these 10 to 'X DM sent 2026-06-02. Varied human-sounding message with sample offer. [any email if sent]'.
- Be careful not to spam or get rate limited; space if needed.
- Confirm at end by reading the sheet or reporting the sent messages summaries.

Use the openclaw browser tools for the X interactions and Notion. Switch up every message."
```

(The exact full prompt + the 10 varied DM texts the agent produced are in the workspace agent log and the varied_x_outreach_messages_2026-06-03.md. Always paste the *exact approved full text* into the message after user says GA.)

After the agent run, the local CSVs / xlsx will be updated (or guide the agent to do it via browser on the Google Sheet tab).

### Rebuilding / Maintaining the Lead Spreadsheet + Notion Import

The data lives in the JS array inside `work/lead_outreach/build_leads.mjs` (copies in the two main Codex project dirs — keep them in sync with cp after edits).

To add a new lead or batch:
- Research (X semantic/keyword/user searches + web for recent episodes + contact info).
- Append a new object to the `leads = [...]` array with all fields (especially unique `fit`, `angle`, `subject`, `status` with research date and contact method).
- Run the builder:
  ```bash
  cd /path/to/the/work/lead_outreach
  node build_leads.mjs
  ```
  This updates the xlsx (with Leads + Email Drafts + Summary sheets) and the csv (great for Notion import).

- Then hand-craft or extend the `varied_x_outreach_messages_*.md` with new unique messages (different structure, hooks, b-roll references where relevant for Bitcoin leads, sample offers).
- Update `additional_creator_leads.md` summary.
- Use `new_10_for_notion_import.csv` (or the full csv) to import into Notion.
- Get explicit GA on the exact texts before any send.
- After sends: update Status in the xlsx/csv/mjs, rebuild, update Notion.

See the main `HANDOFF_TO_GEMINI.md` (in your home and both Codex outputs/) for the current 45 leads, the two prepared varied batches, full file paths, and the exact 10 DM texts from the agent run.

### Syncing the Two Codex Workspaces + Library

After changes in one dir:
- For code/docs (mjs, md, csv, xlsx, handoff): use cp or rsync between the dated session dir and the david-ai-operations-os dir.
- For the Bitcoin library: run the `install_bitcoin_media_library_to_wd.sh` (or manual rsync -a --delete from the local outputs copy to the volume target).

Then consider committing updates here if they improve the automation core.

### Updating Notion and the Google Sheet Version

- The agent can open the Notion URL and the Google Sheet (open the xlsx via "Open with > Google Sheets" in the Person 1 Chrome tabs) and perform adds/updates via browser actions.
- Or do it manually after the agent run: import the csv, set Status to e.g. "X DM sent 2026-06-03 via app to @handle. Varied message with sample offer per agent transcript / varied md."
- The "spreadsheet" the user refers to is usually the Google Sheets live version; the local xlsx/csv are the source of truth generated from the mjs.

### Safety & Approval Gate (non-negotiable, baked into every prompt)

- Lead Scout / outreach rule: Research + draft/prep only. Human must explicitly approve the *exact recipient + platform + full message text* (the "GA" step) before any external action (X DM, email, post, etc.).
- The agent always surfaces the exact text for review.
- All actions are logged in transcripts.
- Never bypass for "speed".
- See full rules in your workspace AGENTS.md + MEMORY.md.

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
