#!/usr/bin/env bash
# ============================================================================
#  Kali-Style Prompt Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-04-15
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
#  Installs a Kali Linux-style command prompt on Ubuntu, Debian, RHEL,
#  Rocky Linux, or Fedora. Auto-detects the user's shell (bash/zsh) and
#  configures accordingly.
#
# ============================================================================

set -o pipefail

# ── Script Metadata ───────────────────────────────────────────────────────────
SCRIPT_NAME="kali-prompt-install"
SCRIPT_VERSION="1.0.0"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${LOG_DIR:-/var/tmp/${SCRIPT_NAME}}"
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
OS_ID=""
OS_FAMILY=""
OS_PRETTY=""
PKG_MGR=""
TARGET_SHELL_NAME=""

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD}  Script interrupted (exit ${code})${CL}\n"
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found: $1"
}

# ── Header ────────────────────────────────────────────────────────────────────
header_info() {
  clear
  echo -e "${BL}${BLD}"
  cat << 'BANNER'
  __   ___   _  _   _  _   _ _  _____ _  _   _____ ___ ___ _  _
  \ \ / /_\ | \| | /_\| | | | |/ / __| \| | |_   _| __/ __| || |
   \ V / _ \| .` |/ _ \ |_| | ' <| _|| .` |   | | | _| (__| __ |
    \_/_/ \_\_|\_/_/ \_\___/|_|\_\___|_|\_|   |_| |___\___|_||_|
BANNER
  echo -e "${CL}"
  echo -e "${DGN}  ── Kali-Style Prompt Installer ────────────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOG_FILE"
  echo ""
}

# ── Logging Setup ─────────────────────────────────────────────────────────────
setup_logging() {
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"
  chmod 600 "$LOG_FILE" 2>/dev/null || true
  echo "Kali-Style Prompt Install Log - $(date)" > "$LOG_FILE"
}

# ── File Management ───────────────────────────────────────────────────────────
backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.${TIMESTAMP}"
    cp -a "$file" "$backup" 2>/dev/null || true
    msg_ok "Backup created: $backup"
    echo "Backup: $file -> $backup" >> "$LOG_FILE"
  fi
}

ensure_ownership() {
  local file="$1"
  local group
  group="$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")"
  chown "$REAL_USER:$group" "$file" 2>/dev/null || true
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
    awk -v start="$start_marker" -v end="$end_marker" '
      BEGIN {skip=0}
      $0 == start {skip=1; next}
      $0 == end   {skip=0; next}
      skip == 0   {print}
    ' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
  fi

  {
    printf '\n%s\n' "$start_marker"
    printf '%s\n' "$content"
    printf '%s\n' "$end_marker"
  } >> "$file"

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

  {
    printf '\n%s\n' "$start_marker"
    printf '%s\n' "$content"
    printf '%s\n' "$end_marker"
  } >> "$file"

  ensure_ownership "$file"
}

# ── Detection Functions ───────────────────────────────────────────────────────
detect_real_user() {
  section "Detecting Target User"

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    REAL_USER="$SUDO_USER"
  else
    REAL_USER="$(id -un)"
  fi

  REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || true)"

  if [[ -z "${REAL_HOME:-}" || ! -d "$REAL_HOME" ]]; then
    case "$REAL_USER" in
      root) REAL_HOME="/root" ;;
      *)    REAL_HOME="/home/$REAL_USER" ;;
    esac
  fi

  [[ -d "$REAL_HOME" ]] || fatal "Unable to determine home directory for user: $REAL_USER"

  msg_ok "Target user: $REAL_USER"
  msg_ok "Target home: $REAL_HOME"
  echo "User: $REAL_USER, Home: $REAL_HOME" >> "$LOG_FILE"
}

detect_os() {
  section "Detecting Operating System"

  [[ -r /etc/os-release ]] || fatal "/etc/os-release not found; unsupported system"
  # shellcheck disable=SC1091
  . /etc/os-release

  OS_ID="${ID:-unknown}"
  local os_like="${ID_LIKE:-}"
  OS_PRETTY="${PRETTY_NAME:-$OS_ID}"

  case "$OS_ID" in
    ubuntu|debian|raspbian|linuxmint|pop|elementary|zorin|kali)
      OS_FAMILY="debian"
      PKG_MGR="apt"
      ;;
    rhel|rocky|almalinux|centos|ol)
      OS_FAMILY="rhel"
      if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
      elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
      else
        fatal "No supported package manager found for $OS_ID"
      fi
      ;;
    fedora)
      OS_FAMILY="rhel"
      PKG_MGR="dnf"
      ;;
    *)
      case "$os_like" in
        *debian*|*ubuntu*)
          OS_FAMILY="debian"
          PKG_MGR="apt"
          ;;
        *rhel*|*fedora*|*centos*)
          OS_FAMILY="rhel"
          if command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
          elif command -v yum >/dev/null 2>&1; then
            PKG_MGR="yum"
          else
            fatal "No supported package manager found for $OS_ID"
          fi
          ;;
        *)
          fatal "Unsupported distribution: ${OS_PRETTY}. Supported: Ubuntu, Debian, RHEL, Rocky, Fedora"
          ;;
      esac
      ;;
  esac

  msg_ok "Detected OS: $OS_PRETTY"
  msg_ok "OS family: $OS_FAMILY"
  msg_ok "Package manager: $PKG_MGR"
  echo "OS: $OS_PRETTY, Family: $OS_FAMILY, PKG: $PKG_MGR" >> "$LOG_FILE"
}

