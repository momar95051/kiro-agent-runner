#!/bin/zsh
# lib/tmux.sh — Exact-match tmux targets and Claude Code readiness/submit helpers
#
# tmux resolves a bare `-t name` by prefix when no session is named exactly
# `name`, so `kill-session -t worker` can kill `worker-startup-ideas`.
# Always target sessions as `=name` and panes as `=name:`.

tmux_has()     { tmux has-session  -t "=$1" 2>/dev/null; }
tmux_kill()    { tmux kill-session -t "=$1" 2>/dev/null; }
tmux_capture() { tmux capture-pane -t "=$1:" -p 2>/dev/null; }
tmux_keys()    { local s="$1"; shift; tmux send-keys -t "=$s:" "$@" 2>/dev/null; }

# Claude Code's folder trust dialog
_claude_trust_prompt() { grep -q "Yes, I trust this folder"; }

# Trust dialog with "Yes" highlighted (options are unnumbered; "No, exit" is
# highlighted by default)
_claude_trust_yes_selected() { grep -qE '❯ +Yes, I trust this folder'; }

# Claude Code's input box is ready. Match Claude's own footer, not a bare `❯`,
# which many shell prompts also use.
_claude_input_ready() { grep -qE 'bypass permissions on|\? for shortcuts'; }

# Claude Code is working on a submitted turn
_claude_busy() { grep -qE 'esc to interrupt|Goal set'; }

# Wait until Claude Code in <session> is at an empty input prompt.
# Accepts the folder trust dialog once if it appears. Returns 1 on timeout.
claude_wait_ready() {
  local session="$1" timeout="${2:-60}" screen accepted=false i
  for i in $(seq 1 "$timeout"); do
    screen=$(tmux_capture "$session")
    if echo "$screen" | _claude_trust_prompt; then
      if [[ "$accepted" != "true" ]]; then
        log_warn "Trust prompt detected — accepting..."
        tmux_keys "$session" Down
        sleep 0.5
        if tmux_capture "$session" | _claude_trust_yes_selected; then
          tmux_keys "$session" Enter
          accepted=true
        else
          log_error "Could not select 'Yes, I trust this folder' — not confirming"
          return 1
        fi
      fi
    elif echo "$screen" | _claude_input_ready; then
      log_info "Claude Code is ready (${i}s)"
      return 0
    fi
    sleep 1
  done
  return 1
}

# Type <text> into Claude Code's input box and make sure it was submitted.
# An Enter sent while the TUI is still processing pasted text can be dropped,
# leaving the text sitting in the input box, so retry Enter until Claude
# shows it is working.
claude_submit() {
  local session="$1" text="$2" attempt
  tmux_keys "$session" -l "$text"
  sleep 1
  for attempt in 1 2 3 4 5; do
    tmux_keys "$session" Enter
    sleep 3
    if tmux_capture "$session" | _claude_busy; then
      return 0
    fi
  done
  return 1
}
