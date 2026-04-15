#!/bin/bash
# ============================================================================
#  Kali-Style Prompt Installer for macOS
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-04-15
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
#  Installs a Kali Linux-style command prompt on macOS 12.7.6 (Monterey)
#  or later. Supports both Intel and Apple Silicon Macs. Auto-detects
#  the user's shell (zsh/bash) and configures accordingly.
#
# ============================================================================

# ── Script Metadata ───────────────────────────────────────────────────────────
SCRIPT_NAME="kali-prompt-macos-install"
SCRIPT_VERSION="1.0.0"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${LOG_DIR:-${TMPDIR:-/tmp}/${SCRIPT_NAME}}"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}-${TIMESTAMP}.log"

# ── Colour Palette ────────────────────────────────────────────────────────────
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="    "

# ── Globals ───────────────────────────────────────────────────────────────────
REAL_USER=""
REAL_HOME=""
MACOS_VERSION=""
MACOS_NAME=""
ARCH_TYPE=""
TARGET_SHELL_NAME=""
MIN_MACOS_VERSION="12.7.6"

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  if [ $code -ne 0 ]; then
    echo ""
    printf "${RD}  Script interrupted (exit ${code})${CL}\n"
    echo ""
  fi
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
msg_info()  { printf "${TAB}${BL}◆  %s...${CL}\r" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔  %-60s${CL}\n" "$1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

fatal() {
  msg_error "$1"
  exit 1
}

# ── Version Comparison ────────────────────────────────────────────────────────
# Compare two version strings (returns 0 if v1 >= v2)
version_ge() {
  local v1="$1"
  local v2="$2"
  
  # Use sort -V if available, otherwise do manual comparison
  if printf '%s\n%s' "$v2" "$v1" | sort -V -C 2>/dev/null; then
    return 0
  fi
  
  # Fallback: manual comparison for major.minor.patch
  local IFS='.'
  local i
  local -a ver1
  local -a ver2
  
  # Read into arrays (bash 3.x compatible)
  set -- $v1
  ver1_0="${1:-0}"; ver1_1="${2:-0}"; ver1_2="${3:-0}"
  set -- $v2
  ver2_0="${1:-0}"; ver2_1="${2:-0}"; ver2_2="${3:-0}"
  
  # Compare major
  if [ "$ver1_0" -gt "$ver2_0" ] 2>/dev/null; then return 0; fi
  if [ "$ver1_0" -lt "$ver2_0" ] 2>/dev/null; then return 1; fi
  
  # Compare minor
  if [ "$ver1_1" -gt "$ver2_1" ] 2>/dev/null; then return 0; fi
  if [ "$ver1_1" -lt "$ver2_1" ] 2>/dev/null; then return 1; fi
  
  # Compare patch
  if [ "$ver1_2" -ge "$ver2_2" ] 2>/dev/null; then return 0; fi
  
  return 1
}

# ── Header ────────────────────────────────────────────────────────────────────
header_info() {
  clear 2>/dev/null || printf '\n\n\n'
  printf "${BL}${BLD}"
  cat << 'BANNER'
  __   ___   _  _   _  _   _ _  _____ _  _   _____ ___ ___ _  _
  \ \ / /_\ | \| | /_\| | | | |/ / __| \| | |_   _| __/ __| || |
   \ V / _ \| .` |/ _ \ |_| | ' <| _|| .` |   | | | _| (__| __ |
    \_/_/ \_\_|\_/_/ \_\___/|_|\_\___|_|\_|   |_| |___\___|_||_|
BANNER
  printf "${CL}\n"
  printf "${DGN}  ── Kali-Style Prompt Installer for macOS ──────────────────────────${CL}\n"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname 2>/dev/null || echo 'unknown')"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOG_FILE"
  echo ""
}

# ── Logging Setup ─────────────────────────────────────────────────────────────
setup_logging() {
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"
  chmod 600 "$LOG_FILE" 2>/dev/null || true
  echo "Kali-Style Prompt macOS Install Log - $(date)" > "$LOG_FILE"
}

# ── File Management ───────────────────────────────────────────────────────────
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local backup="${file}.bak.${TIMESTAMP}"
    cp -a "$file" "$backup" 2>/dev/null || true
    msg_ok "Backup created: $backup"
    echo "Backup: $file -> $backup" >> "$LOG_FILE"
  fi
}

