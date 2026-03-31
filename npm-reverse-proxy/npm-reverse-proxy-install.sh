#!/usr/bin/env bash
# ============================================================================
#  Nginx Proxy Manager — Post-Install Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.1.0
#  Date:       2026-03-31
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
# Run this script AFTER deploying the Nginx Proxy Manager LXC from:
#   https://community-scripts.org/scripts?id=nginxproxymanager
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
LOGFILE="/var/log/npm-config-$(date +%Y%m%d-%H%M%S).log"
API_TOKEN=""
NPM_IP=""
ADMIN_NAME=""
ADMIN_EMAIL=""
ADMIN_PASS=""
CERT_CRT=""
CERT_KEY=""
CERT_NAME=""

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
  echo -e "${DGN}  ── Nginx Proxy Manager — Post-Install Configuration ────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "NPM Post-Install Config Log - $(date)" > "$LOGFILE"
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
  printf "  ${GN}[▸]${CL}  ${BLD}Fresh install (web UI setup wizard never opened):${CL}\n"
  printf "        Enter the email and password you WANT to create.\n"
  printf "        This script creates the admin account via the API automatically.\n"
  echo ""
  printf "  ${YW}[▸]${CL}  ${BLD}Already completed the NPM web UI setup wizard:${CL}\n"
  printf "        Enter the email and password you already set up.\n"
  printf "        The script will skip account creation and log in directly.\n"
  echo ""

  read -rp "  ${BL}NPM LXC IP address${CL}: " NPM_IP
  [[ -z "$NPM_IP" ]] && { msg_error "IP address is required"; exit 1; }

  read -rp "  ${BL}Admin full name${CL}: " ADMIN_NAME
  [[ -z "$ADMIN_NAME" ]] && ADMIN_NAME="Administrator"

  read -rp "  ${BL}Admin email address${CL}: " ADMIN_EMAIL
  [[ -z "$ADMIN_EMAIL" ]] && { msg_error "Admin email is required"; exit 1; }

  while true; do
    read -rsp "  ${BL}Admin password${CL}: " ADMIN_PASS; echo ""
    read -rsp "  ${BL}Confirm password${CL}: " PASS_CONFIRM; echo ""
    [[ "$ADMIN_PASS" == "$PASS_CONFIRM" ]] && break
    msg_warn "Passwords do not match — try again"
  done

  echo ""
  echo -e "  ${BL}${BLD}Wildcard SSL Certificate — press Enter to skip:${CL}"
  read -rp "  ${BL}Path to .crt file${CL}: " CERT_CRT
  if [[ -n "$CERT_CRT" ]]; then
    if [[ ! -f "$CERT_CRT" ]]; then
      msg_warn "File not found: ${CERT_CRT} — skipping cert import"
      CERT_CRT=""
    else
      read -rp "  ${BL}Path to .key file${CL}: " CERT_KEY
      if [[ ! -f "$CERT_KEY" ]]; then
        msg_warn "File not found: ${CERT_KEY} — skipping cert import"
        CERT_CRT=""
        CERT_KEY=""
      else
        read -rp "  ${BL}Certificate friendly name${CL} [Wildcard Certificate]: " CERT_NAME
        CERT_NAME="${CERT_NAME:-Wildcard Certificate}"
      fi
    fi
  fi

  echo ""
  msg_ok "Configuration collected"
}

# ── Wait for Service ──────────────────────────────────────────────────────────
wait_for_service() {
  section "Connectivity Check"
  msg_info "Checking http://${NPM_IP}:81"
  local attempts=0 max=30
  while (( attempts < max )); do
    if curl -s --connect-timeout 2 "http://${NPM_IP}:81/api" &>/dev/null; then
      msg_ok "Nginx Proxy Manager is reachable at http://${NPM_IP}:81"
      return 0
    fi
    (( attempts++ ))
    sleep 2
  done
  msg_error "NPM not reachable after ${max} attempts — is the LXC running and port 81 open?"
  exit 1
}

