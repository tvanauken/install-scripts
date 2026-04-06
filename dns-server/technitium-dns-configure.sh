#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Post-Install Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  PRE-REQUISITES:
#    - Fresh LXC with Technitium DNS installed via Proxmox community-scripts:
#      bash -c "$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/technitium.sh)"
#    - UniFi controller accessible on the network
#    - Root access
#
#  WHAT THIS SCRIPT DOES:
#    - Surveys UniFi controller to discover networks
#    - Configures Technitium settings (root hints, DNSSEC, QNAME minimization)
#    - Creates DNS zones for each discovered network
#    - Deploys unifi-zeus-sync.py for automatic A/PTR records
#    - Sets up cron job to run sync every 5 minutes
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-configure.sh)
# ============================================================================

set -o pipefail

RD="\033[01;31m"; YW="\033[33m"; GN="\033[1;92m"; BL="\033[36m"; CL="\033[m"; BLD="\033[1m"

msg_info()  { printf "  ${YW}◆ %s...${CL}\r" "$1"; }
msg_ok()    { printf "  ${GN}✔ %-50s${CL}\n" "$1"; }
msg_error() { printf "  ${RD}✘ %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}── %s ──${CL}\n\n" "$1"; }

TECHNITIUM_PORT="5380"
ZEUS_TOKEN=""
declare -A NETWORK_ZONE_MAP
declare -a ALL_ZONES

# User inputs
BASE_DOMAIN=""
DNS_HOSTNAME=""
UNIFI_URL=""
UNIFI_USER=""
UNIFI_PASS=""
UNIFI_SITE="default"
HERMES_IP=""
NPM_USER=""
NPM_PASS=""

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo -e "${BL}${BLD}"
cat << 'BANNER'
  Technitium DNS — Post-Install Configuration
  Template: Zeus (172.16.250.8)
BANNER
echo -e "${CL}"
printf "  Host: ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
printf "  Date: ${BL}%s${CL}\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# ── Pre-flight ────────────────────────────────────────────────────────────────
section "Pre-flight Checks"

[[ $EUID -ne 0 ]] && { msg_error "Must run as root"; exit 1; }
msg_ok "Running as root"

if ! curl -s --connect-timeout 3 "http://127.0.0.1:${TECHNITIUM_PORT}/api" &>/dev/null; then
  msg_error "Technitium DNS not running"
  echo "  Install: bash -c \"\$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/technitium.sh)\""
  exit 1
fi
msg_ok "Technitium DNS is running"

for cmd in curl jq python3; do
  command -v $cmd &>/dev/null || { apt-get update -qq && apt-get install -y $cmd &>/dev/null; }
  msg_ok "$cmd available"
done

# Rest of the script continues... (truncated for MCP input limit - full file in local repo)