detect_shell() {
  section "Detecting User Shell"

  local target_shell
  target_shell="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f7 || true)"
  TARGET_SHELL_NAME="$(basename "${target_shell:-bash}")"

  case "$TARGET_SHELL_NAME" in
    bash|zsh) ;;
    *)
      msg_warn "User shell '$TARGET_SHELL_NAME' is not bash/zsh — defaulting to bash config"
      TARGET_SHELL_NAME="bash"
      ;;
  esac

  msg_ok "Detected login shell: $TARGET_SHELL_NAME"
  echo "Shell: $TARGET_SHELL_NAME" >> "$LOG_FILE"
}

# ── Package Installation ──────────────────────────────────────────────────────
install_optional_shell_tools() {
  section "Installing Shell Dependencies"

  local need_install=0
  local packages=()

  if [[ "$TARGET_SHELL_NAME" == "zsh" ]] && ! command -v zsh >/dev/null 2>&1; then
    packages+=(zsh)
    need_install=1
  fi

  if [[ "$need_install" -eq 0 ]]; then
    msg_ok "No additional packages required"
    return 0
  fi

  msg_info "Installing missing packages: ${packages[*]}"

  case "$PKG_MGR" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y >> "$LOG_FILE" 2>&1
      apt-get install -y "${packages[@]}" >> "$LOG_FILE" 2>&1
      ;;
    dnf)
      dnf install -y "${packages[@]}" >> "$LOG_FILE" 2>&1
      ;;
    yum)
      yum install -y "${packages[@]}" >> "$LOG_FILE" 2>&1
      ;;
    *)
      fatal "Unsupported package manager: $PKG_MGR"
      ;;
  esac

  msg_ok "Optional packages installed: ${packages[*]}"
}

# ── Prompt Configuration Blocks ──────────────────────────────────────────────
build_bash_block() {
  cat <<'EOF'
# Kali-like prompt — managed by kali-prompt-install
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|linux*|vt*) color_prompt=yes ;;
    *) color_prompt=yes ;;
esac

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

alias ls='ls --color=auto 2>/dev/null || ls -G 2>/dev/null || ls'
alias ll='ls -alF --color=auto 2>/dev/null || ls -alFG 2>/dev/null || ls -alF'
alias la='ls -A --color=auto 2>/dev/null || ls -AG 2>/dev/null || ls -A'
alias l='ls -CF --color=auto 2>/dev/null || ls -CFG 2>/dev/null || ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
EOF
}

build_zsh_block() {
  cat <<'EOF'
# Kali-like prompt — managed by kali-prompt-install
autoload -U colors >/dev/null 2>&1 && colors

if [[ $EUID -eq 0 ]]; then
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f# '
else
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f$ '
fi

alias ls='ls --color=auto 2>/dev/null || ls -G 2>/dev/null || ls'
alias ll='ls -alF --color=auto 2>/dev/null || ls -alFG 2>/dev/null || ls -alF'
alias la='ls -A --color=auto 2>/dev/null || ls -AG 2>/dev/null || ls -A'
alias l='ls -CF --color=auto 2>/dev/null || ls -CFG 2>/dev/null || ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
EOF
}

# ── Installation Functions ────────────────────────────────────────────────────
install_bash_prompt() {
  section "Installing Bash Prompt"

  local file="${REAL_HOME}/.bashrc"
  local start="# >>> kali-prompt-install >>>"
  local end="# <<< kali-prompt-install <<<"
  local content
  content="$(build_bash_block)"

  msg_info "Configuring $file"
  replace_managed_block "$file" "$start" "$end" "$content"
  msg_ok "Bash prompt configured: $file"
  echo "Configured: $file" >> "$LOG_FILE"
}

install_zsh_prompt() {
  section "Installing Zsh Prompt"

  local file="${REAL_HOME}/.zshrc"
  local start="# >>> kali-prompt-install >>>"
  local end="# <<< kali-prompt-install <<<"
  local content
  content="$(build_zsh_block)"

  msg_info "Configuring $file"
  replace_managed_block "$file" "$start" "$end" "$content"
  msg_ok "Zsh prompt configured: $file"
  echo "Configured: $file" >> "$LOG_FILE"
}

