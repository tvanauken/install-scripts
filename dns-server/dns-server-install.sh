#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Post-Install Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.1.0
#  Date:       2026-03-31
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
# Run this script AFTER deploying the Technitium DNS LXC from:
#   https://community-scripts.org/scripts?id=technitiumdns
# ============================================================================

set -o pipefail

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
LOGFILE="/var/log/dns-server-config-$(date +%Y%m%d-%H%M%S).log"
API_TOKEN=""
DNS_IP=""
DNS_USER=""
DNS_PASS=""
PRIMARY_ZONE=""
EXTRA_ZONES=()
FORWARDERS="1.1.1.1,9.9.9.9"
ENABLE_RFC2136="y"
ALL_ZONES=()

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD}  Script interrupted (exit ${code})${CL}\n"
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
msg_info()  { printf "${TAB}${YW}◆  %s...${CL}\r" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔  %-55s${CL}\n" "$1"; }
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
  echo -e "${DGN}  ── Technitium DNS Server — Post-Install Configuration ──────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "DNS Server Post-Install Config Log - $(date)" > "$LOGFILE"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"
  if [[ $EUID -ne 0 ]]; then
    msg_error "Must be run as root — aborting"
    exit 1
  fi
  msg_ok "Running as root"

  for tool in curl jq; do
    if ! command -v "$tool" &>/dev/null; then
      msg_info "Installing ${tool}"
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$tool" >> "$LOGFILE" 2>&1
      msg_ok "${tool} installed"
    else
      msg_ok "${tool} available"
    fi
  done
}

# ── Collect Configuration ─────────────────────────────────────────────────────
collect_config() {
  section "Configuration"

  echo -e "  ${BL}${BLD}About admin credentials:${CL}"
  echo ""
  printf "  ${GN}[▸]${CL}  ${BLD}Fresh install (web UI never opened):${CL}\n"
  printf "        Enter the username and password you WANT to create.\n"
  printf "        This script creates the account via the API automatically.\n"
  echo ""
  printf "  ${YW}[▸]${CL}  ${BLD}Already completed the web UI setup wizard:${CL}\n"
  printf "        Enter the username and password you already set up.\n"
  printf "        The script will skip account creation and log in directly.\n"
  echo ""

  read -rp "  ${BL}Technitium LXC IP address${CL}: " DNS_IP
  [[ -z "$DNS_IP" ]] && { msg_error "IP address is required"; exit 1; }

  read -rp "  ${BL}Admin username${CL} [admin]: " DNS_USER
  DNS_USER="${DNS_USER:-admin}"

  while true; do
    read -rsp "  ${BL}Admin password${CL}: " DNS_PASS; echo ""
    read -rsp "  ${BL}Confirm password${CL}: " PASS_CONFIRM; echo ""
    [[ "$DNS_PASS" == "$PASS_CONFIRM" ]] && break
    msg_warn "Passwords do not match — try again"
  done

  read -rp "  ${BL}Primary internal zone${CL} (e.g. home.vanauken.tech): " PRIMARY_ZONE
  [[ -z "$PRIMARY_ZONE" ]] && { msg_error "Primary zone is required"; exit 1; }

  read -rp "  ${BL}Additional zones${CL} (comma-separated, or Enter to skip): " extra_input
  if [[ -n "$extra_input" ]]; then
    IFS=',' read -ra EXTRA_ZONES <<< "$extra_input"
    for i in "${!EXTRA_ZONES[@]}"; do
      EXTRA_ZONES[$i]="${EXTRA_ZONES[$i]//[[:space:]]/}"
    done
  fi

  read -rp "  ${BL}Upstream forwarders${CL} [1.1.1.1,9.9.9.9]: " fw_input
  [[ -n "$fw_input" ]] && FORWARDERS="$fw_input"

  read -rp "  ${BL}Enable RFC 2136 dynamic updates on all zones?${CL} [Y/n]: " rfc_input
  [[ "${rfc_input,,}" == "n" ]] && ENABLE_RFC2136="n"

  echo ""
  msg_ok "Configuration collected"

  ALL_ZONES=("$PRIMARY_ZONE" "${EXTRA_ZONES[@]}")
}

