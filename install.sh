#!/bin/zsh
# install.sh — Bootstrap kiro-agent-runner on a fresh machine
#
# Usage:
#   git clone https://github.com/<you>/kiro-agent-runner.git
#   cd kiro-agent-runner
#   ./install.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "$REPO_DIR/lib/common.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  kiro-agent-runner — install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Detect OS ───────────────────────────────────────────────────────────────

log_section "System"

OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
  log_info "macOS detected"
elif [[ -f /etc/debian_version ]]; then
  OS="debian"
  log_info "Debian/Ubuntu detected"
elif [[ -f /etc/redhat-release ]]; then
  OS="redhat"
  log_info "RHEL/CentOS/Fedora detected"
else
  log_warn "Unknown OS — will attempt generic install"
fi

SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

# ── 2. Prerequisites ───────────────────────────────────────────────────────────

log_section "Prerequisites"

source "$REPO_DIR/lib/preflight.sh"
run_preflight || {
  echo ""
  log_error "Fix the missing prerequisites above, then re-run ./install.sh"
  exit 1
}

# ── 3. Install Kiro PreToolUse hook (if Kiro is installed) ────────────────────

log_section "Kiro activity logging hook"

KIRO_HOOKS_DIR=""
# Check common Kiro workspace locations
for candidate in \
  "$HOME/.kiro/hooks" \
  "$HOME/projects/.kiro/hooks" \
  "$PWD/.kiro/hooks"
do
  if [[ -d "$(dirname "$candidate")" ]]; then
    KIRO_HOOKS_DIR="$candidate"
    break
  fi
done

if command -v kiro &>/dev/null && [[ -n "$KIRO_HOOKS_DIR" ]]; then
  mkdir -p "$KIRO_HOOKS_DIR"
  HOOK_FILE="$KIRO_HOOKS_DIR/agent-activity-logger.json"
  ACTIVITY_LOG="$RUNNER_HOME/activity.log"

  cat > "$HOOK_FILE" <<EOF
{
  "version": "v1",
  "hooks": [{
    "name": "Agent Activity Logger",
    "trigger": "PreToolUse",
    "description": "Logs every Kiro tool call to $ACTIVITY_LOG",
    "action": {
      "type": "command",
      "command": "python3 -c \\"\\nimport sys, json, datetime, os\\ndata = json.load(sys.stdin)\\ntool = data.get('tool_name', 'unknown')\\nparams = data.get('tool_input', {})\\nsummary = params.get('path', params.get('command', params.get('query', params.get('prompt', params.get('name', params.get('explanation', ''))))))\\nif isinstance(summary, str): summary = summary[:80]\\nelse: summary = str(summary)[:80]\\nts = datetime.datetime.now().strftime('%H:%M:%S')\\nlog_path = '$ACTIVITY_LOG'\\nos.makedirs(os.path.dirname(log_path), exist_ok=True)\\nwith open(log_path, 'a') as f:\\n    f.write(f'[{ts}] {tool:<32} {summary}\\\\n')\\n\\"\\n"
    }
  }]
}
EOF
  log_info "Kiro hook installed → $HOOK_FILE"
  log_warn "Restart Kiro for the hook to take effect"
else
  log_warn "Kiro not found — skipping activity logging hook"
  log_info "Install manually later: copy the hook from docs/kiro-hook.json"
fi

# ── 4. Symlink bin/ commands to ~/bin ─────────────────────────────────────────

log_section "Installing commands to ~/bin"

mkdir -p "$HOME/bin"

for cmd in "$REPO_DIR/bin/"*; do
  name="$(basename "$cmd")"
  target="$HOME/bin/$name"
  chmod +x "$cmd"
  if [[ -L "$target" ]]; then
    rm "$target"
  elif [[ -f "$target" ]]; then
    log_warn "$target exists as a regular file — backing up to ${target}.bak"
    mv "$target" "${target}.bak"
  fi
  ln -s "$cmd" "$target"
  log_info "Linked: $name → $target"
done

# ── 5. Ensure ~/bin in PATH ────────────────────────────────────────────────────

log_section "PATH"

if echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  log_info "~/bin already in PATH"
else
  echo "" >> "$SHELL_RC"
  echo "# kiro-agent-runner" >> "$SHELL_RC"
  echo 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
  export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
  log_info "Added ~/bin to PATH in $SHELL_RC"
fi

# ── 6. Create long-term memory directory ──────────────────────────────────────

log_section "Long-term memory"

ensure_dir "$RUNNER_HOME/memory"

for f in profile.md preferences.md learnings.md decisions.md; do
  if [[ ! -f "$RUNNER_HOME/memory/$f" ]]; then
    cp "$REPO_DIR/memory/$f" "$RUNNER_HOME/memory/$f"
    log_info "Created: $RUNNER_HOME/memory/$f"
  else
    log_info "Exists (unchanged): $RUNNER_HOME/memory/$f"
  fi
done

# ── 7. Done ───────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅  Installation complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Reload your shell:"
echo "    source $SHELL_RC"
echo ""
echo "  Then get started:"
echo ""
echo "    1. kiro-init                         # set up your profile (once)"
echo "    2. kiro-brief <job> [project_dir]    # scaffold a job brief"
echo "    3. kiro-job   <job> [project_dir]    # launch worker + watcher"
echo ""
echo "  Full docs: $REPO_DIR/docs/"
echo ""
