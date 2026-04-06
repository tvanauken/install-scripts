#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Full Installation & Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    3.0.0
#  Date:       2026-04-05
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  Installs Technitium DNS Server from scratch on any Debian-based distro.
#  Surveys UniFi network to discover VLANs and builds zone structure dynamically.
#  Deploys unifi-zeus-sync script for automatic DNS record management.
#  PRIVACY: Root hints recursion ONLY - no external forwarders.
#
#  Template: Zeus production server
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
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
SCRIPT_VERSION="3.0.0"
LOGFILE="/var/log/technitium-dns-install-$(date +%Y%m%d-%H%M%S).log"
TECHNITIUM_PORT="5380"

# Configuration - collected during survey/prompts
DNS_IP=""
DNS_USER=""
DNS_PASS=""
BASE_DOMAIN=""
UNIFI_URL=""
UNIFI_USER=""
UNIFI_PASS=""
UNIFI_SITE="default"
HERMES_IP=""
NPM_URL=""
NPM_USER=""
NPM_PASS=""
API_TOKEN=""
ZEUS_TOKEN=""

# Discovered networks
declare -A NETWORK_ZONE_MAP
declare -a ALL_ZONES
declare -a REVERSE_SUBNETS

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  if [[ $code -ne 0 ]]; then
    echo -e "\n${RD}  Script interrupted or failed (exit ${code})${CL}"
    echo -e "${YW}  Check the log file for details: ${LOGFILE}${CL}\n"
  fi
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
log()       { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"; }
msg_info()  { printf "${TAB}${YW}◆  %s...${CL}\r" "$1"; log "INFO: $1"; }
msg_ok()    { printf "${TAB}${GN}✔  %-55s${CL}\n" "$1"; log "OK: $1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; log "ERROR: $1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; log "WARN: $1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; log "SECTION: $1"; }

# ── OS Detection ──────────────────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME="${NAME:-Unknown}"
    OS_VERSION="${VERSION_ID:-Unknown}"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"
    OS_ID="${ID:-unknown}"
  else
    OS_NAME="Unknown"
    OS_VERSION="Unknown"
    OS_CODENAME="unknown"
    OS_ID="unknown"
  fi
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
  echo -e "${DGN}  ── Technitium DNS Server — Full Installation ────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}OS     :${CL}  ${BL}%s %s (%s)${CL}\n" "$OS_NAME" "$OS_VERSION" "$OS_CODENAME"
  printf "  ${DGN}Script :${CL}  ${BL}v%s${CL}\n" "$SCRIPT_VERSION"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "Technitium DNS Full Install Log - $(date)" > "$LOGFILE"
  log "OS: $OS_NAME $OS_VERSION ($OS_CODENAME) - ID: $OS_ID"
}

# ── Preflight Checks ──────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"
  
  if [[ $EUID -ne 0 ]]; then
    msg_error "Must be run as root — aborting"
    exit 1
  fi
  msg_ok "Running as root"
  
  if ! command -v apt-get &>/dev/null; then
    msg_error "Only apt-based distributions are supported"
    exit 1
  fi
  msg_ok "APT package manager available"
  
  msg_info "Checking internet connectivity"
  if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    msg_error "No internet connectivity"
    exit 1
  fi
  msg_ok "Internet connectivity confirmed"
  
  DNS_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  msg_ok "Detected IP address: ${DNS_IP}"
}

