#!/bin/zsh
# lib/memory.sh — Read/write long-term memory helpers

source "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/common.sh"

# ── Read helpers ──────────────────────────────────────────────────────────────

read_profile() {
  cat "$RUNNER_MEMORY/profile.md" 2>/dev/null || echo "(no profile — run kiro-init)"
}

read_preferences() {
  cat "$RUNNER_MEMORY/preferences.md" 2>/dev/null || echo "(no preferences — run kiro-init)"
}

read_learnings() {
  cat "$RUNNER_MEMORY/learnings.md" 2>/dev/null || echo "(no learnings yet)"
}

read_long_term_decisions() {
  cat "$RUNNER_MEMORY/decisions.md" 2>/dev/null || echo "(no decisions yet)"
}

# ── Write helpers ─────────────────────────────────────────────────────────────

append_learning() {
  local job_name="$1"
  local summary="$2"
  local outcome="$3"  # success | blocked | partial

  ensure_dir "$RUNNER_MEMORY"
  cat >> "$RUNNER_MEMORY/learnings.md" <<EOF

## Job: $job_name ($(ts_date)) — $outcome
$summary
EOF
  log_info "Learning appended to $RUNNER_MEMORY/learnings.md"
}

append_long_term_decision() {
  local context="$1"
  local decision="$2"

  ensure_dir "$RUNNER_MEMORY"
  cat >> "$RUNNER_MEMORY/decisions.md" <<EOF

### $(ts_date): $context
$decision
EOF
}

# ── Profile summary for injection into prompts ────────────────────────────────

profile_context() {
  local profile preferences
  profile=$(read_profile)
  preferences=$(read_preferences)

  cat <<EOF
## Founder Profile (long-term memory)
$profile

## Working Preferences
$preferences
EOF
}
