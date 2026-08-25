#!/usr/bin/env bash
# ============================================================================
#  Van Auken Tech - Houston / 45Drives - Universal Installer
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       $(date +%Y-%m-%d)
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================

# ── Colour Palette ────────────────────────────────────────────────────────────
RD="\033[38;5;131m"    # Muted Red (Error)
YW="\033[38;5;137m"    # Muted Yellow (Warning)
GN="\033[38;5;108m"    # Muted Green (Success)
DGN="\033[38;5;67m"    # Steel Blue (Headers)
BL="\033[38;5;110m"    # Light Blue Gray (Info)
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
  echo -e "${DGN}  ── Van Auken Tech - Houston / 45Drives - Universal Installer ───────────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "Houston UI Install Log - $(date)" > "$LOGFILE"
}

# ── Main ──────────────────────────────────────────────────────────────────────

if [ -f /etc/os-release ]; then
    source /etc/os-release
fi

header_info

if [[ $EUID -ne 0 ]]; then
   msg_error "This script must be run as root"
fi

# Ensure whiptail is available
if ! command -v whiptail &> /dev/null; then
  msg_info "Installing whiptail"
  apt-get update -y -qq >/dev/null 2>&1
  apt-get install -y whiptail jq -qq >/dev/null 2>&1
  msg_ok "Installed whiptail and jq"
fi

