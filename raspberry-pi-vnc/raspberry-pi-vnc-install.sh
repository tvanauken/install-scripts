#!/usr/bin/env bash
# ============================================================================
#  Raspberry Pi Kali Linux — Headless VNC Multi-Session Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-10-09
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
LOGFILE="/var/log/rpi-vnc-install-$(date +%Y%m%d-%H%M%S).log"

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
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; exit 1; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

log_exec() {
  echo -e "\n[EXECUTING]: $*" >> "$LOGFILE"
  "$@" >> "$LOGFILE" 2>&1
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
  echo -e "${DGN}  ── Raspberry Pi VNC (Multi-Session) Installer ─────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "Raspberry Pi VNC Install Log - $(date)" > "$LOGFILE"
}

summary() {
  echo -e "\n${BL}${BLD}  ========================================================================${CL}"
  echo -e "${BL}${BLD}               INSTALLATION COMPLETE — Van Auken Tech${CL}"
  echo -e "${BL}${BLD}  ========================================================================${CL}\n"
  printf "  ${DGN}Access via :${CL} RealVNC Viewer -> %s:5900\n" "$(hostname -I | awk '{print $1}')"
  printf "  ${DGN}Quality    :${CL} Set 'Picture quality' to 'High' in RealVNC Properties\n"
  printf "  ${DGN}Log File   :${CL} %s\n" "$LOGFILE"
  printf "  ${DGN}Created By :${CL} Thomas Van Auken\n\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────
header_info

if [[ $EUID -ne 0 ]]; then
  msg_error "This script must be run as root. Try 'sudo bash $0'"
fi

section "System Preparation"
msg_info "Updating package lists"
log_exec apt update
msg_ok "Package lists updated"

section "Package Installation"
msg_info "Installing TigerVNC, XFCE4, and LightDM"
export DEBIAN_FRONTEND=noninteractive
log_exec apt install -y tigervnc-standalone-server tigervnc-tools dbus-x11 xfce4 xfce4-goodies lightdm
msg_ok "Core packages installed"

section "XDMCP Configuration"
msg_info "Enabling XDMCP in LightDM"
mkdir -p /etc/lightdm/lightdm.conf.d
cat << 'CONF' > /etc/lightdm/lightdm.conf.d/50-xdmcp.conf
[XDMCPServer]
enabled=true
port=177
CONF
log_exec systemctl restart lightdm
msg_ok "XDMCP enabled and LightDM restarted"

section "Session Isolation"
msg_info "Deploying global D-Bus / XDG isolation script"
cat << 'INNER' > /etc/X11/Xsession.d/99-isolate-dbus-runtime
# Isolate D-Bus and runtime directories so the same user can run multiple concurrent XFCE sessions
# Allow X Server to connect without authentication for the local LightDM greeter
xhost +local: >/dev/null 2>&1 || true
export XDG_RUNTIME_DIR=/tmp/xdg-runtime-$(id -u)-$$
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
eval $(dbus-launch --sh-syntax)
INNER
chmod 644 /etc/X11/Xsession.d/99-isolate-dbus-runtime
msg_ok "Session isolation configured"

section "Systemd VNC Deployment"
msg_info "Creating xvnc.socket"
cat << 'SOCK' > /etc/systemd/system/xvnc.socket
[Unit]
Description=XVNC Server Socket
[Socket]
ListenStream=5900
ListenStream=5901
Accept=yes
[Install]
WantedBy=sockets.target
SOCK
msg_ok "xvnc.socket created"

msg_info "Creating xvnc@.service template"
cat << 'SVC' > /etc/systemd/system/xvnc@.service
[Unit]
Description=XVNC Per-Connection Daemon
[Service]
ExecStart=-/bin/bash -c "if [ -f /usr/bin/Xtigervnc ]; then /usr/bin/Xtigervnc -inetd -query localhost -geometry 1920x1080 -once -SecurityTypes=None; else /usr/bin/Xvnc -inetd -query localhost -geometry 1920x1080 -once -SecurityTypes=None; fi"
User=nobody
StandardInput=socket
StandardError=syslog
SVC
msg_ok "xvnc@.service created"

msg_info "Enabling socket activation"
log_exec systemctl daemon-reload
log_exec systemctl enable --now xvnc.socket
msg_ok "Socket activation enabled"

section "Firewall"
msg_info "Flushing iptables for incoming connections"
log_exec iptables -F
log_exec iptables -P INPUT ACCEPT
msg_ok "iptables cleared and configured"

summary
