#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE Host — CLI Tools Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-03-22
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================

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
LOGFILE="/var/log/cli-tools-install-$(date +%Y%m%d-%H%M%S).log"
INSTALLED=()
FAILED=()

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD}  Script interrupted (exit ${code})${CL}\n"
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
msg_info()  { printf "${TAB}${YW}◆  %s...${CL}\r" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔  %-50s${CL}\n" "$1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

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
  echo -e "${DGN}  ── CLI Tools Installer for Proxmox VE ─────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  if command -v pveversion &>/dev/null; then
    printf "  ${DGN}PVE    :${CL}  ${BL}%s${CL}\n" "$(pveversion | cut -d/ -f2)"
  fi
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "CLI Tools Install Log - $(date)" > "$LOGFILE"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"
  if [[ $EUID -ne 0 ]]; then
    msg_error "Must be run as root — aborting"
    exit 1
  fi
  msg_ok "Running as root"
  if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    msg_warn "No internet connectivity detected — installation may fail"
  else
    msg_ok "Internet connectivity confirmed"
  fi
}

# ── Repositories ──────────────────────────────────────────────────────────────
setup_repositories() {
  section "Configuring Repositories"

  msg_info "Installing prerequisite tools"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gnupg2 ca-certificates wget curl lsb-release >> "$LOGFILE" 2>&1
  msg_ok "Prerequisites ready"

  local codename
  codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")
  msg_ok "Detected OS codename: ${codename}"

  # Enable contrib / non-free / non-free-firmware for full package access
  if ! grep -qP "^deb .* contrib" /etc/apt/sources.list 2>/dev/null; then
    sed -i 's/^\(deb [^ ]* [^ ]* main\)$/\1 contrib non-free non-free-firmware/' \
      /etc/apt/sources.list
    msg_ok "Enabled contrib / non-free / non-free-firmware"
  else
    msg_ok "contrib/non-free already enabled"
  fi
}

# ── APT Update ────────────────────────────────────────────────────────────────
apt_update() {
  section "Updating Package Lists"
  msg_info "Running apt-get update"
  DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
  msg_ok "Package lists updated"
}

# ── Single Package Installer ──────────────────────────────────────────────────
install_pkg() {
  local pkg="$1"
  local label="${2:-$pkg}"
  printf "${TAB}${BL}[▸]${CL} Installing %-38s" "${label}..."
  if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1; then
    printf "${GN}✔ OK${CL}\n"
    INSTALLED+=("$label")
  else
    printf "${RD}✘ FAILED${CL}\n"
    FAILED+=("$label")
  fi
}

# ── All Packages ──────────────────────────────────────────────────────────────
install_all() {

  section "System Monitoring & Performance"
  install_pkg "htop"
  install_pkg "lm-sensors"
  install_pkg "glances"
  install_pkg "iftop"
  install_pkg "smartmontools"
  install_pkg "ncdu"
  install_pkg "iotop"
  install_pkg "btop"
  install_pkg "s-tui"
  install_pkg "iptraf-ng"

  section "Storage & File Utilities"
  install_pkg "rsync"
  install_pkg "zfsutils-linux"       "zfs-utils-linux"
  install_pkg "plocate"
  install_pkg "dos2unix"
  install_pkg "libguestfs-tools"     "virt-filesystems (libguestfs-tools)"

  section "Networking"
  install_pkg "net-tools"
  install_pkg "wget"
  install_pkg "curl"
  install_pkg "mtr"
  install_pkg "ipset"
  install_pkg "sshpass"
  install_pkg "axel"
  install_pkg "nfs-common"
  install_pkg "nfs-kernel-server"
  install_pkg "qemu-guest-agent"
  install_pkg "iperf3"
  install_pkg "iperf"

  section "Shell, Dev & Terminal Tools"
  install_pkg "tmux"
  install_pkg "zsh"
  install_pkg "git"
  install_pkg "bat"
  install_pkg "fzf"
  install_pkg "ripgrep"
  install_pkg "msr-tools"
  install_pkg "finger"
  install_pkg "grc"
  install_pkg "dialog"

  section "X11 Display & Forwarding Dependencies"
  install_pkg "xauth"
  install_pkg "xterm"
  install_pkg "x11-apps"
  install_pkg "x11-utils"
  install_pkg "x11-xserver-utils"
  install_pkg "xinit"
  install_pkg "xorg"
  install_pkg "libx11-6"
  install_pkg "libx11-dev"
}