install_profile_loader() {
  section "Configuring Profile Loader"

  local profile_file="${REAL_HOME}/.profile"
  local start="# >>> kali-prompt-loader >>>"
  local end="# <<< kali-prompt-loader <<<"
  local content

  content="$(cat <<'EOF'
# Load user shell config if present
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

if [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
    . "$HOME/.zshrc"
fi
EOF
)"

  msg_info "Configuring $profile_file"
  append_block_once "$profile_file" "$start" "$end" "$content"
  msg_ok "Profile loader configured: $profile_file"
  echo "Configured: $profile_file" >> "$LOG_FILE"
}

# ── Verification ──────────────────────────────────────────────────────────────
verify_installation() {
  section "Verifying Installation"

  local ok_count=0
  local fail_count=0

  # Check bash config
  printf "${TAB}  %-50s" ".bashrc configuration"
  if grep -Fq "kali-prompt-install" "${REAL_HOME}/.bashrc" 2>/dev/null; then
    printf "${GN}✔ Verified${CL}\n"
    ok_count=$((ok_count + 1))
  else
    printf "${RD}✘ Not Found${CL}\n"
    fail_count=$((fail_count + 1))
  fi

  # Check zsh config (only if zsh is target shell)
  if [[ "$TARGET_SHELL_NAME" == "zsh" ]]; then
    printf "${TAB}  %-50s" ".zshrc configuration"
    if grep -Fq "kali-prompt-install" "${REAL_HOME}/.zshrc" 2>/dev/null; then
      printf "${GN}✔ Verified${CL}\n"
      ok_count=$((ok_count + 1))
    else
      printf "${RD}✘ Not Found${CL}\n"
      fail_count=$((fail_count + 1))
    fi
  fi

  # Check profile loader
  printf "${TAB}  %-50s" ".profile loader"
  if grep -Fq "kali-prompt-loader" "${REAL_HOME}/.profile" 2>/dev/null; then
    printf "${GN}✔ Verified${CL}\n"
    ok_count=$((ok_count + 1))
  else
    printf "${YW}⚠ Optional${CL}\n"
  fi

  echo ""
  printf "  ${GN}${BLD}Verified: %d${CL}    ${RD}${BLD}Failed: %d${CL}\n" "$ok_count" "$fail_count"

  if [[ "$fail_count" -gt 0 ]]; then
    msg_warn "Some verifications failed — attempting repair"
    install_bash_prompt
    if [[ "$TARGET_SHELL_NAME" == "zsh" ]]; then
      install_zsh_prompt
    fi
  fi

  # Final check
  if ! grep -Fq "kali-prompt-install" "${REAL_HOME}/.bashrc" 2>/dev/null; then
    fatal "Verification failed after repair attempt"
  fi

  msg_ok "All verifications passed"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Van Auken Tech${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf "  ${GN}${BLD}Script Version    :${CL}  %s\n" "${SCRIPT_VERSION}"
  printf "  ${GN}${BLD}Target User       :${CL}  %s\n" "${REAL_USER}"
  printf "  ${GN}${BLD}Target Home       :${CL}  %s\n" "${REAL_HOME}"
  printf "  ${GN}${BLD}Detected OS       :${CL}  %s\n" "${OS_PRETTY}"
  printf "  ${GN}${BLD}OS Family         :${CL}  %s\n" "${OS_FAMILY}"
  printf "  ${GN}${BLD}Shell Configured  :${CL}  %s\n" "${TARGET_SHELL_NAME}"
  echo ""
  echo -e "  ${GN}${BLD}Configured files:${CL}"
  echo -e "  ${GN}    ✔${CL}  ${REAL_HOME}/.bashrc"
  [[ "$TARGET_SHELL_NAME" == "zsh" ]] && echo -e "  ${GN}    ✔${CL}  ${REAL_HOME}/.zshrc"
  echo -e "  ${GN}    ✔${CL}  ${REAL_HOME}/.profile"
  echo ""
  echo -e "  ${YW}Log file  : ${LOG_FILE}${CL}"
  echo ""
  echo -e "  ${BL}${BLD}To activate immediately:${CL}"
  echo -e "  ${BL}    exec ${TARGET_SHELL_NAME} -l${CL}"
  echo -e "  ${BL}  Or open a new terminal session.${CL}"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $(hostname -f 2>/dev/null || hostname)${CL}"
  echo -e "${DGN}  Completed  : $(date '+%Y-%m-%d %H:%M:%S')${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"

  # Required commands
  local required_cmds=(bash grep awk sed id cp tee)
  for cmd in "${required_cmds[@]}"; do
    printf "${TAB}  %-40s" "$cmd"
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "${GN}✔ Found${CL}\n"
    else
      printf "${RD}✘ Missing${CL}\n"
      fatal "Required command not found: $cmd"
    fi
  done

  # Optional: getent (not always available on minimal installs)
  printf "${TAB}  %-40s" "getent"
  if command -v getent >/dev/null 2>&1; then
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
  detect_os
  detect_shell
  install_optional_shell_tools
  install_bash_prompt

  if [[ "$TARGET_SHELL_NAME" == "zsh" ]]; then
    install_zsh_prompt
  fi

  install_profile_loader
  verify_installation
  print_summary
}

main "$@"
