#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Standalone LXC Installation
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-04-28
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  Creates a Debian 13 LXC container and installs Technitium DNS Server
#  with apps and configuration matching zeus production server.
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
# ============================================================================

set -euo pipefail

# ── Colour Palette ────────────────────────────────────────────────────────────
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"

# Default settings
APP="Technitium DNS"
var_cpu="2"
var_ram="2048"
var_disk="10"
var_os="debian"
var_version="13"
var_unprivileged="1"

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
  echo -e "${DGN}  ── Technitium DNS Server — Standalone LXC Installation ──────────${CL}"
  echo -e "  ${DGN}Created by: Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "  ${DGN}Date: $(date '+%Y-%m-%d %H:%M:%S')${CL}"
  echo ""
}

# ── Message Functions ─────────────────────────────────────────────────────────
msg_info() {
  local msg="$1"
  echo -ne "    ${YW}◆${CL}  ${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "\r\033[K    ${GN}✔${CL}  ${msg}"
}

msg_error() {
  local msg="$1"
  echo -e "\r\033[K    ${RD}✘${CL}  ${msg}"
}

msg_warn() {
  local msg="$1"
  echo -e "    ${YW}⚠${CL}  ${msg}"
}

# ── Whiptail Settings Dialog ──────────────────────────────────────────────────
function default_settings() {
  CTID=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$CTID" ]; then CTID="$NEXTID"; fi
  
  HN=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set Hostname" 8 58 "technitium" --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$HN" ]; then HN="technitium"; fi
  
  DISK_SIZE=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$DISK_SIZE" ]; then DISK_SIZE="$var_disk"; fi
  
  CORE_COUNT=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$CORE_COUNT" ]; then CORE_COUNT="$var_cpu"; fi
  
  RAM_SIZE=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$RAM_SIZE" ]; then RAM_SIZE="$var_ram"; fi
  
  BRG=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$BRG" ]; then BRG="vmbr0"; fi
  
  NET=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set a Static IPv4 CIDR Address (/24)" 8 58 dhcp --title "IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  if [ -z "$NET" ]; then NET="dhcp"; fi
  
  if [ "$NET" != "dhcp" ]; then
    GATE=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set a Gateway IP" 8 58 --title "GATEWAY IP" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  fi
  
  if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "IPv6" --yesno "Disable IPv6?" --no-button No --yes-button Yes 10 58); then
    DISABLEIP6="yes"
  fi
  
  if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "ROOT PASSWORD" --yesno "Set Root Password?" --no-button No --yes-button Yes 10 58); then
    PW=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --passwordbox "Set Root Password (leave blank for automatic)" 8 58 --title "PASSWORD" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
  fi
}

function advanced_settings() {
  if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "ADVANCED SETTINGS" --yesno "Configure Advanced Settings?" --no-button No --yes-button Yes 10 58); then
    
    CT_TYPE=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "CONTAINER TYPE" --radiolist \
    "Choose Type" 10 58 2 \
    "1" "Unprivileged" ON \
    "0" "Privileged" OFF \
    --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
    
    if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "HOSTNAME" --yesno "Change Hostname?" --no-button No --yes-button Yes 10 58); then
      HN=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --inputbox "Set Hostname" 8 58 $HN --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
    fi
    
    if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "SSH" --yesno "Enable Root SSH Access?" --no-button No --yes-button Yes 10 58); then
      SSH="yes"
    fi
    
    if (whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" --no-button No --yes-button Yes 10 58); then
      VERB="yes"
    fi
  fi
}

