#!/usr/bin/env bash
# ============================================================================
#  Raspberry Pi Kali Linux — Headless VNC Multi-Session Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.5
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
check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|kali|ubuntu)$ && ! "$ID_LIKE" =~ ^(debian|ubuntu)$ ]]; then
      msg_error "Unsupported OS ($ID). This script requires Debian, Kali Linux, or Ubuntu."
    fi
  else
    msg_error "/etc/os-release not found. Cannot verify OS compatibility."
  fi
}

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
  exit 0
}

# ── Main ──────────────────────────────────────────────────────────────────────
check_os
header_info

if [[ $EUID -ne 0 ]]; then
  msg_error "This script must be run as root. Try 'sudo bash $0'"
fi

section "System Preparation"
msg_info "Updating package lists"
if ! log_exec apt-get update -y; then
  msg_error "Failed to update package lists!"
fi
msg_ok "Package lists updated"

section "Package Installation"
msg_info "Pre-seeding LightDM to bypass interactive prompts"
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
msg_ok "LightDM pre-seeded"

msg_info "Installing TigerVNC, XFCE4, and LightDM"
export DEBIAN_FRONTEND=noninteractive
if ! apt-get -s install tigervnc-standalone-server tigervnc-tools dbus-x11 xfce4 xfce4-goodies lightdm >/dev/null 2>&1; then
  msg_info "Broken dependencies detected. Deploying aptitude resolver"
  log_exec apt-get --fix-broken install -y
  log_exec apt-get install -y aptitude
  log_exec env DEBIAN_FRONTEND=noninteractive aptitude install -y -q -f tigervnc-standalone-server tigervnc-tools dbus-x11 xfce4 xfce4-goodies lightdm
fi
if ! log_exec apt-get install -y --no-install-recommends tigervnc-standalone-server tigervnc-tools dbus-x11 xfce4 xfce4-goodies lightdm; then
  msg_error "Package installation failed! Check logs: $LOGFILE"
fi
msg_ok "Core packages installed"

section "XDMCP & Headless Configuration"
msg_info "Configuring LightDM for headless XDMCP"
mkdir -p /etc/lightdm/lightdm.conf.d
cat << 'CONF' > /etc/lightdm/lightdm.conf.d/50-xdmcp.conf
[LightDM]
start-default-seat=false

[XDMCPServer]
enabled=true
port=177
CONF

if ! log_exec systemctl restart lightdm; then
  msg_error "Failed to restart LightDM service!"
fi
msg_ok "XDMCP enabled and local seat disabled"

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
msg_ok "Global session isolation configured"

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
ExecStart=-/bin/bash -c "if [ -x /usr/bin/Xtigervnc ]; then exec /usr/bin/Xtigervnc -inetd -query localhost -geometry 1920x1080 -once -SecurityTypes=None; else exec /usr/bin/Xvnc -inetd -query localhost -geometry 1920x1080 -once -SecurityTypes=None; fi"
User=nobody
StandardInput=socket
StandardError=syslog
SVC
msg_ok "xvnc@.service created"

msg_info "Enabling socket activation"
log_exec systemctl daemon-reload
if ! log_exec systemctl enable --now xvnc.socket; then
  msg_error "Failed to enable xvnc.socket!"
fi
msg_ok "Socket activation enabled"

section "Firewall Configuration"
msg_info "Configuring incoming VNC ports"
if command -v ufw &>/dev/null; then
  log_exec ufw allow 5900:5910/tcp
elif command -v firewall-cmd &>/dev/null; then
  log_exec firewall-cmd --permanent --add-port=5900-5910/tcp
  log_exec firewall-cmd --reload
else
  log_exec iptables -F
  log_exec iptables -P INPUT ACCEPT
fi
msg_ok "Firewall configured"

section "System Validation"
msg_info "Validating Package Verification"
for pkg in tigervnc-standalone-server xfce4 lightdm; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    msg_error "Validation Failed: Package '$pkg' is not installed."
  fi
done
msg_ok "Packages validated"

msg_info "Validating X11 Binary Paths"
if [[ ! -x /usr/bin/Xvnc && ! -x /usr/bin/Xtigervnc ]]; then
  msg_error "Validation Failed: TigerVNC server binary not found or not executable!"
fi
msg_ok "VNC binaries verified"

msg_info "Validating VNC Sockets"
if ! systemctl is-active --quiet xvnc.socket; then
  msg_error "Validation Failed: xvnc.socket failed to start!"
fi
if ! ss -tln | grep -q ":5900 "; then
  msg_error "Validation Failed: TCP port 5900 is not listening!"
fi
msg_ok "VNC socket is active and listening"

msg_info "Validating LightDM XDMCP"
if ! systemctl is-active --quiet lightdm; then
  msg_error "Validation Failed: LightDM service is not running!"
fi
if ! ss -uln | grep -q ":177 "; then
  msg_error "Validation Failed: XDMCP is not listening on UDP port 177!"
fi
msg_ok "XDMCP service is operational"

summary
