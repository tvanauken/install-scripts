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
  _  _  ___ ___       _                 _    _               _              
 | || || __|   \ _ _ (_)_ _____ ___    | |_ | |___ _  _ ___ | |_ ___ _ _    
 | __ ||__ \ |) | '_|| \ V / -_)_-<    | ' \| / _ \ || (_-< |  _/ _ \ ' \   
 |_||_||___/___/|_|  |_|\_/\___/__/    |_||_|_\___/\_,_/__/  \__\___/_||_|  
                                                                            
BANNER
  echo -e "${CL}"
  echo -e "${DGN}  ── 45Drives Houston UI Installer ───────────────────────────────────${CL}"
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
curl -sSL https://repo.45drives.com/setup -o /tmp/setup-repo.sh
bash /tmp/setup-repo.sh >> "$LOGFILE" 2>&1
rm -f /tmp/setup-repo.sh
msg_ok "45Drives repository added"

section "Installing Packages"
PACKAGES="cockpit cockpit-45drives-hardware cockpit-file-sharing cockpit-navigator cockpit-identities cockpit-benchmark cockpit-zfs 45drives-tools"

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
    cat > /etc/45drives/server_info/server_info.json <<EOF
{
    "Motherboard": {
        "Manufacturer": "VIRTUAL_MACHINE",
        "Product Name": "VM_MOTHERBOARD",
        "Serial Number": "VIRTUAL_MACHINE"
    },
    "HBA": [],
    "Hybrid": false,
    "Serial": "VIRTUAL_MACHINE",
    "Model": "${HW_MODEL}",
    "Alias Style": "STORINATOR",
    "Chassis Size": "${HW_CHASSIS}",
    "VM": true,
    "Edit Mode": true,
    "OS NAME": "Linux",
    "OS VERSION_ID": "",
    "Auto Alias": false,
    "HWRAID": false
}
EOF
    msg_ok "Applied VM hardware overrides"

    msg_info "Masking OpenIPMI (VM Environment)"
    systemctl disable --now openipmi >> "$LOGFILE" 2>&1 || true
    systemctl mask openipmi >> "$LOGFILE" 2>&1 || true
    systemctl reset-failed >> "$LOGFILE" 2>&1 || true
    msg_ok "Masked OpenIPMI service"
fi

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
