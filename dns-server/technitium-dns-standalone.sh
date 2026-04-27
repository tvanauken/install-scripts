#!/usr/bin/env bash

#=================================================================================================================
# VAN AUKEN TECH - INSTALL SCRIPTS COLLECTION
# Technitium DNS Server - Standalone Installation Script for Proxmox VE
#
# Copyright (c) 2026 Thomas Van Auken - Van Auken Tech
# License: MIT
# Repository: https://github.com/tvanauken/install-scripts
#
# This script creates a Debian 13 LXC container on Proxmox VE and installs Technitium DNS Server
#
# USAGE (run from Proxmox node command line):
#   bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
#
# FEATURES:
#  - Debian 13 (Trixie) LXC Container
#  - .NET 9.0 Runtime (ASP.NET Core)
#  - Technitium DNS Server (latest version)
#  - Advanced Blocking, Auto PTR, Drop Requests, Log Exporter, Query Logs (Sqlite) apps
#  - Hagezi blocklists (multi, popupads, tif, fake)
#  - Root hints DNS recursion (no forwarders)
#  - 2 CPU cores, 2GB RAM, 8GB disk (adjustable)
#=================================================================================================================

# Van Auken Tech color scheme
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\r\033[K"
HOLD=" "

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() { echo -ne " ${HOLD} ${YW}$1..."; }
msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; }