ensure_ownership() {
  local file="$1"
  chown "$REAL_USER" "$file" 2>/dev/null || true
}

replace_managed_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file" 2>/dev/null || true

  backup_file "$file"

  if grep -Fq "$start_marker" "$file" 2>/dev/null; then
    # Remove existing block using sed (macOS compatible)
    sed -i '' "/$start_marker/,/$end_marker/d" "$file" 2>/dev/null || true
  fi

  # Append new block
  printf '\n%s\n' "$start_marker" >> "$file"
  printf '%s\n' "$content" >> "$file"
  printf '%s\n' "$end_marker" >> "$file"

  ensure_ownership "$file"
}

append_block_once() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file" 2>/dev/null || true

  if grep -Fq "$start_marker" "$file" 2>/dev/null; then
    msg_ok "Managed block already present in $file"
    return 0
  fi

  backup_file "$file"

  printf '\n%s\n' "$start_marker" >> "$file"
  printf '%s\n' "$content" >> "$file"
  printf '%s\n' "$end_marker" >> "$file"

  ensure_ownership "$file"
}

# ── Detection Functions ───────────────────────────────────────────────────────
detect_real_user() {
  section "Detecting Target User"

  if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    REAL_USER="$SUDO_USER"
  else
    REAL_USER="$(id -un)"
  fi

  # macOS home directories are in /Users
  REAL_HOME="/Users/$REAL_USER"
  
  # Handle root user
  if [ "$REAL_USER" = "root" ]; then
    REAL_HOME="/var/root"
  fi

  if [ ! -d "$REAL_HOME" ]; then
    fatal "Unable to determine home directory for user: $REAL_USER"
  fi

  msg_ok "Target user: $REAL_USER"
  msg_ok "Target home: $REAL_HOME"
  echo "User: $REAL_USER, Home: $REAL_HOME" >> "$LOG_FILE"
}

detect_macos() {
  section "Detecting macOS Version"

  # Check if running on macOS
  if [ "$(uname)" != "Darwin" ]; then
    fatal "This script is for macOS only. Detected: $(uname)"
  fi

  # Get macOS version
  MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null)"
  if [ -z "$MACOS_VERSION" ]; then
    fatal "Unable to determine macOS version"
  fi

  # Get macOS name
  MACOS_NAME="$(sw_vers -productName 2>/dev/null) $MACOS_VERSION"

  # Check minimum version
  if ! version_ge "$MACOS_VERSION" "$MIN_MACOS_VERSION"; then
    fatal "macOS $MIN_MACOS_VERSION or later required. Found: $MACOS_VERSION"
  fi

  # Detect architecture
  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64)
      ARCH_TYPE="Apple Silicon"
      ;;
    x86_64)
      ARCH_TYPE="Intel"
      ;;
    *)
      ARCH_TYPE="$arch"
      ;;
  esac

  msg_ok "Detected: $MACOS_NAME"
  msg_ok "Architecture: $ARCH_TYPE ($(uname -m))"
  msg_ok "Minimum required: macOS $MIN_MACOS_VERSION"
  echo "macOS: $MACOS_NAME, Arch: $ARCH_TYPE" >> "$LOG_FILE"
}

detect_shell() {
  section "Detecting User Shell"

  local target_shell
  target_shell="$(dscl . -read /Users/$REAL_USER UserShell 2>/dev/null | awk '{print $2}')"
  
  if [ -z "$target_shell" ]; then
    target_shell="$SHELL"
  fi
  
  TARGET_SHELL_NAME="$(basename "${target_shell:-zsh}")"

  case "$TARGET_SHELL_NAME" in
    bash|zsh) ;;
    *)
      msg_warn "User shell '$TARGET_SHELL_NAME' detected — will configure both bash and zsh"
      TARGET_SHELL_NAME="zsh"
      ;;
  esac

  msg_ok "Detected login shell: $TARGET_SHELL_NAME"
  msg_ok "Note: macOS default shell is zsh since Catalina"
  echo "Shell: $TARGET_SHELL_NAME" >> "$LOG_FILE"
}