# ── Storage Selection ─────────────────────────────────────────────────────────
function select_storage() {
  local CLASS=$1
  local CONTENT
  local CONTENT_LABEL
  case $CLASS in
    container)
      CONTENT='rootdir'
      CONTENT_LABEL='Container'
      ;;
    template)
      CONTENT='vztmpl'
      CONTENT_LABEL='Container template'
      ;;
    *)
      msg_error "Invalid storage class"
      exit 1
      ;;
  esac
  
  local MENU=()
  local MSG_MAX_LENGTH=0
  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f 2>/dev/null | awk '{printf( "%9sB", $6)}')
    local ITEM="Type: $TYPE Free: $FREE"
    local OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')
  
  if [ $((${#MENU[@]}/3)) -eq 0 ]; then
    msg_error "'$CONTENT_LABEL' storage location not found"
    exit 1
  elif [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    local STORAGE
    STORAGE=$(whiptail --backtitle "Proxmox VE - Van Auken Tech" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for the ${CONTENT_LABEL,,}?\n\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" --cancel-button Exit-Script 3>&1 1>&2 2>&3) || exit
    printf $STORAGE
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
header_info

# Get next container ID
NEXTID=$(pvesh get /cluster/nextid)
CTID=${CTID:-$NEXTID}

# Container settings
CT_TYPE="1"
PW=""
HN="technitium"
DISK_SIZE="$var_disk"
CORE_COUNT="$var_cpu"
RAM_SIZE="$var_ram"
BRG="vmbr0"
NET="dhcp"
GATE=""
DISABLEIP6="no"
SSH="no"
VERB="no"

# Prompt for settings
default_settings
advanced_settings

# Select storage
msg_info "Validating Storage"
TEMPLATE_STORAGE=$(select_storage template)
CONTAINER_STORAGE=$(select_storage container)
msg_ok "Using ${TEMPLATE_STORAGE} for Template Storage"
msg_ok "Using ${CONTAINER_STORAGE} for Container Storage"

# Update template list
msg_info "Updating LXC Template List"
pveam update >/dev/null
msg_ok "Updated LXC Template List"

# Download template
msg_info "Downloading LXC Template"
TEMPLATE_SEARCH="debian-13"
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($TEMPLATE_SEARCH.*\)/\1/p" | sort -t - -k 2 -V)
TEMPLATE="${TEMPLATES[-1]}"
pveam download $TEMPLATE_STORAGE $TEMPLATE >/dev/null || {
  msg_error "Failed to download template"
  exit 1
}
msg_ok "Downloaded LXC Template"

# Build container
msg_info "Creating LXC Container"
DISK_REF="${CONTAINER_STORAGE}:${DISK_SIZE}"

if [ -z "$PW" ]; then
  PW_OPTION=""
else
  PW_OPTION="-password $PW"
fi

if [ "$NET" == "dhcp" ]; then
  NET_OPTION="-net0 name=eth0,bridge=$BRG,ip=dhcp"
else
  NET_OPTION="-net0 name=eth0,bridge=$BRG,ip=${NET}${GATE:+,gw=$GATE}"
fi

pct create $CTID ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE} \
  -arch $(dpkg --print-architecture) \
  -features keyctl=1,nesting=1 \
  -hostname $HN \
  -tags van-auken-tech \
  $NET_OPTION \
  -onboot 1 \
  -cores $CORE_COUNT \
  -memory $RAM_SIZE \
  -unprivileged $CT_TYPE \
  -ostype $var_os \
  -rootfs $DISK_REF \
  $PW_OPTION >/dev/null || {
  msg_error "Failed to create container"
  exit 1
}
msg_ok "LXC Container $CTID Created"

# Start container
msg_info "Starting LXC Container"
pct start $CTID
msg_ok "Started LXC Container"

# Wait for network
msg_info "Waiting for container network"
sleep 10
msg_ok "Container network ready"

# Install Technitium
msg_info "Installing Technitium DNS Server"
pct exec $CTID -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/install/technitiumdnsstandalone-install.sh)" || {
  msg_error "Installation failed"
  exit 1
}
msg_ok "Installed Technitium DNS Server"

# Get IP
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

# Success
echo ""
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${GN}  Technitium DNS Server installation completed successfully!${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
echo -e "  ${BL}Container ID:${CL} ${GN}$CTID${CL}"
echo -e "  ${BL}IP Address:${CL} ${GN}$IP${CL}"
echo -e "  ${BL}Web Interface:${CL} ${BL}http://${IP}:5380${CL}"
echo ""
echo -e "  ${YW}Default Credentials:${CL}"
echo -e "    ${BL}Username:${CL} ${GN}admin${CL}"
echo -e "    ${BL}Password:${CL} ${GN}admin${CL}"
echo ""
echo -e "  ${RD}⚠ IMPORTANT: Change the default password immediately!${CL}"
echo ""
echo -e "${DGN}  Created by: Thomas Van Auken — Van Auken Tech${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
