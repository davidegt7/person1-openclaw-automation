#!/usr/bin/env python3
"""
Visible OpenClaw Bridge

A PTY + FIFO bridge that runs a long-lived `openclaw` (TUI or agent) process
in the background while allowing an external controller (e.g. another agent,
script, or Grok session) to inject prompts via a named pipe (fifo) and
capture the full transcript.

This is the mechanism used for persistent "director", "lead-scout", etc.
agent lanes that stay alive, keep model context, and can perform multi-turn
work (especially browser automation on a real logged-in Chrome profile).

Key features for realistic automation (Instagram DMs, etc.):
- The inner openclaw agent uses real keyboard/mouse level input
  (page.keyboard.type char-by-char + random delays, hover/click realism).
- No direct DOM injection or bulk .type() for sensitive sites.
- Full transcript is logged for audit / resumption.

Usage (typical):
  python visible_openclaw_bridge.py \
    --root "$HOME/.openclaw-person1/sessions/director/state" \
    --cwd "$HOME/person1-openclaw-automation" \
    --command openclaw tui --session director

Environment (used by the wrapper start script):
  OPENCLAW_BRIDGE_ROOT  - state dir (contains input.fifo, transcript.log, status.txt)
  OPENCLAW_BRIDGE_CWD   - working dir for the openclaw process

The bridge forces a known-good Node (via nvm 22.19+) because openclaw
agent execution and browser tools are sensitive to Node version.

Safety: the agent prompts running inside must still contain explicit
"do not send without approval" / GA gates for any external actions.
"""

import argparse
import datetime as dt
import errno
import os
import pty
import select
import signal
import sys
import termios
import time
import tty


def stamp():
    return dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def append_line(path, text):
    with open(path, "a", encoding="utf-8", errors="replace") as f:
        f.write(text)
        if not text.endswith("\n"):
            f.write("\n")


def fifo_input_to_pty(data):
    if not data:
        return data
    if data.endswith(b"\r"):
        return data
    if data.endswith(b"\n"):
        return data[:-1] + b"\r"
    return data + b"\r"


def ensure_fifo(path):
    if os.path.exists(path):
        if not stat_is_fifo(path):
            raise RuntimeError(f"Input path exists and is not a FIFO: {path}")
        return
    os.mkfifo(path)


def stat_is_fifo(path):
    import stat
    return stat.S_ISFIFO(os.stat(path).st_mode)


def main():
    parser = argparse.ArgumentParser(description="Visible OpenClaw bridge for persistent agent sessions.")
    parser.add_argument("--root", required=True, help="Bridge state directory (fifo + transcript).")
    parser.add_argument("--cwd", required=True, help="Working directory for openclaw process.")
    parser.add_argument("--command", default="openclaw", help="Command to run (usually openclaw).")
    parser.add_argument("command_args", nargs=argparse.REMAINDER, help="Arguments for the command (e.g. tui --session director).")
    args = parser.parse_args()

    os.makedirs(args.root, exist_ok=True)
    input_fifo = os.path.join(args.root, "input.fifo")
    transcript = os.path.join(args.root, "transcript.log")
    status = os.path.join(args.root, "status.txt")

    ensure_fifo(input_fifo)
    append_line(transcript, f"\n===== bridge started {stamp()} =====")
    append_line(transcript, f"cwd: {args.cwd}")
    command = [args.command, *args.command_args]
    append_line(transcript, f"command: {' '.join(command)}")
    append_line(status, f"{stamp()} running pid={os.getpid()}")

    print("")
    print("Visible OpenClaw bridge is running.")
    print(f"Input pipe: {input_fifo}")
    print(f"Transcript: {transcript}")
    print("")
    print("External controller can send prompts by writing to the input pipe.")
    print("Everything shown here (and inside the openclaw session) is captured in the transcript.")
    print("")

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(args.cwd)
        # Force good Node (>=22.19) for openclaw CLI and any sub-commands the agent runs.
        # Critical for agent tool calling, browser CDP, etc.
        good_node_dir = os.path.expanduser("~/.nvm/versions/node/v22.19.0/bin")
        if os.path.isdir(good_node_dir):
            os.environ["PATH"] = good_node_dir + ":" + os.environ.get("PATH", "")
        os.execvp(args.command, command)

    old_tty = None
    stdin_fd = sys.stdin.fileno()
    try:
        if sys.stdin.isatty():
            old_tty = termios.tcgetattr(stdin_fd)
            tty.setraw(stdin_fd)
    except Exception:
        old_tty = None

    fifo_fd = os.open(input_fifo, os.O_RDONLY | os.O_NONBLOCK)
    keepalive_fd = os.open(input_fifo, os.O_WRONLY | os.O_NONBLOCK)

    def shutdown(signum=None, frame=None):
        append_line(transcript, f"\n===== bridge stopped {stamp()} =====")
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
        if old_tty is not None:
            try:
                termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)
            except Exception:
                pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    while True:
        try:
            done_pid, _ = os.waitpid(pid, os.WNOHANG)
            if done_pid == pid:
                append_line(transcript, f"\n===== child exited {stamp()} =====")
                break
        except ChildProcessError:
            break

        read_fds = [fd, fifo_fd]
        if sys.stdin.isatty():
            read_fds.append(stdin_fd)

        readable, _, _ = select.select(read_fds, [], [], 0.1)

        if fd in readable:
            try:
                data = os.read(fd, 4096)
            except OSError as exc:
                if exc.errno in (errno.EIO, errno.EBADF):
                    break
                raise
            if not data:
                break
            os.write(sys.stdout.fileno(), data)
            with open(transcript, "ab") as f:
                f.write(data)

        if fifo_fd in readable:
            try:
                data = os.read(fifo_fd, 4096)
            except BlockingIOError:
                data = b""
            if data:
                marker = f"\n\n===== controller input {stamp()} =====\n".encode()
                with open(transcript, "ab") as f:
                    f.write(marker)
                    f.write(data)
                    if not data.endswith(b"\n"):
                        f.write(b"\n")
                os.write(fd, fifo_input_to_pty(data))

        if stdin_fd in readable:
            data = os.read(stdin_fd, 4096)
            if data:
                os.write(fd, data)

        time.sleep(0.01)

    shutdown()


if __name__ == "__main__":
    main()
