#!/usr/bin/env bash
# ============================================================================
#  Nginx Proxy Manager — LXC Installer for Proxmox VE
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-03-31
#  Repo:       https://github.com/tvanauken/install-scripts
#  Source:     https://community-scripts.org/scripts?id=nginxproxymanager
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
LOGFILE="/var/log/npm-reverse-proxy-install-$(date +%Y%m%d-%H%M%S).log"
COMMUNITY_SCRIPT="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/nginxproxymanager.sh"

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
  echo -e "${DGN}  ── Nginx Proxy Manager — LXC Installer for Proxmox VE ─────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "NPM Reverse Proxy Install Log - $(date)" > "$LOGFILE"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"

  if [[ $EUID -ne 0 ]]; then
    msg_error "Must be run as root on Proxmox VE host — aborting"
    exit 1
  fi
  msg_ok "Running as root"

  if ! command -v pveversion &>/dev/null; then
    msg_error "This script must be run on a Proxmox VE host — aborting"
    exit 1
  fi
  msg_ok "Proxmox VE host confirmed: $(pveversion | cut -d/ -f2)"

  if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    msg_warn "No internet connectivity detected — installation may fail"
  else
    msg_ok "Internet connectivity confirmed"
  fi

  if ! command -v curl &>/dev/null; then
    msg_info "Installing curl"
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl >> "$LOGFILE" 2>&1
    msg_ok "curl installed"
  else
    msg_ok "curl available"
  fi
}

# ── LXC Specs Preview ─────────────────────────────────────────────────────────
show_specs() {
  section "LXC Container Specifications"
  echo -e "  ${BL}${BLD}Default LXC settings (changeable via Advanced mode during install):${CL}"
  echo ""
  printf "  ${DGN}OS           :${CL}  ${BL}Debian 12 (Bookworm)${CL}\n"
  printf "  ${DGN}CPU          :${CL}  ${BL}2 vCPU${CL}\n"
  printf "  ${DGN}RAM          :${CL}  ${BL}2048 MB${CL}\n"
  printf "  ${DGN}Storage      :${CL}  ${BL}8 GB${CL}\n"
  printf "  ${DGN}Web UI       :${CL}  ${BL}http://<LXC-IP>:81${CL}\n"
  printf "  ${DGN}Source       :${CL}  ${BL}community-scripts.org/scripts?id=nginxproxymanager${CL}\n"
  echo ""
  msg_warn "The community script will prompt for LXC settings — press Enter for defaults or choose Advanced to customise"
  echo ""
}

# ── Run Community Script ──────────────────────────────────────────────────────
run_installer() {
  section "Running Community Script — Nginx Proxy Manager LXC"
  echo -e "  ${YW}Launching:${CL}  ${BL}${COMMUNITY_SCRIPT}${CL}"
  echo ""
  echo "Launching community script: $COMMUNITY_SCRIPT" >> "$LOGFILE"
  bash -c "$(curl -fsSL "${COMMUNITY_SCRIPT}")"
  local exit_code=$?
  echo "Community script exited with code ${exit_code}" >> "$LOGFILE"
  if [[ $exit_code -ne 0 ]]; then
    msg_error "Community script exited with error code ${exit_code} — check output above"
    exit $exit_code
  fi
}

# ── Post-Install Notes ────────────────────────────────────────────────────────
post_install_notes() {
  section "Post-Install Reference"
  echo -e "  ${GN}${BLD}Nginx Proxy Manager LXC container has been deployed.${CL}"
  echo ""
  echo -e "  ${BL}${BLD}Access the Web UI:${CL}"
  printf "  ${TAB}http://<LXC-IP>:81\n"
  echo ""
  echo -e "  ${BL}${BLD}First-launch setup wizard:${CL}"
  printf "  ${DGN}[▸]${CL}  Navigate to http://<LXC-IP>:81\n"
  printf "  ${DGN}[▸]${CL}  Complete the admin account creation wizard (no default credentials)\n"
  printf "  ${DGN}[▸]${CL}  Add a Proxy Host — map your domain to a backend service IP:port\n"
  printf "  ${DGN}[▸]${CL}  Request an SSL certificate via Let's Encrypt, or upload a wildcard cert\n"
  printf "  ${DGN}[▸]${CL}  Enable Force SSL and HTTP/2 on each proxy host\n"
  echo ""
  echo -e "  ${BL}${BLD}Optional certbot DNS plugins (run inside the NPM LXC):${CL}"
  printf "  ${DGN}[▸]${CL}  /app/scripts/install-certbot-plugins  — installs common DNS provider certbot plugins\n"
  echo ""
  echo -e "  ${YW}Full documentation:${CL}  https://github.com/tvanauken/install-scripts/tree/main/npm-reverse-proxy/docs"
  echo ""
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       DEPLOYMENT COMPLETE — Nginx Proxy Manager${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  echo -e "  ${GN}${BLD}Nginx Proxy Manager LXC container created and running.${CL}"
  echo -e "  ${YW}Log file : ${LOGFILE}${CL}"
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
  show_specs
  run_installer
  post_install_notes
  summary
}

main "$@"