# 1. Ask Deployment Type
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
ALIAS_STYLE=""
if [[ "$ENV_TYPE" == "VM" ]]; then
    HW_CHASSIS=$(whiptail --title "Chassis Size" --menu "Select the emulated Chassis Size:" 15 60 6 \
    "S45" "Storinator S45 Turbo (45 Drives)" \
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
        ALIAS_STYLE="HOMELAB"
    else
        HW_MODEL="Storinator-$HW_CHASSIS"
        ALIAS_STYLE="STORINATOR"
    fi
    log "Configured VM Hardware Spoofing: Model=$HW_MODEL, Chassis=$HW_CHASSIS"
fi

section "Sanitizing Environment"
msg_info "Purging conflicting network and VM packages from previous states"
apt-get remove -y --purge network-manager network-manager-gnome network-manager-pptp modemmanager wpasupplicant cockpit-networkmanager >> "$LOGFILE" 2>&1
apt-get autoremove -y >> "$LOGFILE" 2>&1
msg_ok "Environment sanitized"

section "Installing 45Drives Repository"
msg_info "Configuring APT Sideloading"

# Import 45Drives GPG Key
wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
# Add the Jammy list (since newer OSes aren't natively supported by 45Drives yet)
echo "deb [signed-by=/usr/share/keyrings/45drives-archive-keyring.gpg] https://repo.45drives.com/enterprise/ubuntu jammy main" > /etc/apt/sources.list.d/45drives-enterprise-jammy.list

msg_info "Setting apt preferences for 45Drives repo"
MAJOR_VER=$(echo "$VERSION_ID" | cut -d. -f1)
if [[ "$ID" == "ubuntu" && "$MAJOR_VER" -ge 24 ]]; then
    # Strict pinning for 24.04/26.04+ to force OS-native ZFS and Samba
    cat <<PREF > /etc/apt/preferences.d/45drives.pref
Package: cockpit* 45drives-tools
Pin: origin "repo.45drives.com"
Pin-Priority: 1000

Package: *
Pin: origin "repo.45drives.com"
Pin-Priority: 100
PREF
else
    # 22.04 and 20.04 require the 45Drives forks of ZFS (zfs-dkms/zfs-zed)
    rm -f /etc/apt/preferences.d/45drives.pref
fi

apt-get update -y -qq >> "$LOGFILE" 2>&1
msg_ok "45Drives repository added and pinned"

section "Installing Packages"
msg_info "Installing dependencies and Houston UI"
PACKAGES="zfsutils-linux samba winbind realmd nfs-kernel-server cockpit cockpit-bridge cockpit-ws cockpit-system cockpit-45drives-hardware cockpit-file-sharing cockpit-navigator cockpit-identities cockpit-benchmark cockpit-zfs cockpit-ceph cockpit-s3-browser 45drives-tools"

if [[ "$ENV_TYPE" == "BAREMETAL" ]]; then
    PACKAGES="$PACKAGES cockpit-machines cockpit-podman podman"
elif [[ "$ENV_TYPE" == "VM" ]]; then
    msg_info "Purging nested virtualization plugins (VM Environment)"
    apt-get remove -y --purge cockpit-machines cockpit-podman podman libvirt-daemon-system libvirt-clients >> "$LOGFILE" 2>&1 || true
    msg_ok "Virtualization plugins purged"
fi

if [[ "$MAJOR_VER" -ge 24 ]]; then
    PACKAGES="$PACKAGES cockpit-super-simple-setup"
fi

apt-get install -y -qq $PACKAGES >> "$LOGFILE" 2>&1
msg_ok "Packages installed successfully"

section "Configuring Networking"
msg_info "Enabling native systemd-networkd rendering"
rm -f /etc/NetworkManager/conf.d/20-connectivity.conf
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i 's/managed=true/managed=false/' /etc/NetworkManager/NetworkManager.conf
fi
sed -i '/renderer: NetworkManager/d' /etc/netplan/*.yaml 2>/dev/null || true
netplan apply >> "$LOGFILE" 2>&1 || true
systemctl enable --now systemd-networkd >> "$LOGFILE" 2>&1 || true
systemctl restart systemd-networkd >> "$LOGFILE" 2>&1 || true
msg_ok "Native systemd-networkd restored"

msg_info "Fixing systemd-udev-settle race condition for ZFS (Forward Compatible)"
# OpenZFS upstream removed udev-settle dependencies. Older versions (like 2.1.5 in Ubuntu 22.04/24.04) 
# still require it, which causes 120s boot hangs when passed-through HBAs take time to spin up.
# We dynamically find any ZFS service requiring this deprecated target and surgically remove the dependency.
for zfs_service_path in $(grep -l "systemd-udev-settle.service" /lib/systemd/system/zfs-*.service 2>/dev/null); do
    zfs_service=$(basename "$zfs_service_path")
    cp "$zfs_service_path" "/etc/systemd/system/${zfs_service}"
    sed -i 's/^Requires=systemd-udev-settle.service/#Requires=systemd-udev-settle.service/' "/etc/systemd/system/${zfs_service}"
    sed -i 's/^After=systemd-udev-settle.service/#After=systemd-udev-settle.service/' "/etc/systemd/system/${zfs_service}"
done
systemctl daemon-reload >> "$LOGFILE" 2>&1
msg_ok "ZFS udev-settle dependencies dynamically resolved"

section "Configuring Environment"
if [[ "$ENV_TYPE" == "VM" ]]; then
    msg_info "Applying VM Hardware Overrides"
    mkdir -p /etc/45drives/server_info/
    
    if [ -f /etc/45drives/server_info/server_info.json ]; then
        # Ensure Edit Mode is false so dynamic scanning works, but spoofing is forced by python patch
        jq '.Model = "'\"$HW_MODEL\"'" | .VM = false | ."Edit Mode" = false' /etc/45drives/server_info/server_info.json > /tmp/server_info.json && mv /tmp/server_info.json /etc/45drives/server_info/server_info.json
    else
        # Create it if it doesn't exist yet
        cat <<JSONEOF > /etc/45drives/server_info/server_info.json
{
  "Model": "$HW_MODEL",
  "VM": false,
  "Edit Mode": false
}
JSONEOF
    fi
    
    # Patch the underlying Python script to spoof the chassis layout and avoid QEMU generic fallback
    if [ -f /opt/45drives/tools/server_identifier ]; then
        sed -i 's/server\["VM"\] = vm_check(server\["Motherboard"\])/server["VM"] = False/' /opt/45drives/tools/server_identifier
        sed -i 's/def vm_passthrough(server):/def vm_passthrough(server):\n\tpass\n\ndef old_vm_passthrough(server):/' /opt/45drives/tools/server_identifier
        
        # Inject dynamic spoofing lines right before update_json_file
        if ! grep -q "server\[\"Model\"\] = \"$HW_MODEL\"" /opt/45drives/tools/server_identifier; then
            sed -i '/update_json_file(server,scan_time)/i \
\tserver["Model"] = "'\"$HW_MODEL\"'"\
\tserver["Chassis Size"] = "'\"$HW_CHASSIS\"'"\
\tserver["Alias Style"] = "'\"$ALIAS_STYLE\"'"' /opt/45drives/tools/server_identifier
        fi
    fi
    msg_ok "Applied VM hardware overrides"

    msg_info "Disabling libvirt default network (VM Environment)"
    virsh net-destroy default >/dev/null 2>&1 || true
    virsh net-autostart --disable default >/dev/null 2>&1 || true
    msg_ok "Disabled virbr0"
fi

msg_info "Allowing root login to Cockpit UI"
if [ -f /etc/cockpit/disallowed-users ]; then
    sed -i 's/^root/#root/' /etc/cockpit/disallowed-users
fi
msg_ok "Allowed root login"

msg_info "Applying Van Auken Tech Custom Branding"
mkdir -p /usr/share/cockpit/branding/ubuntu
cat << 'SVG1' > /usr/share/cockpit/branding/ubuntu/van-auken-tech-logo.svg
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
SVG1

cat << 'SVG2' > /usr/share/cockpit/branding/ubuntu/van-auken-tech-bg.svg
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
SVG2

cat << 'CSS1' > /usr/share/cockpit/branding/ubuntu/branding.css
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
CSS1
msg_ok "Applied Van Auken Tech Custom Branding"


msg_info "Restarting Cockpit service"
systemctl enable --now cockpit.socket >> "$LOGFILE" 2>&1
systemctl restart cockpit >> "$LOGFILE" 2>&1
msg_ok "Cockpit service restarted"

echo ""
echo -e "${GN}${BLD}  Van Auken Tech - Houston / 45Drives - Universal Installer installation is complete!${CL}"
echo -e "${BL}  Access the dashboard at: https://$(hostname -I | awk '{print $1}'):9090${CL}"
echo ""