# ── Collect Configuration ─────────────────────────────────────────────────────
collect_config() {
  section "Configuration"
  
  echo -e "  ${BL}${BLD}This script installs Technitium DNS Server and configures it${CL}"
  echo -e "  ${BL}${BLD}for split-horizon DNS with UniFi network integration.${CL}"
  echo ""
  
  # DNS Server IP
  read -rp "  ${BL}DNS Server IP address${CL} [${DNS_IP}]: " ip_input
  [[ -n "$ip_input" ]] && DNS_IP="$ip_input"
  
  # Admin credentials
  echo ""
  echo -e "  ${BL}${BLD}Technitium Admin Account:${CL}"
  read -rp "  ${BL}Admin username${CL} [admin]: " DNS_USER
  DNS_USER="${DNS_USER:-admin}"
  
  while true; do
    read -rsp "  ${BL}Admin password${CL}: " DNS_PASS; echo ""
    [[ ${#DNS_PASS} -ge 8 ]] && break
    msg_warn "Password must be at least 8 characters"
  done
  
  # Base domain
  echo ""
  echo -e "  ${BL}${BLD}Domain Configuration:${CL}"
  read -rp "  ${BL}Base domain (e.g., home.example.com)${CL}: " BASE_DOMAIN
  [[ -z "$BASE_DOMAIN" ]] && { msg_error "Base domain is required"; exit 1; }
  
  # UniFi Controller
  echo ""
  echo -e "  ${BL}${BLD}UniFi Controller (for network discovery and sync):${CL}"
  read -rp "  ${BL}UniFi Controller URL (e.g., https://192.168.1.1)${CL}: " UNIFI_URL
  [[ -z "$UNIFI_URL" ]] && { msg_error "UniFi URL is required"; exit 1; }
  
  read -rp "  ${BL}UniFi username${CL}: " UNIFI_USER
  [[ -z "$UNIFI_USER" ]] && { msg_error "UniFi username is required"; exit 1; }
  
  read -rsp "  ${BL}UniFi password${CL}: " UNIFI_PASS; echo ""
  [[ -z "$UNIFI_PASS" ]] && { msg_error "UniFi password is required"; exit 1; }
  
  read -rp "  ${BL}UniFi site${CL} [default]: " site_input
  [[ -n "$site_input" ]] && UNIFI_SITE="$site_input"
  
  # Hermes (NPM) for proxy integration
  echo ""
  echo -e "  ${BL}${BLD}Reverse Proxy Integration (optional):${CL}"
  read -rp "  ${BL}Hermes/NPM IP (or Enter to skip)${CL}: " HERMES_IP
  
  if [[ -n "$HERMES_IP" ]]; then
    read -rp "  ${BL}NPM Web UI URL${CL} [http://${HERMES_IP}:81]: " npm_url_input
    NPM_URL="${npm_url_input:-http://${HERMES_IP}:81}"
    read -rp "  ${BL}NPM admin email${CL}: " NPM_USER
    read -rsp "  ${BL}NPM admin password${CL}: " NPM_PASS; echo ""
  fi
  
  # Reverse DNS subnets
  echo ""
  echo -e "  ${BL}${BLD}Reverse DNS Subnets:${CL}"
  echo -e "  ${DGN}Enter subnets for PTR records (e.g., 172.16.250,192.168.1)${CL}"
  read -rp "  ${BL}Subnets (comma-separated)${CL}: " subnet_input
  
  if [[ -n "$subnet_input" ]]; then
    IFS=',' read -ra REVERSE_SUBNETS <<< "$subnet_input"
  fi
  
  msg_ok "Configuration collected"
}

# ── Survey UniFi Network ──────────────────────────────────────────────────────
survey_unifi() {
  section "Surveying UniFi Network"
  
  msg_info "Connecting to UniFi Controller"
  
  local cookie_jar="/tmp/unifi_cookies_$$"
  
  # Login to UniFi
  local login_response
  login_response=$(curl -sk -c "$cookie_jar" -b "$cookie_jar" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${UNIFI_USER}\",\"password\":\"${UNIFI_PASS}\"}" \
    "${UNIFI_URL}/api/auth/login" 2>>"$LOGFILE")
  
  if ! echo "$login_response" | grep -q "unique_id"; then
    msg_error "Failed to authenticate with UniFi Controller"
    log "UniFi login response: $login_response"
    rm -f "$cookie_jar"
    exit 1
  fi
  msg_ok "Authenticated with UniFi Controller"
  
  # Get networks
  msg_info "Discovering networks"
  local networks_response
  networks_response=$(curl -sk -b "$cookie_jar" \
    "${UNIFI_URL}/proxy/network/api/s/${UNIFI_SITE}/rest/networkconf" 2>>"$LOGFILE")
  
  log "Networks response: ${networks_response:0:500}"
  
  # Parse networks and build zone map
  local network_count=0
  while IFS= read -r line; do
    local net_id net_name purpose
    net_id=$(echo "$line" | jq -r '._id // empty')
    net_name=$(echo "$line" | jq -r '.name // empty')
    purpose=$(echo "$line" | jq -r '.purpose // empty')
    
    [[ -z "$net_id" || -z "$net_name" ]] && continue
    [[ "$purpose" == "wan" ]] && continue
    
    # Sanitize network name for DNS zone
    local zone_name
    zone_name=$(echo "$net_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    
    local zone_fqdn="${zone_name}.${BASE_DOMAIN}"
    NETWORK_ZONE_MAP["$net_id"]="$zone_fqdn"
    ALL_ZONES+=("$zone_fqdn")
    
    log "Discovered network: $net_name (ID: $net_id) -> $zone_fqdn"
    ((network_count++))
  done < <(echo "$networks_response" | jq -c '.data[]' 2>/dev/null)
  
  # Add base domain and backend zones
  ALL_ZONES+=("$BASE_DOMAIN")
  ALL_ZONES+=("backend.${BASE_DOMAIN}")
  
  for zone in "${ALL_ZONES[@]}"; do
    [[ "$zone" != "$BASE_DOMAIN" && "$zone" != "backend.${BASE_DOMAIN}" ]] && \
      ALL_ZONES+=("backend.${zone}")
  done
  
  rm -f "$cookie_jar"
  
  msg_ok "Discovered ${network_count} networks"
  
  echo ""
  echo -e "  ${BL}${BLD}Zones to be created:${CL}"
  for zone in "${ALL_ZONES[@]}"; do
    printf "  ${DGN}  • %s${CL}\n" "$zone"
  done
  echo ""
  
  read -rp "  ${YW}Continue with these zones? [Y/n]:${CL} " proceed
  [[ "${proceed,,}" == "n" ]] && exit 0
}

# ── Install Prerequisites ─────────────────────────────────────────────────────
install_prerequisites() {
  section "Installing Prerequisites"
  
  msg_info "Updating package lists"
  DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
  msg_ok "Package lists updated"
  
  local prereqs=(curl wget gnupg2 ca-certificates jq dnsutils python3 cron)
  
  for pkg in "${prereqs[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      msg_ok "${pkg} already installed"
    else
      msg_info "Installing ${pkg}"
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1
      msg_ok "${pkg} installed"
    fi
  done
}

# ── Install Technitium DNS Server ─────────────────────────────────────────────
install_technitium() {
  section "Installing Technitium DNS Server"
  
  msg_info "Downloading Technitium DNS installer"
  curl -fsSL https://download.technitium.com/dns/install.sh -o /tmp/technitium-install.sh >> "$LOGFILE" 2>&1
  msg_ok "Downloaded installer"
  
  msg_info "Running Technitium installer"
  bash /tmp/technitium-install.sh >> "$LOGFILE" 2>&1
  rm -f /tmp/technitium-install.sh
  msg_ok "Technitium DNS Server installed"
  
  msg_info "Waiting for DNS service to start"
  local attempts=0
  while (( attempts < 30 )); do
    if curl -s --connect-timeout 2 "http://127.0.0.1:${TECHNITIUM_PORT}/api/user/login" &>/dev/null; then
      msg_ok "DNS service is running"
      return 0
    fi
    ((attempts++))
    sleep 2
  done
  
  msg_error "DNS service failed to start"
  exit 1
}

# ── Configure DNS Server ──────────────────────────────────────────────────────
configure_dns() {
  section "Configuring DNS Server"
  
  local api_base="http://127.0.0.1:${TECHNITIUM_PORT}/api"
  
  msg_info "Creating admin account"
  curl -s -X POST "${api_base}/user/createAccount" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    >> "$LOGFILE" 2>&1
  msg_ok "Admin account created"
  
  msg_info "Authenticating"
  local response
  response=$(curl -s -X POST "${api_base}/user/login" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    --data-urlencode "includeInfo=true")
  
  API_TOKEN=$(echo "$response" | jq -r '.response.token // empty')
  ZEUS_TOKEN="$API_TOKEN"
  
  if [[ -z "$API_TOKEN" ]]; then
    msg_error "Authentication failed"
    exit 1
  fi
  msg_ok "Authenticated"
  
  # Configure server settings - ROOT HINTS ONLY
  msg_info "Configuring server settings (root hints recursion)"
  curl -s -X POST "${api_base}/settings/set" \
    --data-urlencode "token=${API_TOKEN}" \
    --data-urlencode "dnsServerDomain=$(hostname -s).${BASE_DOMAIN}" \
    --data-urlencode "recursion=AllowOnlyForPrivateNetworks" \
    --data-urlencode "forwarders=" \
    --data-urlencode "preferIPv6=false" \
    --data-urlencode "dnssecValidation=true" \
    --data-urlencode "qnameMinimization=true" \
    --data-urlencode "resolverRetries=2" \
    --data-urlencode "resolverTimeout=1500" \
    --data-urlencode "resolverConcurrency=3" \
    --data-urlencode "saveCache=true" \
    --data-urlencode "serveStale=true" \
    --data-urlencode "serveStaleTtl=259200" \
    --data-urlencode "cacheMaximumEntries=40000" \
    --data-urlencode "enableLogging=true" \
    --data-urlencode "logQueries=true" \
    >> "$LOGFILE" 2>&1
  msg_ok "Root hints recursion configured (no external forwarders)"
  
  msg_info "Configuring DNS blocking"
  curl -s -X POST "${api_base}/settings/set" \
    --data-urlencode "token=${API_TOKEN}" \
    --data-urlencode "enableBlocking=true" \
    --data-urlencode "blockingType=NxDomain" \
    --data-urlencode "blockListUrls=https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/multi.txt,https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/tif.txt,https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/fake.txt" \
    --data-urlencode "blockListUpdateIntervalHours=24" \
    >> "$LOGFILE" 2>&1
  msg_ok "DNS blocking enabled with hagezi blocklists"
}

# ── Create DNS Zones ──────────────────────────────────────────────────────────
create_zones() {
  section "Creating DNS Zones"
  
  local api_base="http://127.0.0.1:${TECHNITIUM_PORT}/api"
  
  # Remove duplicates
  local -A seen
  local unique_zones=()
  for zone in "${ALL_ZONES[@]}"; do
    [[ -z "$zone" ]] && continue
    if [[ -z "${seen[$zone]}" ]]; then
      seen[$zone]=1
      unique_zones+=("$zone")
    fi
  done
  
  for zone in "${unique_zones[@]}"; do
    msg_info "Creating zone: ${zone}"
    curl -s -X POST "${api_base}/zones/create" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "type=Primary" \
      >> "$LOGFILE" 2>&1
    
    curl -s -X POST "${api_base}/zones/options/set" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "allowDynamicUpdates=true" \
      >> "$LOGFILE" 2>&1
    
    msg_ok "Zone created: ${zone}"
  done
  
  # Create reverse zones
  for subnet in "${REVERSE_SUBNETS[@]}"; do
    subnet="${subnet//[[:space:]]/}"
    [[ -z "$subnet" ]] && continue
    
    IFS='.' read -ra octets <<< "$subnet"
    local reverse_zone=""
    for (( i=${#octets[@]}-1; i>=0; i-- )); do
      reverse_zone+="${octets[i]}."
    done
    reverse_zone+="in-addr.arpa"
    
    msg_info "Creating reverse zone: ${reverse_zone}"
    curl -s -X POST "${api_base}/zones/create" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${reverse_zone}" \
      --data-urlencode "type=Primary" \
      >> "$LOGFILE" 2>&1
    
    curl -s -X POST "${api_base}/zones/options/set" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${reverse_zone}" \
      --data-urlencode "allowDynamicUpdates=true" \
      >> "$LOGFILE" 2>&1
    
    msg_ok "Reverse zone created: ${reverse_zone}"
  done
}

# ── Deploy UniFi Sync Script ──────────────────────────────────────────────────
deploy_sync_script() {
  section "Deploying UniFi-Zeus Sync Script"
  
  mkdir -p /var/lib/unifi-zeus-sync
  mkdir -p /usr/local/bin
  
  msg_info "Creating sync configuration"
  
  # Build network_zone_map JSON
  local zone_map_json="{"
  local first=true
  for net_id in "${!NETWORK_ZONE_MAP[@]}"; do
    [[ "$first" == "true" ]] && first=false || zone_map_json+=","
    zone_map_json+="\"${net_id}\":\"${NETWORK_ZONE_MAP[$net_id]}\""
  done
  zone_map_json+="}"
  
  cat > /etc/unifi-zeus-sync.conf << EOF
{
  "unifi_url": "${UNIFI_URL}",
  "unifi_user": "${UNIFI_USER}",
  "unifi_pass": "${UNIFI_PASS}",
  "unifi_site": "${UNIFI_SITE}",
  "zeus_url": "http://localhost:5380",
  "zeus_token": "${ZEUS_TOKEN}",
  "dns_ttl": 300,
  "sync_comment": "unifi-sync",
  "hermes_ip": "${HERMES_IP:-}",
  "npm_url": "${NPM_URL:-}",
  "npm_user": "${NPM_USER:-}",
  "npm_pass": "${NPM_PASS:-}",
  "log_file": "/var/log/unifi-zeus-sync.log",
  "network_zone_map": ${zone_map_json}
}
EOF
  chmod 600 /etc/unifi-zeus-sync.conf
  msg_ok "Sync configuration created"
  
  msg_info "Deploying sync script"
  cat > /usr/local/bin/unifi-zeus-sync.py << 'SYNCSCRIPT'
#!/usr/bin/env python3
"""
unifi-zeus-sync.py
Reads active clients from UniFi and reconciles A + PTR records in Technitium.
Author: Thomas Van Auken - Van Auken Tech
"""
import urllib.request
import urllib.parse
import http.cookiejar
import ssl
import json
import re
import logging
import sys
import os

CONFIG_FILE = "/etc/unifi-zeus-sync.conf"
STATE_FILE  = "/var/lib/unifi-zeus-sync/state.json"

with open(CONFIG_FILE) as f:
    cfg = json.load(f)

UNIFI_URL    = cfg["unifi_url"]
UNIFI_USER   = cfg["unifi_user"]
UNIFI_PASS   = cfg["unifi_pass"]
UNIFI_SITE   = cfg["unifi_site"]
ZEUS_URL     = cfg["zeus_url"]
ZEUS_TOKEN   = cfg["zeus_token"]
DNS_TTL      = cfg["dns_ttl"]
SYNC_COMMENT = cfg["sync_comment"]
LOG_FILE     = cfg["log_file"]
NET_ZONE_MAP = cfg["network_zone_map"]
HERMES_IP    = cfg.get("hermes_ip", "")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)]
)
log = logging.getLogger(__name__)

def sanitize_label(label):
    label = label.lower().strip()
    label = re.sub(r"[^a-z0-9-]", "-", label)
    label = re.sub(r"-{2,}", "-", label)
    return label.strip("-")[:63]

def build_unifi_opener():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ctx),
        urllib.request.HTTPCookieProcessor(cj)
    )

def unifi_login(opener):
    payload = json.dumps({"username": UNIFI_USER, "password": UNIFI_PASS}).encode()
    req = urllib.request.Request(
        f"{UNIFI_URL}/api/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    resp = opener.open(req)
    body = json.loads(resp.read().decode())
    if "unique_id" not in body:
        raise RuntimeError(f"UniFi login failed")
    log.info(f"UniFi login OK")
    return resp.headers.get("x-csrf-token", "")

def unifi_get(opener, path):
    req = urllib.request.Request(f"{UNIFI_URL}/proxy/network/api/s/{UNIFI_SITE}/{path}")
    resp = opener.open(req)
    data = json.loads(resp.read().decode())
    return data.get("data", [])

def zeus_get(path_and_params):
    url = f"{ZEUS_URL}/{path_and_params}"
    resp = urllib.request.urlopen(url)
    data = json.loads(resp.read().decode())
    if data.get("status") != "ok":
        raise RuntimeError(f"Zeus failed: {data.get('errorMessage')}")
    return data

def zeus_upsert_a(fqdn, ip):
    params = urllib.parse.urlencode({
        "token": ZEUS_TOKEN, "domain": fqdn, "type": "A",
        "ipAddress": ip, "ttl": str(DNS_TTL), "overwrite": "true",
        "ptr": "true", "createPtrZone": "true", "comments": SYNC_COMMENT
    })
    zeus_get(f"api/zones/records/add?{params}")

def zeus_delete_a(fqdn, ip):
    params = urllib.parse.urlencode({
        "token": ZEUS_TOKEN, "domain": fqdn, "type": "A", "ipAddress": ip
    })
    zeus_get(f"api/zones/records/delete?{params}")

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {}

def save_state(records):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(records, f, indent=2)

def main():
    log.info("=== unifi-zeus-sync start ===")
    opener = build_unifi_opener()
    unifi_login(opener)
    clients = unifi_get(opener, "stat/sta")
    log.info(f"UniFi returned {len(clients)} active clients")

    expected = {}
    for client in clients:
        ip = client.get("ip", "").strip()
        if not ip:
            continue
        network_id = client.get("network_id", "")
        zone = NET_ZONE_MAP.get(network_id)
        if not zone:
            continue
        raw_label = client.get("name", "").strip() or client.get("hostname", "").strip()
        if not raw_label:
            continue
        label = sanitize_label(raw_label)
        if not label:
            continue
        fqdn = f"{label}.{zone}"
        if fqdn not in expected:
            expected[fqdn] = ip

    log.info(f"Expected DNS records: {len(expected)}")
    state = load_state()
    current = state.get("a_records", {})

    added = updated = unchanged = errors = 0
    for fqdn, ip in expected.items():
        try:
            if fqdn not in current:
                zeus_upsert_a(fqdn, ip)
                log.info(f"ADD {fqdn} → {ip}")
                added += 1
            elif current[fqdn] != ip:
                zeus_upsert_a(fqdn, ip)
                log.info(f"UPDATE {fqdn}: {current[fqdn]} → {ip}")
                updated += 1
            else:
                unchanged += 1
        except Exception as e:
            log.error(f"Failed {fqdn}: {e}")
            errors += 1

    removed = 0
    for fqdn, old_ip in current.items():
        if fqdn not in expected:
            try:
                zeus_delete_a(fqdn, old_ip)
                log.info(f"REMOVE {fqdn}")
                removed += 1
            except Exception as e:
                log.warning(f"Could not remove {fqdn}: {e}")

    log.info(f"=== Sync complete: added={added} updated={updated} unchanged={unchanged} removed={removed} errors={errors} ===")
    if errors == 0:
        save_state({"a_records": expected})

if __name__ == "__main__":
    main()
SYNCSCRIPT

  chmod 750 /usr/local/bin/unifi-zeus-sync.py
  msg_ok "Sync script deployed"
  
  msg_info "Setting up cron job (every 5 minutes)"
  (crontab -l 2>/dev/null | grep -v "unifi-zeus-sync"; echo "*/5 * * * * /usr/bin/python3 /usr/local/bin/unifi-zeus-sync.py >> /var/log/unifi-zeus-sync.log 2>&1") | crontab -
  msg_ok "Cron job configured"
  
  msg_info "Running initial sync"
  python3 /usr/local/bin/unifi-zeus-sync.py >> "$LOGFILE" 2>&1 || true
  msg_ok "Initial sync complete"
}

# ── Configure Firewall ────────────────────────────────────────────────────────
configure_firewall() {
  section "Configuring Firewall"
  
  if command -v ufw &>/dev/null; then
    msg_info "Configuring UFW firewall"
    ufw allow 53/tcp >> "$LOGFILE" 2>&1
    ufw allow 53/udp >> "$LOGFILE" 2>&1
    ufw allow 5380/tcp >> "$LOGFILE" 2>&1
    msg_ok "UFW rules added"
  else
    msg_ok "No firewall detected — skipping"
  fi
}

# ── Verification ──────────────────────────────────────────────────────────────
verify_installation() {
  section "Verification"
  
  if systemctl is-active --quiet dns 2>/dev/null; then
    msg_ok "DNS service is running"
  else
    msg_error "DNS service is not running"
  fi
  
  if curl -s --connect-timeout 3 "http://127.0.0.1:${TECHNITIUM_PORT}/api/user/login" &>/dev/null; then
    msg_ok "API is accessible"
  else
    msg_error "API is not accessible"
  fi
  
  local zone_count
  zone_count=$(curl -s "http://127.0.0.1:${TECHNITIUM_PORT}/api/zones/list?token=${API_TOKEN}" 2>/dev/null | jq -r '.response.zones | length' 2>/dev/null || echo "0")
  msg_ok "Total zones configured: ${zone_count}"
  
  if [[ -f /usr/local/bin/unifi-zeus-sync.py ]]; then
    msg_ok "UniFi sync script deployed"
  fi
  
  if crontab -l 2>/dev/null | grep -q "unifi-zeus-sync"; then
    msg_ok "Sync cron job active"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Technitium DNS Server${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf "  ${DGN}Web UI       :${CL}  ${BL}http://${DNS_IP}:5380${CL}\n"
  printf "  ${DGN}Admin user   :${CL}  ${BL}${DNS_USER}${CL}\n"
  printf "  ${DGN}Base domain  :${CL}  ${BL}${BASE_DOMAIN}${CL}\n"
  printf "  ${DGN}Zones        :${CL}  ${BL}${#ALL_ZONES[@]} zones${CL}\n"
  printf "  ${DGN}Resolution   :${CL}  ${BL}Root Hints (no external forwarders)${CL}\n"
  printf "  ${DGN}DNSSEC       :${CL}  ${BL}Enabled${CL}\n"
  printf "  ${DGN}Blocking     :${CL}  ${BL}Enabled (hagezi)${CL}\n"
  printf "  ${DGN}UniFi Sync   :${CL}  ${BL}Every 5 minutes${CL}\n"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  detect_os
  header_info
  preflight
  collect_config
  survey_unifi
  install_prerequisites
  install_technitium
  configure_dns
  create_zones
  deploy_sync_script
  configure_firewall
  verify_installation
  summary
}

main "$@"