# ── Create Admin Account ──────────────────────────────────────────────────────
create_admin() {
  section "Admin Account"
  msg_info "Attempting to create account: ${ADMIN_EMAIL}"

  local payload
  payload=$(jq -n \
    --arg name "$ADMIN_NAME" \
    --arg email "$ADMIN_EMAIL" \
    --arg pass "$ADMIN_PASS" \
    '{name: $name, nickname: "Admin", email: $email, password: $pass, is_disabled: false, roles: ["admin"]}')

  local response
  response=$(curl -s -X POST \
    "http://${NPM_IP}:81/api/users" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    2>>"$LOGFILE")

  echo "Create admin response: ${response:0:300}" >> "$LOGFILE"

  local error
  error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)

  if [[ -z "$error" ]]; then
    msg_ok "Admin account created: ${ADMIN_EMAIL}"
  else
    # Account already exists — normal if web UI wizard was completed first
    msg_ok "Account already exists — logging in with provided credentials"
    echo "Note: ${error}" >> "$LOGFILE"
  fi
}

# ── Authenticate ──────────────────────────────────────────────────────────────
get_token() {
  section "Authenticating"
  msg_info "Logging in as ${ADMIN_EMAIL}"

  local payload
  payload=$(jq -n \
    --arg identity "$ADMIN_EMAIL" \
    --arg secret "$ADMIN_PASS" \
    '{identity: $identity, secret: $secret}')

  local response
  response=$(curl -s -X POST \
    "http://${NPM_IP}:81/api/tokens" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    2>>"$LOGFILE")

  echo "Login response: ${response:0:300}" >> "$LOGFILE"

  local error
  error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)

  if [[ -n "$error" ]]; then
    msg_error "Authentication failed: ${error}"
    msg_error "If you used the NPM web UI wizard first, make sure you entered those exact credentials above"
    exit 1
  fi

  API_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)

  if [[ -z "$API_TOKEN" ]]; then
    msg_error "Failed to retrieve API token from response"
    exit 1
  fi

  msg_ok "Authenticated — token acquired"
}

# ── Import Wildcard Certificate ───────────────────────────────────────────────
import_cert() {
  [[ -z "$CERT_CRT" || -z "$CERT_KEY" ]] && return

  section "Importing Wildcard SSL Certificate"
  msg_info "Uploading: ${CERT_NAME}"

  local response
  response=$(curl -s -X POST \
    "http://${NPM_IP}:81/api/nginx/certificates" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -F "certificate=@${CERT_CRT}" \
    -F "certificate_key=@${CERT_KEY}" \
    -F "nice_name=${CERT_NAME}" \
    -F "provider=other" \
    2>>"$LOGFILE")

  echo "Import cert response: ${response:0:300}" >> "$LOGFILE"

  local cert_id
  cert_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)
  local error
  error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)

  if [[ -n "$cert_id" ]]; then
    msg_ok "Certificate imported: ${CERT_NAME} (ID: ${cert_id})"
  else
    msg_warn "Certificate import: ${error:-see log for details}"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  local cert_status
  if [[ -n "$CERT_CRT" ]]; then
    cert_status="${CERT_NAME} imported"
  else
    cert_status="Not imported — add via Web UI"
  fi

  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       CONFIGURATION COMPLETE — Nginx Proxy Manager${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  echo -e "  ${GN}${BLD}Nginx Proxy Manager configured successfully.${CL}"
  echo ""
  printf "  ${DGN}Server     :${CL}  ${BL}http://${NPM_IP}:81${CL}\n"
  printf "  ${DGN}Admin      :${CL}  ${BL}${ADMIN_EMAIL}${CL}\n"
  printf "  ${DGN}SSL Cert   :${CL}  ${BL}${cert_status}${CL}\n"
  echo ""
  echo -e "  ${YW}Next steps:${CL}"
  printf "  ${DGN}[▸]${CL}  Open http://${NPM_IP}:81 and log in\n"
  printf "  ${DGN}[▸]${CL}  Add Proxy Hosts: Hosts → Proxy Hosts → Add Proxy Host\n"
  printf "  ${DGN}[▸]${CL}  Assign your SSL certificate to each proxy host\n"
  printf "  ${DGN}[▸]${CL}  Enable Force SSL and HTTP/2 on each proxy host\n"
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
  create_admin
  get_token
  import_cert
  summary
}

main "$@"