# ── Prompt Configuration Blocks ──────────────────────────────────────────────
build_bash_block() {
  cat <<'EOF'
# Kali-like prompt — managed by kali-prompt-macos-install
# macOS-compatible prompt configuration

__kali_prompt_apply() {
    local reset='\[\033[0m\]'
    local red='\[\033[1;31m\]'
    local blue='\[\033[1;34m\]'

    if [ "$(id -u)" -eq 0 ]; then
        PS1="${red}\u@\h${reset}:${blue}\w${reset}# "
    else
        PS1="${red}\u@\h${reset}:${blue}\w${reset}\$ "
    fi
}

__kali_prompt_apply
unset -f __kali_prompt_apply

# macOS-compatible aliases (BSD ls uses -G for color)
alias ls='ls -G'
alias ll='ls -alFG'
alias la='ls -AG'
alias l='ls -CFG'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Enable color output
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
EOF
}

build_zsh_block() {
  cat <<'EOF'
# Kali-like prompt — managed by kali-prompt-macos-install
# macOS zsh prompt configuration

autoload -U colors 2>/dev/null && colors

if [[ $EUID -eq 0 ]]; then
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f# '
else
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f%# '
fi

# macOS-compatible aliases (BSD ls uses -G for color)
alias ls='ls -G'
alias ll='ls -alFG'
alias la='ls -AG'
alias l='ls -CFG'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Enable color output
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
EOF
}

# ── Installation Functions ────────────────────────────────────────────────────
install_bash_prompt() {
  section "Installing Bash Prompt"

  local file="${REAL_HOME}/.bash_profile"
  local start="# >>> kali-prompt-macos-install >>>"
  local end="# <<< kali-prompt-macos-install <<<"
  local content
  content="$(build_bash_block)"

  msg_info "Configuring $file"
  replace_managed_block "$file" "$start" "$end" "$content"
  msg_ok "Bash prompt configured: $file"
  
  # Also add to .bashrc for non-login shells
  local bashrc="${REAL_HOME}/.bashrc"
  if [ -f "$bashrc" ] || [ "$TARGET_SHELL_NAME" = "bash" ]; then
    msg_info "Configuring $bashrc"
    replace_managed_block "$bashrc" "$start" "$end" "$content"
    msg_ok "Bash prompt configured: $bashrc"
  fi
  
  echo "Configured: $file" >> "$LOG_FILE"
}

install_zsh_prompt() {
  section "Installing Zsh Prompt"

  local file="${REAL_HOME}/.zshrc"
  local start="# >>> kali-prompt-macos-install >>>"
  local end="# <<< kali-prompt-macos-install <<<"
  local content
  content="$(build_zsh_block)"

  msg_info "Configuring $file"
  replace_managed_block "$file" "$start" "$end" "$content"
  msg_ok "Zsh prompt configured: $file"
  echo "Configured: $file" >> "$LOG_FILE"
}

# ── Verification ──────────────────────────────────────────────────────────────
verify_installation() {
  section "Verifying Installation"

  local ok_count=0
  local fail_count=0

  # Check zsh config (primary on macOS)
  printf "${TAB}  %-50s" ".zshrc configuration"
  if grep -Fq "kali-prompt-macos-install" "${REAL_HOME}/.zshrc" 2>/dev/null; then
    printf "${GN}✔ Verified${CL}\n"
    ok_count=$((ok_count + 1))
  else
    printf "${RD}✘ Not Found${CL}\n"
    fail_count=$((fail_count + 1))
  fi

  # Check bash config
  printf "${TAB}  %-50s" ".bash_profile configuration"
  if grep -Fq "kali-prompt-macos-install" "${REAL_HOME}/.bash_profile" 2>/dev/null; then
    printf "${GN}✔ Verified${CL}\n"
    ok_count=$((ok_count + 1))
  else
    printf "${YW}⚠ Optional (zsh is default)${CL}\n"
  fi

  echo ""
  printf "  ${GN}${BLD}Verified: %d${CL}    ${RD}${BLD}Failed: %d${CL}\n" "$ok_count" "$fail_count"

  if [ "$fail_count" -gt 0 ]; then
    msg_warn "Some verifications failed — attempting repair"
    install_zsh_prompt
    install_bash_prompt
  fi

  # Final check
  if ! grep -Fq "kali-prompt-macos-install" "${REAL_HOME}/.zshrc" 2>/dev/null; then
    fatal "Verification failed after repair attempt"
  fi

  msg_ok "All verifications passed"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  printf "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}\n"
  printf "${BL}${BLD}       INSTALLATION COMPLETE — Van Auken Tech${CL}\n"
  printf "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}\n"
  echo ""
  printf "  ${GN}${BLD}Script Version    :${CL}  %s\n" "${SCRIPT_VERSION}"
  printf "  ${GN}${BLD}Target User       :${CL}  %s\n" "${REAL_USER}"
  printf "  ${GN}${BLD}Target Home       :${CL}  %s\n" "${REAL_HOME}"
  printf "  ${GN}${BLD}macOS Version     :${CL}  %s\n" "${MACOS_NAME}"
  printf "  ${GN}${BLD}Architecture      :${CL}  %s\n" "${ARCH_TYPE}"
  printf "  ${GN}${BLD}Shell Configured  :${CL}  %s\n" "${TARGET_SHELL_NAME}"
  echo ""
  printf "  ${GN}${BLD}Configured files:${CL}\n"
  printf "  ${GN}    ✔${CL}  ${REAL_HOME}/.zshrc\n"
  printf "  ${GN}    ✔${CL}  ${REAL_HOME}/.bash_profile\n"
  echo ""
  printf "  ${YW}Log file  : ${LOG_FILE}${CL}\n"
  echo ""
  printf "  ${BL}${BLD}To activate immediately:${CL}\n"
  printf "  ${BL}    exec ${TARGET_SHELL_NAME} -l${CL}\n"
  printf "  ${BL}  Or open a new Terminal window.${CL}\n"
  echo ""
  printf "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}\n"
  printf "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}\n"
  printf "${DGN}  Host       : $(hostname 2>/dev/null || echo 'unknown')${CL}\n"
  printf "${DGN}  Completed  : $(date '+%Y-%m-%d %H:%M:%S')${CL}\n"
  printf "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}\n"
  echo ""
}

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"

  # Check we're on macOS
  printf "${TAB}  %-40s" "macOS platform"
  if [ "$(uname)" = "Darwin" ]; then
    printf "${GN}✔ Darwin${CL}\n"
  else
    printf "${RD}✘ Not macOS${CL}\n"
    fatal "This script requires macOS"
  fi

  # Required commands (all should be present on macOS)
  local required_cmds="bash grep sed id cp"
  for cmd in $required_cmds; do
    printf "${TAB}  %-40s" "$cmd"
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "${GN}✔ Found${CL}\n"
    else
      printf "${RD}✘ Missing${CL}\n"
      fatal "Required command not found: $cmd"
    fi
  done

  # Check sw_vers
  printf "${TAB}  %-40s" "sw_vers"
  if command -v sw_vers >/dev/null 2>&1; then
    printf "${GN}✔ Found${CL}\n"
  else
    printf "${RD}✘ Missing${CL}\n"
    fatal "sw_vers not found - cannot determine macOS version"
  fi

  # Check dscl for user info
  printf "${TAB}  %-40s" "dscl"
  if command -v dscl >/dev/null 2>&1; then
    printf "${GN}✔ Found${CL}\n"
  else
    printf "${YW}⚠ Not found (will use fallback)${CL}\n"
  fi

  msg_ok "Preflight checks passed"
}

# ── Entry Point ───────────────────────────────────────────────────────────────
main() {
  setup_logging
  header_info
  preflight
  detect_real_user
  detect_macos
  detect_shell
  
  # Always install both zsh and bash configs on macOS
  # since users may switch shells
  install_zsh_prompt
  install_bash_prompt
  
  verify_installation
  print_summary
}

main "$@"