function header_info() {
clear
cat <<"EOF"
 _   _              _             _              _____         _     
| | | |            / \           | |            |_   _|       | |    
| | | | __ _ _ __ / _ \ _   _ ___| | _____ _ __   | | ___  ___| |__  
| | | |/ _` | '_ / ___ | | | / __| |/ / _ | '_ \  | |/ _ \/ __| '_ \ 
\ \_/ | (_| | | / /   \ |_| \__ |   |  __| | | | | |  __| (__| | | |
 \___/ \__,_|_|_/_/     \__,_|___|_|\_\___|_| |_| |_|\___|\___|_| |_|

 ████████╗███████╗ ██████╗██╗  ██╗███╗   ██╗██╗████████╗██╗██╗   ██╗███╗   ███╗
 ╚══██╔══╝██╔════╝██╔════╝██║  ██║████╗  ██║██║╚══██╔══╝██║██║   ██║████╗ ████║
    ██║   █████╗  ██║     ███████║██╔██╗ ██║██║   ██║   ██║██║   ██║██╔████╔██║
    ██║   ██╔══╝  ██║     ██╔══██║██║╚██╗██║██║   ██║   ██║██║   ██║██║╚██╔╝██║
    ██║   ███████╗╚██████╗██║  ██║██║ ╚████║██║   ██║   ██║╚██████╔╝██║ ╚═╝ ██║
    ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝     ╚═╝

                          DNS SERVER INSTALLATION                                
                    Created by Thomas Van Auken - Van Auken Tech

EOF
}

header_info
echo -e "\nThis script will create a Technitium DNS Server LXC container on Proxmox VE.\n"

# Generate random password for container
PASS="$(openssl rand -base64 12)"

# Get next available CT ID
CTID=$(pvesh get /cluster/nextid)

# Container configuration
PCT_OPTIONS=(
  -features keyctl=1,nesting=1
  -hostname technitium-dns
  -tags van-auken-tech
  -onboot 1
  -cores 2
  -memory 2048
  -password "$PASS"
  -net0 name=eth0,bridge=vmbr0,ip=dhcp
  -unprivileged 1
  -ostype debian
)

DEFAULT_PCT_OPTIONS=(
  -arch $(dpkg --print-architecture)
)

# Storage selection function
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
  
  # Query all storage locations
  local -a MENU
  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    local ITEM="  Type: $TYPE Free: $FREE "
    local OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      local MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')
  
  # Select storage location
  if [ $((${#MENU[@]}/3)) -eq 0 ]; then
    msg_error "'$CONTENT_LABEL' storage location not found"
    exit 1
  elif [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    local STORAGE
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Van Auken Tech - Proxmox VE Scripts" --title "Storage Pools" --radiolist \
        "Which storage pool would you like to use for the ${CONTENT_LABEL,,}?\nTo make a selection, use the Spacebar.\n" \
        16 $(($MSG_MAX_LENGTH + 23)) 6 \
        "${MENU[@]}" 3>&1 1>&2 2>&3) || exit
    done
    printf $STORAGE
  fi
}

# Get template storage - auto-select first available
msg_info "Detecting template storage"
TEMPLATE_STORAGE=$(pvesm status -content vztmpl | awk 'NR==2 {print $1}')
if [ -z "$TEMPLATE_STORAGE" ]; then
  msg_error "No template storage found"
  exit 1
fi
msg_ok "Using ${BL}$TEMPLATE_STORAGE${CL} for Template Storage"

# Get container storage - auto-select first available
msg_info "Detecting container storage"
CONTAINER_STORAGE=$(pvesm status -content rootdir | awk 'NR==2 {print $1}')
if [ -z "$CONTAINER_STORAGE" ]; then
  msg_error "No container storage found"
  exit 1
fi
msg_ok "Using ${BL}$CONTAINER_STORAGE${CL} for Container Storage"

# Update LXC template list
msg_info "Updating LXC Template List"
pveam update >/dev/null
msg_ok "Updated LXC Template List"

# Get Debian 13 template
TEMPLATE_SEARCH="debian-13"
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($TEMPLATE_SEARCH.*\)/\1/p" | sort -t - -k 2 -V)
[ ${#TEMPLATES[@]} -gt 0 ] || { msg_error "Unable to find Debian 13 template"; exit 1; }
TEMPLATE="${TEMPLATES[-1]}"

# Download LXC template if needed
if ! pveam list $TEMPLATE_STORAGE | grep -q $TEMPLATE; then
  msg_info "Downloading LXC Template"
  pveam download $TEMPLATE_STORAGE $TEMPLATE >/dev/null || { msg_error "Failed to download template"; exit 1; }
  msg_ok "Downloaded LXC Template"
fi

# Combine all options
PCT_OPTIONS=(${PCT_OPTIONS[@]:-${DEFAULT_PCT_OPTIONS[@]}})
[[ " ${PCT_OPTIONS[@]} " =~ " -rootfs " ]] || PCT_OPTIONS+=(-rootfs $CONTAINER_STORAGE:8)

# Create LXC Container
msg_info "Creating LXC Container"
pct create $CTID ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE} ${PCT_OPTIONS[@]} >/dev/null || { msg_error "Failed to create container"; exit 1; }
msg_ok "LXC Container ${BL}$CTID${CL} was successfully created"

# Save credentials
echo "Technitium DNS Server Container Credentials" > ~/technitium-dns-$CTID.creds
echo "Container ID: $CTID" >> ~/technitium-dns-$CTID.creds
echo "Root Password: $PASS" >> ~/technitium-dns-$CTID.creds
echo "Credentials saved to: ~/technitium-dns-$CTID.creds" >> ~/technitium-dns-$CTID.creds

# Start container
msg_info "Starting LXC Container"
pct start "$CTID"
sleep 5
msg_ok "Started LXC Container"

# Wait for network
msg_info "Waiting for container network (30 seconds)"
sleep 30
msg_ok "Container network ready"

# Get container IP
IP=""
max_attempts=10
attempt=1
while [[ $attempt -le $max_attempts ]]; do
  IP=$(pct exec $CTID -- ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
  if [[ -n $IP ]]; then
    break
  else
    echo -e "${YW}Attempt $attempt: IP address not found. Waiting...${CL}"
    sleep 3
    ((attempt++))
  fi
done

if [[ -z $IP ]]; then
  msg_error "Failed to get IP address"
  IP="NOT FOUND"
fi

# Install Technitium DNS Server
msg_info "Installing Technitium DNS Server in container"

pct exec $CTID -- bash -c "
export DEBIAN_FRONTEND=noninteractive

# Update system
apt-get update >/dev/null 2>&1
apt-get -y upgrade >/dev/null 2>&1

# Install dependencies
apt-get install -y curl sudo mc gnupg ca-certificates jq wget lsb-release >/dev/null 2>&1

# Add Microsoft repository for Debian
# Debian 13 (trixie) uses bookworm packages as trixie repos don't exist yet
DEBIAN_VERSION=12
curl -fsSL https://packages.microsoft.com/config/debian/\${DEBIAN_VERSION}/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb >/dev/null 2>&1
rm -f /tmp/packages-microsoft-prod.deb
apt-get update >/dev/null 2>&1

# Install .NET 9.0 Runtime
apt-get install -y aspnetcore-runtime-9.0 >/dev/null 2>&1

# Download Technitium DNS Server
mkdir -p /opt/technitium/dns /etc/dns
curl -fsSL https://download.technitium.com/dns/DnsServerPortable.tar.gz -o /tmp/DnsServerPortable.tar.gz
tar -xzf /tmp/DnsServerPortable.tar.gz -C /opt/technitium/dns
rm /tmp/DnsServerPortable.tar.gz

# Create systemd service
cat <<'SERVICEEOF' >/etc/systemd/system/dns.service
[Unit]
Description=Technitium DNS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/technitium/dns
ExecStart=/usr/bin/dotnet /opt/technitium/dns/DnsServerApp.dll /etc/dns
Restart=on-failure
RestartPreventExitStatus=1
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable -q --now dns.service

# Wait for service to start
sleep 20

# Get API token
TOKEN=\$(cat /etc/dns/dns.config | jq -r '.webServiceRootApiToken // empty')
if [ -z \"\$TOKEN\" ]; then
    echo 'Failed to get API token'
    exit 1
fi

# Store credentials
echo \"token=\$TOKEN\" > /etc/dns/.creds
chmod 600 /etc/dns/.creds

# Wait for API
sleep 5

# Install apps
curl -fsSL https://download.technitium.com/dns/apps/AdvancedBlockingApp-v10.zip -o /tmp/AdvancedBlocking.zip
curl -X POST -F 'dnsApp=@/tmp/AdvancedBlocking.zip' \"http://localhost:5380/api/apps/install?token=\$TOKEN\" >/dev/null 2>&1
rm /tmp/AdvancedBlocking.zip

curl -fsSL https://download.technitium.com/dns/apps/AutoPtrApp-v4.zip -o /tmp/AutoPtr.zip
curl -X POST -F 'dnsApp=@/tmp/AutoPtr.zip' \"http://localhost:5380/api/apps/install?token=\$TOKEN\" >/dev/null 2>&1
rm /tmp/AutoPtr.zip

curl -fsSL https://download.technitium.com/dns/apps/DropRequestsApp-v7.zip -o /tmp/DropRequests.zip
curl -X POST -F 'dnsApp=@/tmp/DropRequests.zip' \"http://localhost:5380/api/apps/install?token=\$TOKEN\" >/dev/null 2>&1
rm /tmp/DropRequests.zip

curl -fsSL https://download.technitium.com/dns/apps/LogExporterApp-v2.1.zip -o /tmp/LogExporter.zip
curl -X POST -F 'dnsApp=@/tmp/LogExporter.zip' \"http://localhost:5380/api/apps/install?token=\$TOKEN\" >/dev/null 2>&1
rm /tmp/LogExporter.zip

curl -fsSL https://download.technitium.com/dns/apps/QueryLogsSqliteApp-v8.zip -o /tmp/QueryLogs.zip
curl -X POST -F 'dnsApp=@/tmp/QueryLogs.zip' \"http://localhost:5380/api/apps/install?token=\$TOKEN\" >/dev/null 2>&1
rm /tmp/QueryLogs.zip

# Configure blocklists
BLOCKLISTS='https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/multi.txt'
BLOCKLISTS=\"\$BLOCKLISTS,https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/popupads.txt\"
BLOCKLISTS=\"\$BLOCKLISTS,https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/tif.txt\"
BLOCKLISTS=\"\$BLOCKLISTS,https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/fake.txt\"
curl -X POST \"http://localhost:5380/api/settings/set?token=\$TOKEN&blockListUrls=\$BLOCKLISTS&enableBlocking=true\" >/dev/null 2>&1

# Configure DNS recursion
curl -X POST \"http://localhost:5380/api/settings/set?token=\$TOKEN&recursion=Allow&randomizeName=false&qnameMinimization=true\" >/dev/null 2>&1

# Cleanup
apt-get -y autoremove >/dev/null 2>&1
apt-get -y autoclean >/dev/null 2>&1
"

msg_ok "Installed Technitium DNS Server"

# Success message
header_info
echo
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${GN}  Technitium DNS Server installation completed successfully!${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo
echo -e "${BL}Container ID:${CL} ${GN}$CTID${CL}"
echo -e "${BL}IP Address:${CL} ${GN}$IP${CL}"
echo -e "${BL}Web Interface:${CL} ${BGN}http://$IP:5380${CL}"
echo
echo -e "${YW}Default Credentials:${CL}"
echo -e "  ${BL}Username:${CL} ${GN}admin${CL}"
echo -e "  ${BL}Password:${CL} ${GN}admin${CL}"
echo
echo -e "${RD}⚠ IMPORTANT: Change the default password immediately!${CL}"
echo
echo -e "${BL}Root Password:${CL} ${GN}$PASS${CL}"
echo -e "${BL}Credentials File:${CL} ~/technitium-dns-$CTID.creds"
echo
echo -e "${GN}Created by Thomas Van Auken - Van Auken Tech${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo
