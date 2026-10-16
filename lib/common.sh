#!/bin/zsh
# lib/common.sh — Shared logging, colors, and path helpers

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo "${GREEN}✓${RESET} $*"; }
log_warn()    { echo "${YELLOW}⚠${RESET}  $*"; }
log_error()   { echo "${RED}✗${RESET} $*" >&2; }
log_step()    { echo "${BOLD}${BLUE}→${RESET} $*"; }
log_section() { echo ""; echo "${BOLD}$*${RESET}"; echo "${BLUE}$(printf '%.0s─' {1..50})${RESET}"; }

# ── Paths ─────────────────────────────────────────────────────────────────────
RUNNER_HOME="${KIRO_RUNNER_HOME:-$HOME/.kiro-runner}"
RUNNER_MEMORY="$RUNNER_HOME/memory"
RUNNER_ACTIVITY_LOG="$RUNNER_HOME/activity.log"

# Repo root (wherever this lib is)
RUNNER_REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Ensure a directory exists
ensure_dir() { mkdir -p "$1"; }

# Ask a yes/no question, return 0 for yes
confirm() {
  local prompt="${1:-Continue?}"
  local answer
  printf "${CYAN}?${RESET} ${prompt} [y/N] "
  read -r answer
  [[ "$answer" =~ ^[Yy] ]]
}

# Ask a question with a default value
ask() {
  local prompt="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    printf "${CYAN}?${RESET} ${prompt} [${default}]: "
  else
    printf "${CYAN}?${RESET} ${prompt}: "
  fi
  read -r answer
  echo "${answer:-$default}"
}

# Ask a multi-line question (end with empty line)
ask_multiline() {
  local prompt="$1"
  echo "${CYAN}?${RESET} ${prompt}"
  echo "  (enter multiple lines, blank line to finish)"
  local lines=()
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    lines+=("$line")
  done
  printf '%s\n' "${lines[@]}"
}

# Timestamp
ts() { date '+%Y-%m-%d %H:%M:%S'; }
ts_date() { date '+%Y-%m-%d'; }
