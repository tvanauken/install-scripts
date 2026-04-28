#!/usr/bin/env bash

# Copyright (c) 2025 Thomas Van Auken - Van Auken Tech
# License: MIT
# Repository: https://github.com/tvanauken/install-scripts
# Source: https://technitium.com/dns/

# Default settings
APP="Technitium DNS"
var_cpu="2"
var_ram="2048"
var_disk="10"
var_os="debian"
var_version="13"

# Colors
RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\r\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# Functions
msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

header_info() {
  clear
  cat <<"EOF"
    ______           __          _ __  _                   ____  _   _______
   /_  __/__  _____/ /_  ____  (_) /_(_)_  ______ ___   / __ \/ | / / ___/
    / / / _ \/ ___/ __ \/ __ \/ / __/ / / / / __ `__ \ / / / /  |/ /\__ \ 
   / / /  __/ /__/ / / / / / / / /_/ / /_/ / / / / / // /_/ / /|  /___/ / 
  /_/  \___/\___/_/ /_/_/ /_/_/\__/_/\__,_/_/ /_/ /_//_____/_/ |_//____/  
                                                                            
  Technitium DNS Server - Standalone LXC Installation
  Created by Thomas Van Auken - Van Auken Tech
  
EOF
}

set -euo pipefail
header_info

# Get next container ID
NEXTID=$(pvesh get /cluster/nextid)
CTID=${CTID:-$NEXTID}

# Container settings
CT_TYPE="1"
PW=""
CT_NAME="technitium"
HN="technitium"
DISK_SIZE="$var_disk"
CORE_COUNT="$var_cpu"
RAM_SIZE="$var_ram"
BRG="vmbr0"
NET="dhcp"
GATE=""
APT_CACHER=""
APT_CACHER_IP=""
DISABLEIP6="no"
MTU=""
SD=""
NS=""
MAC=""
VLAN=""
SSH="no"
VERB="no"

# Whiptail dialogs
function default_settings() {
  CTID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" 3>&1 1>&2 2>&3)
  if [ -z "$CTID" ]; then CTID="$NEXTID"; fi
  
  HN=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 $CT_NAME --title "HOSTNAME" 3>&1 1>&2 2>&3)
  if [ -z "$HN" ]; then HN="$CT_NAME"; fi
  
  DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" 3>&1 1>&2 2>&3)
  if [ -z "$DISK_SIZE" ]; then DISK_SIZE="$var_disk"; fi
  
  CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" 3>&1 1>&2 2>&3)
  if [ -z "$CORE_COUNT" ]; then CORE_COUNT="$var_cpu"; fi
  
  RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" 3>&1 1>&2 2>&3)
  if [ -z "$RAM_SIZE" ]; then RAM_SIZE="$var_ram"; fi
  
  BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" 3>&1 1>&2 2>&3)
  if [ -z "$BRG" ]; then BRG="vmbr0"; fi
  
  NET=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Static IPv4 CIDR Address (/24)" 8 58 dhcp --title "IP ADDRESS" 3>&1 1>&2 2>&3)
  if [ -z "$NET" ]; then NET="dhcp"; fi
  
  if [ "$NET" != "dhcp" ]; then
    GATE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Gateway IP" 8 58 --title "GATEWAY IP" 3>&1 1>&2 2>&3)
  fi
  
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "IPv6" --yesno "Disable IPv6?" 10 58); then
    DISABLEIP6="yes"
  fi
  
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ROOT PASSWORD" --yesno "Set Root Password?" 10 58); then
    PW=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Root Password" 8 58 --title "PASSWORD (leave blank for automatic)" 3>&1 1>&2 2>&3)
  fi
}

function advanced_settings() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS" --yesno "Configure Advanced Settings?" 10 58); then
    
    CT_TYPE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CONTAINER TYPE" --radiolist \
    "Choose Type" 10 58 2 \
    "1" "Unprivileged" ON \
    "0" "Privileged" OFF \
    3>&1 1>&2 2>&3)
    
    if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "HOSTNAME" --yesno "Change Hostname?" 10 58); then
      HN=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 $HN --title "HOSTNAME" 3>&1 1>&2 2>&3)
    fi
    
    if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SSH" --yesno "Enable Root SSH Access?" 10 58); then
      SSH="yes"
    fi
    
    if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" 10 58); then
      VERB="yes"
    fi
  fi
}

# Storage selection
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
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for the ${CONTENT_LABEL,,}?\n\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" 3>&1 1>&2 2>&3) || exit
    done
    printf $STORAGE
  fi
}

# Main installation
default_settings
advanced_settings

msg_info "Validating Storage"
TEMPLATE_STORAGE=$(select_storage template) || exit
CONTAINER_STORAGE=$(select_storage container) || exit
msg_ok "Using ${TEMPLATE_STORAGE} for Template Storage"
msg_ok "Using ${CONTAINER_STORAGE} for Container Storage"

msg_info "Updating LXC Template List"
pveam update >/dev/null
msg_ok "Updated LXC Template List"

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

msg_info "Starting LXC Container"
pct start $CTID
msg_ok "Started LXC Container"

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

msg_ok "Completed Successfully!\n"
echo -e "${GN}Technitium DNS Server LXC is now ready to use!${CL}\n"
echo -e "${YW}Access it at:${CL} ${GN}http://${IP}:5380${CL}"
echo -e "${YW}Default credentials:${CL} ${GN}admin / admin${CL}"
echo -e "${RD}⚠ CHANGE DEFAULT PASSWORD IMMEDIATELY!${CL}\n"
