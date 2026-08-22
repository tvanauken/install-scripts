#!/usr/bin/env bash
# ============================================================================
#  45Drives Houston UI & Cockpit Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-08-21
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
LOGFILE="/var/log/houston-ui-install-$(date +%Y%m%d-%H%M%S).log"

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

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# ── Header ────────────────────────────────────────────────────────────────────
header_info() {
  clear
  echo -e "${BL}${BLD}"
  cat << 'BANNER'
  __     __               _         _                _____         _     
  \ \   / /_ _ _ __      / \  _   _| | _____ _ __   |_   _|__  ___| |__  
   \ \ / / _` | '_ \    / _ \| | | | |/ / _ \ '_ \    | |/ _ \/ __| '_ \ 
    \ V / (_| | | | |  / ___ \ |_| |   <  __/ | | |   | |  __/ (__| | | |
     \_/ \__,_|_| |_| /_/   \_\__,_|_|\_\___|_| |_|   |_|\___|\___|_| |_|
BANNER
  echo -e "${CL}"
  echo -e "${DGN}  ── Van Auken Tech Houston UI Installer ───────────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "Houston UI Install Log - $(date)" > "$LOGFILE"
}

# ── Main ──────────────────────────────────────────────────────────────────────

header_info

if [[ $EUID -ne 0 ]]; then
   msg_error "This script must be run as root"
fi

if ! command -v whiptail &> /dev/null; then
  msg_info "Installing whiptail"
  if command -v apt-get &> /dev/null; then
    apt-get update -y -qq >/dev/null 2>&1
    apt-get install -y whiptail -qq >/dev/null 2>&1
  elif command -v dnf &> /dev/null; then
    dnf install -y newt -q >/dev/null 2>&1
  fi
  msg_ok "Installed whiptail"
fi

# OS Detection
OS_ID=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
fi

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    PKG_MGR="apt"
elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "rhel" || "$OS_ID" == "centos" ]]; then
    PKG_MGR="dnf"
else
    msg_error "Unsupported OS: $OS_ID. Only Ubuntu/Debian and RHEL/Rocky are supported."
fi

log "Detected OS: $OS_ID (Package Manager: $PKG_MGR)"

# Ask Deployment Type
ENV_TYPE=$(whiptail --title "Deployment Environment" --radiolist \
"Select the environment type for this installation:\n(VMs with HBA passthrough require special hardware spoofing)" 15 70 2 \
"BAREMETAL" "Physical 45Drives Hardware" ON \
"VM" "Virtual Machine (Proxmox/ESXi) with HBA Passthrough" OFF \
3>&1 1>&2 2>&3)

if [ -z "$ENV_TYPE" ]; then
    msg_error "Installation cancelled."
fi
log "Environment Type: $ENV_TYPE"

# If VM, ask for Model and Chassis
HW_MODEL=""
HW_CHASSIS=""
if [[ "$ENV_TYPE" == "VM" ]]; then
    HW_CHASSIS=$(whiptail --title "Chassis Size" --menu "Select the emulated Chassis Size:" 15 60 6 \
    "S45" "Storinator S45 (45 Drives)" \
    "Q30" "Storinator Q30 (30 Drives)" \
    "AV15" "Storinator AV15 (15 Drives)" \
    "HL15" "45HomeLab HL15 (15 Drives)" \
    "HL8" "45HomeLab HL8 (8 Drives)" \
    "XL60" "Storinator XL60 (60 Drives)" 3>&1 1>&2 2>&3)

    if [ -z "$HW_CHASSIS" ]; then
        msg_error "Installation cancelled."
    fi

    # Set Model name based on chassis
    if [[ "$HW_CHASSIS" == "HL15" || "$HW_CHASSIS" == "HL8" ]]; then
        HW_MODEL="HomeLab-$HW_CHASSIS"
    else
        HW_MODEL="Storinator-$HW_CHASSIS"
    fi
    
    log "Configured VM Hardware Spoofing: Model=$HW_MODEL, Chassis=$HW_CHASSIS"
fi

section "Installing 45Drives Repository"
msg_info "Adding 45Drives Repo"

# Clean up any previously broken lists to prevent apt update failures
rm -f /etc/apt/sources.list.d/45drives*.list

curl -sSL https://repo.45drives.com/setup -o /tmp/setup-repo.sh

# Patch setup-repo.sh for Ubuntu 24.04 (noble) compatibility using jammy repos
sed -i '/curl -sSL.*45drives-enterprise-$distro_codename.list/c\
    if [ "$distro_codename" = "noble" ]; then\n\
        curl -sSL https://repo.45drives.com/repofiles/$custom_distro/45drives-enterprise-jammy.list -o /etc/apt/sources.list.d/45drives-enterprise-jammy.list\n\
    else\n\
        curl -sSL https://repo.45drives.com/repofiles/$custom_distro/45drives-enterprise-$distro_codename.list -o /etc/apt/sources.list.d/45drives-enterprise-$distro_codename.list\n\
    fi' /tmp/setup-repo.sh
sed -i 's/\[\[ "$distro_codename" != "trixie" \]\]/\[\[ "$distro_codename" != "trixie" \]\] \&\& \[\[ "$distro_codename" != "noble" \]\]/g' /tmp/setup-repo.sh

bash /tmp/setup-repo.sh >> "$LOGFILE" 2>&1
rm -f /tmp/setup-repo.sh

if [[ "$PKG_MGR" == "apt" ]]; then
    msg_info "Setting apt preferences for 45Drives repo"
    cat <<EOF > /etc/apt/preferences.d/45drives.pref
Package: cockpit* 45drives-tools
Pin: origin "repo.45drives.com"
Pin-Priority: 1000

Package: *
Pin: origin "repo.45drives.com"
Pin-Priority: -1
EOF
fi

msg_ok "45Drives repository added"

section "Installing Packages"
PACKAGES="cockpit cockpit-45drives-hardware cockpit-file-sharing cockpit-navigator cockpit-identities cockpit-benchmark cockpit-zfs 45drives-tools realmd tuned udisks2-lvm2 zfsutils-linux samba winbind nfs-kernel-server nfs-client cockpit-scheduler"

if [[ "$PKG_MGR" == "apt" ]]; then
    msg_info "Updating apt cache"
    apt-get update -y -qq >> "$LOGFILE" 2>&1
    msg_ok "Updated apt cache"
    
    msg_info "Installing Houston packages (this may take a moment)"
    apt-get install -y -qq $PACKAGES >> "$LOGFILE" 2>&1
    msg_ok "Houston packages installed"
else
    msg_info "Installing Houston packages (this may take a moment)"
    dnf install -y -q $PACKAGES >> "$LOGFILE" 2>&1
    msg_ok "Houston packages installed"
fi

section "Configuring Environment"
if [[ "$ENV_TYPE" == "VM" ]]; then
    msg_info "Applying VM Hardware Spoofing"
    mkdir -p /etc/45drives/server_info/
    
    # Run dmap first so it discovers the passed-through HBA natively
    yes | dmap >> "$LOGFILE" 2>&1 || true
    
    # Inject the chosen chassis size and model using jq
    if [ -f /etc/45drives/server_info/server_info.json ]; then
        jq '.Model = "'$HW_MODEL'" | ."Chassis Size" = "'$HW_CHASSIS'" | ."Edit Mode" = true' /etc/45drives/server_info/server_info.json > /tmp/server_info.json && mv /tmp/server_info.json /etc/45drives/server_info/server_info.json
    fi
    msg_ok "Applied VM hardware overrides"

    msg_info "Masking OpenIPMI (VM Environment)"
    systemctl disable --now openipmi >> "$LOGFILE" 2>&1 || true
    systemctl mask openipmi >> "$LOGFILE" 2>&1 || true
    systemctl reset-failed >> "$LOGFILE" 2>&1 || true
    msg_ok "Masked OpenIPMI service"
fi

msg_info "Allowing root login to Cockpit UI"
if [ -f /etc/cockpit/disallowed-users ]; then
    sed -i 's/^root/#root/' /etc/cockpit/disallowed-users
fi
msg_ok "Allowed root login"

msg_info "Applying Van Auken Tech Custom Branding"
mkdir -p /usr/share/cockpit/branding/ubuntu
cat << 'EOF' > /usr/share/cockpit/branding/ubuntu/van-auken-tech-logo.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 80">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#00e676;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#00b0ff;stop-opacity:1" />
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="2.5" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="28" font-weight="900" fill="url(#grad)" filter="url(#glow)">Van Auken Tech</text>
</svg>
EOF

cat << 'EOF' > /usr/share/cockpit/branding/ubuntu/van-auken-tech-bg.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080">
  <defs>
    <radialGradient id="bgGrad" cx="50%" cy="50%" r="75%" fx="50%" fy="50%">
      <stop offset="0%" style="stop-color:#2a2a35;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0a0a0f;stop-opacity:1" />
    </radialGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#bgGrad)"/>
  <circle cx="10%" cy="20%" r="300" fill="#00e676" opacity="0.03" />
  <circle cx="90%" cy="80%" r="400" fill="#00b0ff" opacity="0.03" />
</svg>
EOF

cat << 'EOF' > /usr/share/cockpit/branding/ubuntu/branding.css
body.login-pf {
    background: url("van-auken-tech-bg.svg") no-repeat center center;
    background-size: cover;
    background-color: #0a0a0f;
}

#badge {
    position: fixed;
    bottom: 20px;
    right: 20px;
    inline-size: 220px;
    block-size: 80px;
    background-image: url("van-auken-tech-logo.svg");
    background-size: contain;
    background-repeat: no-repeat;
}

#brand {
    font-size: 18pt;
    text-transform: uppercase;
}

#brand::before {
    content: "Van Auken Tech UI";
}
EOF
msg_ok "Applied Van Auken Tech Custom Branding"

msg_info "Running 45Drives dmap utility"
yes | dmap >> "$LOGFILE" 2>&1 || true
msg_ok "Executed dmap utility"

msg_info "Restarting Cockpit service"
systemctl enable --now cockpit.socket >> "$LOGFILE" 2>&1
systemctl restart cockpit >> "$LOGFILE" 2>&1
msg_ok "Cockpit service restarted"

echo ""
echo -e "${GN}${BLD}  Houston UI installation is complete!${CL}"
echo -e "${BL}  Access the dashboard at: https://$(hostname -I | awk '{print $1}'):9090${CL}"
echo ""