# ── Wait for Service ──────────────────────────────────────────────────────────
wait_for_service() {
  section "Connectivity Check"
  msg_info "Checking http://${DNS_IP}:5380"
  local attempts=0 max=30
  while (( attempts < max )); do
    if curl -s --connect-timeout 2 "http://${DNS_IP}:5380/api/user/login" &>/dev/null; then
      msg_ok "Technitium DNS is reachable at http://${DNS_IP}:5380"
      return 0
    fi
    (( attempts++ ))
    sleep 2
  done
  msg_error "Technitium DNS not reachable after ${max} attempts — is the LXC running and port 5380 open?"
  exit 1
}

# ── Create Admin Account ──────────────────────────────────────────────────────
create_account() {
  section "Admin Account"
  msg_info "Attempting to create account: ${DNS_USER}"

  local response
  response=$(curl -s -X POST \
    "http://${DNS_IP}:5380/api/user/createAccount" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    --data-urlencode "displayName=Administrator" \
    2>>"$LOGFILE")

  echo "Create account response: $response" >> "$LOGFILE"

  local status
  status=$(echo "$response" | jq -r '.status' 2>/dev/null)

  if [[ "$status" == "ok" ]]; then
    msg_ok "Admin account created: ${DNS_USER}"
  else
    local err
    err=$(echo "$response" | jq -r '.errorMessage // .error // "unknown"' 2>/dev/null)
    # Account already exists — normal if web UI was used first
    msg_ok "Account already exists — logging in with provided credentials"
    echo "Note: ${err}" >> "$LOGFILE"
  fi
}

# ── Authenticate ──────────────────────────────────────────────────────────────
get_token() {
  section "Authenticating"
  msg_info "Logging in as ${DNS_USER}"

  local response
  response=$(curl -s -X POST \
    "http://${DNS_IP}:5380/api/user/login" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    --data-urlencode "includeInfo=true" \
    2>>"$LOGFILE")

  echo "Login response: ${response:0:300}" >> "$LOGFILE"

  local status
  status=$(echo "$response" | jq -r '.status' 2>/dev/null)

  if [[ "$status" != "ok" ]]; then
    local err
    err=$(echo "$response" | jq -r '.errorMessage // .error // "Login failed"' 2>/dev/null)
    msg_error "Authentication failed: ${err}"
    msg_error "If you already set up an account via the web UI, make sure you entered those exact credentials above"
    exit 1
  fi

  API_TOKEN=$(echo "$response" | jq -r '.response.token' 2>/dev/null)

  if [[ -z "$API_TOKEN" || "$API_TOKEN" == "null" ]]; then
    msg_error "Failed to retrieve API token from response"
    exit 1
  fi

  msg_ok "Authenticated — token acquired"
}

# ── Configure Recursion and Forwarders ───────────────────────────────────────
configure_recursion() {
  section "Configuring Recursion and Forwarders"
  msg_info "Applying settings"

  local response
  response=$(curl -s -X POST \
    "http://${DNS_IP}:5380/api/settings/set" \
    --data-urlencode "token=${API_TOKEN}" \
    --data-urlencode "recursion=AllowAll" \
    --data-urlencode "forwarders=${FORWARDERS}" \
    --data-urlencode "forwarderProtocol=Udp" \
    2>>"$LOGFILE")

  echo "Settings response: $response" >> "$LOGFILE"

  local status
  status=$(echo "$response" | jq -r '.status' 2>/dev/null)

  if [[ "$status" == "ok" ]]; then
    msg_ok "Recursion enabled (Allow All)"
    msg_ok "Forwarders set: ${FORWARDERS}"
  else
    local err
    err=$(echo "$response" | jq -r '.errorMessage // .error // "Settings update failed"' 2>/dev/null)
    msg_warn "Settings update: ${err}"
  fi
}

