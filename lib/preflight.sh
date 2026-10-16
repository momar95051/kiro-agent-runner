#!/bin/zsh
# lib/preflight.sh — Dependency checks and auto-install

source "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/common.sh"

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/redhat-release ]]; then
    echo "redhat"
  else
    echo "unknown"
  fi
}

# Check if Homebrew is available (macOS)
ensure_brew() {
  if ! command -v brew &>/dev/null; then
    log_step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

# Install a package via the appropriate package manager
install_pkg() {
  local pkg="$1"
  local os
  os=$(detect_os)
  case "$os" in
    macos)
      ensure_brew
      brew install "$pkg"
      ;;
    debian)
      sudo apt-get install -y "$pkg"
      ;;
    redhat)
      sudo yum install -y "$pkg"
      ;;
    *)
      log_error "Cannot auto-install $pkg on this OS. Please install manually."
      return 1
      ;;
  esac
}

# Check a single dependency
check_dep() {
  local cmd="$1"
  local pkg="${2:-$1}"        # package name if different from command
  local required="${3:-true}" # true = required, false = optional
  local install="${4:-true}"  # true = auto-install, false = manual

  if command -v "$cmd" &>/dev/null; then
    log_info "$cmd $(command -v "$cmd")"
    return 0
  fi

  if [[ "$required" == "true" ]]; then
    log_warn "$cmd not found"
    if [[ "$install" == "true" ]]; then
      log_step "Installing $pkg..."
      install_pkg "$pkg" && log_info "$cmd installed" && return 0
    else
      log_error "$cmd is required but could not be auto-installed."
      return 1
    fi
  else
    log_warn "$cmd not found (optional — some features disabled)"
    return 0
  fi
}

# Check claude CLI specifically (requires manual auth)
check_claude() {
  if command -v claude &>/dev/null; then
    local ver
    ver=$(claude --version 2>/dev/null | head -1)
    log_info "claude $ver"
    return 0
  fi

  log_warn "claude CLI not found"
  echo ""
  echo "  Claude Code CLI is required for the worker and watcher."
  echo "  Install it from: https://claude.ai/code"
  echo ""
  echo "  After installing, run: claude --version to verify"
  echo ""

  if confirm "Open the Claude Code install page now?"; then
    open "https://claude.ai/code" 2>/dev/null || xdg-open "https://claude.ai/code" 2>/dev/null || true
  fi
  return 1
}

# Check tmux version (need >= 2.6 for send-keys -l)
check_tmux() {
  if ! command -v tmux &>/dev/null; then
    log_warn "tmux not found"
    log_step "Installing tmux..."
    install_pkg tmux && log_info "tmux installed"
    return $?
  fi

  local ver major minor
  ver=$(tmux -V | grep -o '[0-9]\+\.[0-9]\+' | head -1)
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)

  if (( major < 2 || (major == 2 && minor < 6) )); then
    log_warn "tmux $ver found but >= 2.6 recommended. Upgrading..."
    install_pkg tmux
  else
    log_info "tmux $ver"
  fi
}

# Ensure ~/bin is in PATH
ensure_bin_in_path() {
  local bin_dir="$HOME/bin"
  mkdir -p "$bin_dir"

  if echo "$PATH" | tr ':' '\n' | grep -qx "$bin_dir"; then
    log_info "~/bin already in PATH"
    return 0
  fi

  log_step "Adding ~/bin to PATH..."

  local shell_rc
  if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
    shell_rc="$HOME/.zshrc"
  else
    shell_rc="$HOME/.bashrc"
  fi

  echo "" >> "$shell_rc"
  echo "# kiro-agent-runner" >> "$shell_rc"
  echo 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' >> "$shell_rc"

  export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
  log_info "Added to $shell_rc (takes effect in new shells)"
}

# Run all dependency checks
run_preflight() {
  local fail=0

  log_section "Checking dependencies"

  check_tmux         || fail=1
  check_dep git      || fail=1
  check_dep python3  || fail=1
  check_dep jq       jq optional true  # optional
  check_claude       || fail=1

  ensure_bin_in_path

  if (( fail )); then
    echo ""
    log_error "Some required dependencies are missing. Fix them and re-run."
    return 1
  fi

  echo ""
  log_info "All dependencies satisfied"
  return 0
}