# ── Post-Install Tasks ────────────────────────────────────────────────────────
post_install() {
  section "Post-Install Configuration"

  # bat is installed as 'batcat' on Debian — create convenience symlink
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" /usr/local/bin/bat
    msg_ok "Symlink created: bat → batcat"
  fi

  # Enable qemu-guest-agent service
  if systemctl list-unit-files qemu-guest-agent.service &>/dev/null 2>&1; then
    systemctl enable --now qemu-guest-agent >> "$LOGFILE" 2>&1 || true
    msg_ok "qemu-guest-agent service enabled and started"
  fi

  # Run sensors-detect non-interactively
  if command -v sensors-detect &>/dev/null; then
    yes "" | sensors-detect >> "$LOGFILE" 2>&1 || true
    msg_ok "lm-sensors configured (run 'sensors' to view readings)"
  fi

  # Update plocate database
  if command -v updatedb &>/dev/null; then
    updatedb >> "$LOGFILE" 2>&1 || true
    msg_ok "plocate database updated"
  fi
}

# ── Verification ──────────────────────────────────────────────────────────────
verify() {
  section "Verifying Installations"

  local entries=(
    "htop:htop"
    "lm-sensors:sensors"
    "glances:glances"
    "iftop:iftop"
    "smartmontools:smartctl"
    "ncdu:ncdu"
    "rsync:rsync"
    "zfsutils-linux:zfs"
    "net-tools:netstat"
    "wget:wget"
    "curl:curl"
    "mtr:mtr"
    "tmux:tmux"
    "zsh:zsh"
    "git:git"
    "bat:batcat"
    "fzf:fzf"
    "ripgrep:rg"
    "iotop:iotop"
    "btop:btop"
    "s-tui:s-tui"
    "iptraf-ng:iptraf-ng"
    "ipset:ipset"
    "plocate:plocate"
    "sshpass:sshpass"
    "grc:grc"
    "axel:axel"
    "dialog:dialog"
    "dos2unix:dos2unix"
    "qemu-guest-agent:qemu-ga"
    "iperf3:iperf3"
    "iperf:iperf"
    "libguestfs-tools:virt-filesystems"
    "xauth:xauth"
    "xterm:xterm"
    "xorg:Xorg"
  )

  local ok=0 fail=0
  for entry in "${entries[@]}"; do
    local pkg="${entry%%:*}"
    local bin="${entry##*:}"
    printf "${TAB}  %-40s" "$pkg"
    if command -v "$bin" &>/dev/null \
       || dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
      printf "${GN}✔ Verified${CL}\n"
      ok=$((ok + 1))
    else
      printf "${RD}✘ Not Found${CL}\n"
      fail=$((fail + 1))
    fi
  done

  echo ""
  printf "  ${GN}${BLD}Verified: %d${CL}    ${RD}${BLD}Not Found: %d${CL}\n" "$ok" "$fail"
}

# ── Final Summary ─────────────────────────────────────────────────────────────
summary() {
  local total=$(( ${#INSTALLED[@]} + ${#FAILED[@]} ))
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Van Auken Tech${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf "  ${GN}${BLD}Installed Successfully : %d / %d${CL}\n" "${#INSTALLED[@]}" "$total"

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf "  ${RD}${BLD}Failed                 : %d${CL}\n" "${#FAILED[@]}"
    echo ""
    echo -e "  ${RD}${BLD}Failed packages:${CL}"
    for p in "${FAILED[@]}"; do
      echo -e "  ${RD}    ✘  ${p}${CL}"
    done
  fi

  echo ""
  echo -e "  ${GN}${BLD}Installed packages:${CL}"
  for p in "${INSTALLED[@]}"; do
    echo -e "  ${GN}    ✔${CL}  ${p}"
  done

  echo ""
  echo -e "  ${YW}Full log  : ${LOGFILE}${CL}"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $(hostname -f 2>/dev/null || hostname)${CL}"
  echo -e "${DGN}  Completed  : $(date '+%Y-%m-%d %H:%M:%S')${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Entry Point ───────────────────────────────────────────────────────────────
main() {
  header_info
  preflight
  setup_repositories
  apt_update
  install_all
  post_install
  verify
  summary
}

main "$@"