# ── Create Zones ──────────────────────────────────────────────────────────────
create_zones() {
  section "Creating DNS Zones"

  for zone in "${ALL_ZONES[@]}"; do
    [[ -z "$zone" ]] && continue
    msg_info "Creating zone: ${zone}"

    local response
    response=$(curl -s -X POST \
      "http://${DNS_IP}:5380/api/zones/create" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "type=Primary" \
      2>>"$LOGFILE")

    echo "Create zone [${zone}]: $response" >> "$LOGFILE"

    local status
    status=$(echo "$response" | jq -r '.status' 2>/dev/null)

    if [[ "$status" == "ok" ]]; then
      msg_ok "Zone created: ${zone}"
    else
      local err
      err=$(echo "$response" | jq -r '.errorMessage // .error // "Zone creation failed"' 2>/dev/null)
      msg_warn "Zone [${zone}]: ${err}"
    fi
  done
}

# ── Enable RFC 2136 ───────────────────────────────────────────────────────────
enable_rfc2136() {
  [[ "$ENABLE_RFC2136" != "y" ]] && return
  section "Enabling RFC 2136 Dynamic Updates"

  for zone in "${ALL_ZONES[@]}"; do
    [[ -z "$zone" ]] && continue
    msg_info "Enabling RFC 2136: ${zone}"

    local response
    response=$(curl -s -X POST \
      "http://${DNS_IP}:5380/api/zones/options/set" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "allowDynamicUpdates=true" \
      2>>"$LOGFILE")

    echo "RFC2136 [${zone}]: $response" >> "$LOGFILE"

    local status
    status=$(echo "$response" | jq -r '.status' 2>/dev/null)

    if [[ "$status" == "ok" ]]; then
      msg_ok "RFC 2136 enabled: ${zone}"
    else
      local err
      err=$(echo "$response" | jq -r '.errorMessage // .error // "Options update failed"' 2>/dev/null)
      msg_warn "RFC 2136 [${zone}]: ${err}"
    fi
  done
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  local rfc_status
  rfc_status=$([ "$ENABLE_RFC2136" == "y" ] && echo "Enabled" || echo "Disabled")

  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       CONFIGURATION COMPLETE — Technitium DNS Server${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  echo -e "  ${GN}${BLD}Technitium DNS Server configured successfully.${CL}"
  echo ""
  printf "  ${DGN}Server       :${CL}  ${BL}http://${DNS_IP}:5380${CL}\n"
  printf "  ${DGN}Admin user   :${CL}  ${BL}${DNS_USER}${CL}\n"
  printf "  ${DGN}Primary zone :${CL}  ${BL}${PRIMARY_ZONE}${CL}\n"
  if [[ ${#EXTRA_ZONES[@]} -gt 0 && -n "${EXTRA_ZONES[0]}" ]]; then
    printf "  ${DGN}Extra zones  :${CL}  ${BL}%s${CL}\n" "${EXTRA_ZONES[*]}"
  fi
  printf "  ${DGN}Forwarders   :${CL}  ${BL}${FORWARDERS}${CL}\n"
  printf "  ${DGN}RFC 2136     :${CL}  ${BL}${rfc_status}${CL}\n"
  echo ""
  echo -e "  ${YW}Next steps:${CL}"
  printf "  ${DGN}[▸]${CL}  Open http://${DNS_IP}:5380 and add A/CNAME/PTR records\n"
  printf "  ${DGN}[▸]${CL}  Point DHCP clients to ${DNS_IP} as their DNS server\n"
  echo ""
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
  collect_config
  wait_for_service
  create_account
  get_token
  configure_recursion
  create_zones
  enable_rfc2136
  summary
}

main "$@"
