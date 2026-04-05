#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Full Installation & Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    2.0.0
#  Date:       2026-04-05
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  Installs Technitium DNS Server from scratch on any Debian-based distro.
#  Configures split-horizon DNS with VLAN zones for UniFi network integration.
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
SCRIPT_VERSION="2.0.0"
LOGFILE="/var/log/technitium-dns-install-$(date +%Y%m%d-%H%M%S).log"
TECHNITIUM_PORT="5380"
TECHNITIUM_SERVICE="dns"
TECHNITIUM_USER="dns"
TECHNITIUM_DIR="/etc/dns"
TECHNITIUM_DATA="/var/lib/technitium"

# Configuration collected from user
DNS_IP=""
DNS_USER=""
DNS_PASS=""
PRIMARY_ZONE=""
VLAN_ZONES=()
BACKEND_ZONES=()
FORWARDERS="1.1.1.1,9.9.9.9"
ENABLE_RFC2136="y"
API_TOKEN=""

# Retry settings
MAX_RETRIES=3
RETRY_DELAY=5

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

# ── Retry wrapper ─────────────────────────────────────────────────────────────
retry() {
  local max_attempts=$1
  local delay=$2
  shift 2
  local attempt=1
  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi
    log "Attempt $attempt failed, retrying in ${delay}s..."
    sleep "$delay"
    (( attempt++ ))
  done
  return 1
}

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
  
  # Determine package manager
  if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt"
  elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
  elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
  else
    PKG_MANAGER="unknown"
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
  log "Package Manager: $PKG_MANAGER"
}

# ── Preflight Checks ──────────────────────────────────────────────────────────
preflight() {
  section "Preflight Checks"
  
  # Root check
  if [[ $EUID -ne 0 ]]; then
    msg_error "Must be run as root — aborting"
    echo -e "\n${YW}  Run with: sudo bash <(curl -fsSL URL)${CL}\n"
    exit 1
  fi
  msg_ok "Running as root"
  
  # OS compatibility
  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian|armbian)
      msg_ok "Compatible OS detected: ${OS_NAME}"
      ;;
    *)
      msg_warn "Untested OS: ${OS_NAME} — proceeding with caution"
      ;;
  esac
  
  # Package manager
  if [[ "$PKG_MANAGER" != "apt" ]]; then
    msg_error "Only apt-based distributions are supported"
    exit 1
  fi
  msg_ok "APT package manager available"
  
  # Internet connectivity
  msg_info "Checking internet connectivity"
  if ! retry 3 2 ping -c1 -W3 8.8.8.8 &>/dev/null; then
    if ! retry 3 2 ping -c1 -W3 1.1.1.1 &>/dev/null; then
      msg_error "No internet connectivity — cannot proceed"
      exit 1
    fi
  fi
  msg_ok "Internet connectivity confirmed"
  
  # Check for existing installation
  if systemctl is-active --quiet dns 2>/dev/null; then
    msg_warn "Technitium DNS service already running"
    read -rp "  ${YW}Continue and reconfigure? [y/N]:${CL} " continue_install
    [[ "${continue_install,,}" != "y" ]] && { echo ""; exit 0; }
  fi
  
  # Get current IP
  DNS_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z "$DNS_IP" ]]; then
    DNS_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
  fi
  msg_ok "Detected IP address: ${DNS_IP}"
}

# ── Collect Configuration ─────────────────────────────────────────────────────
collect_config() {
  section "Configuration"
  
  echo -e "  ${BL}${BLD}This script will install and configure Technitium DNS Server${CL}"
  echo -e "  ${BL}${BLD}for split-horizon DNS with UniFi network integration.${CL}"
  echo ""
  
  # Confirm/override IP
  read -rp "  ${BL}DNS Server IP address${CL} [${DNS_IP}]: " ip_input
  [[ -n "$ip_input" ]] && DNS_IP="$ip_input"
  
  # Admin credentials
  echo ""
  echo -e "  ${BL}${BLD}Admin Account:${CL}"
  read -rp "  ${BL}Admin username${CL} [admin]: " DNS_USER
  DNS_USER="${DNS_USER:-admin}"
  
  while true; do
    read -rsp "  ${BL}Admin password${CL}: " DNS_PASS; echo ""
    if [[ ${#DNS_PASS} -lt 8 ]]; then
      msg_warn "Password must be at least 8 characters"
      continue
    fi
    read -rsp "  ${BL}Confirm password${CL}: " pass_confirm; echo ""
    [[ "$DNS_PASS" == "$pass_confirm" ]] && break
    msg_warn "Passwords do not match — try again"
  done
  
  # Domain configuration
  echo ""
  echo -e "  ${BL}${BLD}Domain Configuration:${CL}"
  echo -e "  ${DGN}Example: For 'home.vanauken.tech', enter 'home.vanauken.tech'${CL}"
  read -rp "  ${BL}Primary domain (your internal zone)${CL}: " PRIMARY_ZONE
  [[ -z "$PRIMARY_ZONE" ]] && { msg_error "Primary domain is required"; exit 1; }
  
  # VLAN zones
  echo ""
  echo -e "  ${BL}${BLD}VLAN Sub-zones:${CL}"
  echo -e "  ${DGN}Enter VLAN names separated by commas (e.g., dmz,pro,storage,mgmt)${CL}"
  echo -e "  ${DGN}These become: dmz.${PRIMARY_ZONE}, pro.${PRIMARY_ZONE}, etc.${CL}"
  read -rp "  ${BL}VLAN names (comma-separated)${CL}: " vlan_input
  
  if [[ -n "$vlan_input" ]]; then
    IFS=',' read -ra raw_vlans <<< "$vlan_input"
    for vlan in "${raw_vlans[@]}"; do
      vlan="${vlan//[[:space:]]/}"  # trim whitespace
      vlan="${vlan,,}"               # lowercase
      [[ -n "$vlan" ]] && VLAN_ZONES+=("${vlan}.${PRIMARY_ZONE}")
    done
  fi
  
  # Create backend zones for each VLAN (for SSL proxy integration)
  echo ""
  echo -e "  ${BL}${BLD}Backend Zones (for SSL Proxy Integration):${CL}"
  read -rp "  ${BL}Create backend.* zones for SSL proxy?${CL} [Y/n]: " backend_input
  if [[ "${backend_input,,}" != "n" ]]; then
    BACKEND_ZONES+=("backend.${PRIMARY_ZONE}")
    for vlan_zone in "${VLAN_ZONES[@]}"; do
      # Extract vlan name from zone
      local vlan_name="${vlan_zone%%.*}"
      BACKEND_ZONES+=("backend.${vlan_zone}")
    done
  fi
  
  # Forwarders
  echo ""
  echo -e "  ${BL}${BLD}Upstream DNS Forwarders:${CL}"
  read -rp "  ${BL}Forwarders (comma-separated)${CL} [1.1.1.1,9.9.9.9]: " fw_input
  [[ -n "$fw_input" ]] && FORWARDERS="$fw_input"
  
  # RFC 2136
  read -rp "  ${BL}Enable RFC 2136 dynamic updates?${CL} [Y/n]: " rfc_input
  [[ "${rfc_input,,}" == "n" ]] && ENABLE_RFC2136="n"
  
  echo ""
  msg_ok "Configuration collected"
  
  # Summary
  echo ""
  echo -e "  ${BL}${BLD}Configuration Summary:${CL}"
  printf "  ${DGN}  Server IP     :${CL} %s\n" "$DNS_IP"
  printf "  ${DGN}  Admin user    :${CL} %s\n" "$DNS_USER"
  printf "  ${DGN}  Primary zone  :${CL} %s\n" "$PRIMARY_ZONE"
  printf "  ${DGN}  VLAN zones    :${CL} %s\n" "${VLAN_ZONES[*]:-none}"
  printf "  ${DGN}  Backend zones :${CL} %s\n" "${#BACKEND_ZONES[@]} zones"
  printf "  ${DGN}  Forwarders    :${CL} %s\n" "$FORWARDERS"
  printf "  ${DGN}  RFC 2136      :${CL} %s\n" "$ENABLE_RFC2136"
  echo ""
  
  read -rp "  ${YW}Proceed with installation? [Y/n]:${CL} " proceed
  [[ "${proceed,,}" == "n" ]] && { echo ""; exit 0; }
}

# ── Install Prerequisites ─────────────────────────────────────────────────────
install_prerequisites() {
  section "Installing Prerequisites"
  
  msg_info "Updating package lists"
  if ! DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1; then
    msg_warn "apt-get update had issues — continuing anyway"
  else
    msg_ok "Package lists updated"
  fi
  
  local prereqs=(curl wget gnupg2 ca-certificates apt-transport-https jq dnsutils lsb-release)
  
  for pkg in "${prereqs[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      msg_ok "${pkg} already installed"
    else
      msg_info "Installing ${pkg}"
      if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1; then
        msg_ok "${pkg} installed"
      else
        msg_warn "Failed to install ${pkg} — continuing"
      fi
    fi
  done
  
  # Install .NET runtime (required for Technitium)
  msg_info "Checking .NET runtime"
  if command -v dotnet &>/dev/null; then
    local dotnet_version
    dotnet_version=$(dotnet --version 2>/dev/null || echo "unknown")
    msg_ok ".NET runtime available (${dotnet_version})"
  else
    msg_info "Installing .NET runtime dependencies"
    DEBIAN_FRONTEND=noninteractive apt-get install -y libicu-dev >> "$LOGFILE" 2>&1
    msg_ok "Runtime dependencies installed"
  fi
}

# ── Install Technitium DNS Server ─────────────────────────────────────────────
install_technitium() {
  section "Installing Technitium DNS Server"
  
  msg_info "Downloading Technitium DNS installer"
  local installer_url="https://download.technitium.com/dns/DnsServerPortable.tar.gz"
  local install_dir="/opt/technitium"
  
  # Create directories
  mkdir -p "$install_dir" >> "$LOGFILE" 2>&1
  mkdir -p /var/lib/technitium >> "$LOGFILE" 2>&1
  
  # Download and extract
  if ! retry 3 5 curl -fsSL "$installer_url" -o /tmp/DnsServerPortable.tar.gz >> "$LOGFILE" 2>&1; then
    msg_error "Failed to download Technitium DNS Server"
    exit 1
  fi
  msg_ok "Downloaded Technitium DNS Server"
  
  msg_info "Extracting installation files"
  tar -xzf /tmp/DnsServerPortable.tar.gz -C "$install_dir" >> "$LOGFILE" 2>&1
  rm -f /tmp/DnsServerPortable.tar.gz
  msg_ok "Extracted to ${install_dir}"
  
  # Create systemd service
  msg_info "Creating systemd service"
  cat > /etc/systemd/system/dns.service << 'EOF'
[Unit]
Description=Technitium DNS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/technitium
ExecStart=/opt/technitium/start.sh
ExecStop=/bin/kill -SIGTERM $MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
  
  # Create start script if it doesn't exist
  if [[ ! -f "$install_dir/start.sh" ]]; then
    # Find the DnsServerApp directory
    local app_dir
    app_dir=$(find "$install_dir" -name "DnsServerApp.dll" -printf '%h\n' 2>/dev/null | head -1)
    
    if [[ -n "$app_dir" ]]; then
      cat > "$install_dir/start.sh" << EOF
#!/bin/bash
cd "${app_dir}"
exec dotnet DnsServerApp.dll
EOF
      chmod +x "$install_dir/start.sh"
    else
      # Use official start method
      cat > "$install_dir/start.sh" << 'EOF'
#!/bin/bash
cd /opt/technitium
if [[ -f "./DnsServerApp" ]]; then
  exec ./DnsServerApp
elif [[ -f "./bin/DnsServerApp" ]]; then
  exec ./bin/DnsServerApp
else
  # Find and run
  APP=$(find . -name "DnsServerApp" -type f -executable 2>/dev/null | head -1)
  [[ -n "$APP" ]] && exec "$APP"
  # Try .NET
  DLL=$(find . -name "DnsServerApp.dll" 2>/dev/null | head -1)
  [[ -n "$DLL" ]] && exec dotnet "$DLL"
fi
EOF
      chmod +x "$install_dir/start.sh"
    fi
  fi
  
  msg_ok "Systemd service created"
  
  # Enable and start
  msg_info "Starting Technitium DNS Server"
  systemctl daemon-reload >> "$LOGFILE" 2>&1
  systemctl enable dns >> "$LOGFILE" 2>&1
  systemctl start dns >> "$LOGFILE" 2>&1
  
  # Wait for service to start
  local attempts=0
  while (( attempts < 30 )); do
    if curl -s --connect-timeout 2 "http://127.0.0.1:${TECHNITIUM_PORT}/api/user/login" &>/dev/null; then
      msg_ok "Technitium DNS Server started successfully"
      return 0
    fi
    (( attempts++ ))
    sleep 2
  done
  
  msg_error "Technitium DNS Server failed to start"
  systemctl status dns >> "$LOGFILE" 2>&1
  exit 1
}

# ── Configure via API ─────────────────────────────────────────────────────────
configure_dns() {
  section "Configuring DNS Server"
  
  local api_base="http://127.0.0.1:${TECHNITIUM_PORT}/api"
  
  # Create admin account
  msg_info "Creating admin account: ${DNS_USER}"
  local response
  response=$(curl -s -X POST "${api_base}/user/createAccount" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    --data-urlencode "displayName=Administrator" \
    2>>"$LOGFILE")
  
  log "Create account response: $response"
  
  local status
  status=$(echo "$response" | jq -r '.status' 2>/dev/null)
  
  if [[ "$status" == "ok" ]]; then
    msg_ok "Admin account created: ${DNS_USER}"
  else
    msg_ok "Admin account setup complete"
  fi
  
  # Authenticate
  msg_info "Authenticating"
  response=$(curl -s -X POST "${api_base}/user/login" \
    --data-urlencode "user=${DNS_USER}" \
    --data-urlencode "pass=${DNS_PASS}" \
    --data-urlencode "includeInfo=true" \
    2>>"$LOGFILE")
  
  log "Login response: ${response:0:300}"
  
  status=$(echo "$response" | jq -r '.status' 2>/dev/null)
  
  if [[ "$status" != "ok" ]]; then
    msg_error "Authentication failed"
    exit 1
  fi
  
  API_TOKEN=$(echo "$response" | jq -r '.response.token' 2>/dev/null)
  
  if [[ -z "$API_TOKEN" || "$API_TOKEN" == "null" ]]; then
    msg_error "Failed to get API token"
    exit 1
  fi
  msg_ok "Authenticated — token acquired"
  
  # Configure server settings
  msg_info "Configuring server settings"
  response=$(curl -s -X POST "${api_base}/settings/set" \
    --data-urlencode "token=${API_TOKEN}" \
    --data-urlencode "recursion=AllowAll" \
    --data-urlencode "forwarders=${FORWARDERS}" \
    --data-urlencode "forwarderProtocol=Udp" \
    --data-urlencode "preferIPv6=false" \
    --data-urlencode "enableLogging=true" \
    2>>"$LOGFILE")
  
  log "Settings response: $response"
  msg_ok "Recursion enabled, forwarders set: ${FORWARDERS}"
}

# ── Create DNS Zones ──────────────────────────────────────────────────────────
create_zones() {
  section "Creating DNS Zones"
  
  local api_base="http://127.0.0.1:${TECHNITIUM_PORT}/api"
  local all_zones=("$PRIMARY_ZONE" "${VLAN_ZONES[@]}" "${BACKEND_ZONES[@]}")
  
  for zone in "${all_zones[@]}"; do
    [[ -z "$zone" ]] && continue
    
    msg_info "Creating zone: ${zone}"
    local response
    response=$(curl -s -X POST "${api_base}/zones/create" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "type=Primary" \
      2>>"$LOGFILE")
    
    log "Create zone [$zone]: $response"
    
    local status
    status=$(echo "$response" | jq -r '.status' 2>/dev/null)
    
    if [[ "$status" == "ok" ]]; then
      msg_ok "Zone created: ${zone}"
    else
      local err
      err=$(echo "$response" | jq -r '.errorMessage // "already exists or error"' 2>/dev/null)
      msg_warn "Zone [${zone}]: ${err}"
    fi
    
    # Enable RFC 2136 if requested
    if [[ "$ENABLE_RFC2136" == "y" ]]; then
      response=$(curl -s -X POST "${api_base}/zones/options/set" \
        --data-urlencode "token=${API_TOKEN}" \
        --data-urlencode "zone=${zone}" \
        --data-urlencode "allowDynamicUpdates=true" \
        2>>"$LOGFILE")
      log "RFC2136 [$zone]: $response"
    fi
  done
  
  if [[ "$ENABLE_RFC2136" == "y" ]]; then
    msg_ok "RFC 2136 dynamic updates enabled on all zones"
  fi
}

# ── Create Reverse DNS Zones ──────────────────────────────────────────────────
create_reverse_zones() {
  section "Creating Reverse DNS Zones"
  
  echo -e "  ${BL}${BLD}Enter the subnets you want reverse DNS for.${CL}"
  echo -e "  ${DGN}Example: 172.16.250,192.168.200,10.1.1${CL}"
  echo -e "  ${DGN}These become: 250.16.172.in-addr.arpa, etc.${CL}"
  read -rp "  ${BL}Subnets (comma-separated, or Enter to skip)${CL}: " subnet_input
  
  [[ -z "$subnet_input" ]] && { msg_ok "Skipping reverse zones"; return; }
  
  local api_base="http://127.0.0.1:${TECHNITIUM_PORT}/api"
  
  IFS=',' read -ra subnets <<< "$subnet_input"
  for subnet in "${subnets[@]}"; do
    subnet="${subnet//[[:space:]]/}"
    [[ -z "$subnet" ]] && continue
    
    # Convert to reverse zone format
    IFS='.' read -ra octets <<< "$subnet"
    local reverse_zone=""
    for (( i=${#octets[@]}-1; i>=0; i-- )); do
      reverse_zone+="${octets[i]}."
    done
    reverse_zone+="in-addr.arpa"
    
    msg_info "Creating reverse zone: ${reverse_zone}"
    local response
    response=$(curl -s -X POST "${api_base}/zones/create" \
      --data-urlencode "token=${API_TOKEN}" \
      --data-urlencode "zone=${reverse_zone}" \
      --data-urlencode "type=Primary" \
      2>>"$LOGFILE")
    
    log "Create reverse zone [$reverse_zone]: $response"
    
    local status
    status=$(echo "$response" | jq -r '.status' 2>/dev/null)
    
    if [[ "$status" == "ok" ]]; then
      msg_ok "Reverse zone created: ${reverse_zone}"
      
      # Enable RFC 2136
      if [[ "$ENABLE_RFC2136" == "y" ]]; then
        curl -s -X POST "${api_base}/zones/options/set" \
          --data-urlencode "token=${API_TOKEN}" \
          --data-urlencode "zone=${reverse_zone}" \
          --data-urlencode "allowDynamicUpdates=true" \
          >> "$LOGFILE" 2>&1
      fi
    else
      msg_warn "Reverse zone [${reverse_zone}]: already exists or error"
    fi
  done
}

# ── Configure Firewall ────────────────────────────────────────────────────────
configure_firewall() {
  section "Configuring Firewall"
  
  if command -v ufw &>/dev/null; then
    msg_info "Configuring UFW firewall"
    ufw allow 53/tcp >> "$LOGFILE" 2>&1
    ufw allow 53/udp >> "$LOGFILE" 2>&1
    ufw allow 5380/tcp >> "$LOGFILE" 2>&1
    msg_ok "UFW rules added for DNS (53) and Web UI (5380)"
  elif command -v firewall-cmd &>/dev/null; then
    msg_info "Configuring firewalld"
    firewall-cmd --permanent --add-service=dns >> "$LOGFILE" 2>&1
    firewall-cmd --permanent --add-port=5380/tcp >> "$LOGFILE" 2>&1
    firewall-cmd --reload >> "$LOGFILE" 2>&1
    msg_ok "Firewalld rules added"
  else
    msg_ok "No firewall detected — skipping"
  fi
}

# ── Verification ──────────────────────────────────────────────────────────────
verify_installation() {
  section "Verification"
  
  # Service status
  if systemctl is-active --quiet dns; then
    msg_ok "DNS service is running"
  else
    msg_error "DNS service is not running"
  fi
  
  # API accessibility
  if curl -s --connect-timeout 3 "http://127.0.0.1:${TECHNITIUM_PORT}/api/user/login" &>/dev/null; then
    msg_ok "API is accessible on port ${TECHNITIUM_PORT}"
  else
    msg_error "API is not accessible"
  fi
  
  # DNS resolution test
  if command -v dig &>/dev/null; then
    msg_info "Testing DNS resolution"
    if dig @127.0.0.1 google.com +short +time=3 >> "$LOGFILE" 2>&1; then
      msg_ok "DNS resolution working (forwarding)"
    else
      msg_warn "DNS forwarding test failed — check forwarders"
    fi
  fi
  
  # Zone verification
  local zone_count
  zone_count=$(curl -s "http://127.0.0.1:${TECHNITIUM_PORT}/api/zones/list?token=${API_TOKEN}" 2>/dev/null | jq -r '.response.zones | length' 2>/dev/null || echo "0")
  msg_ok "Total zones configured: ${zone_count}"
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  local rfc_status
  rfc_status=$([ "$ENABLE_RFC2136" == "y" ] && echo "Enabled" || echo "Disabled")
  
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Technitium DNS Server${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  echo -e "  ${GN}${BLD}Technitium DNS Server installed and configured successfully.${CL}"
  echo ""
  printf "  ${DGN}Web UI       :${CL}  ${BL}http://${DNS_IP}:5380${CL}\n"
  printf "  ${DGN}Admin user   :${CL}  ${BL}${DNS_USER}${CL}\n"
  printf "  ${DGN}Primary zone :${CL}  ${BL}${PRIMARY_ZONE}${CL}\n"
  if [[ ${#VLAN_ZONES[@]} -gt 0 ]]; then
    printf "  ${DGN}VLAN zones   :${CL}  ${BL}%d zones${CL}\n" "${#VLAN_ZONES[@]}"
  fi
  if [[ ${#BACKEND_ZONES[@]} -gt 0 ]]; then
    printf "  ${DGN}Backend zones:${CL}  ${BL}%d zones${CL}\n" "${#BACKEND_ZONES[@]}"
  fi
  printf "  ${DGN}Forwarders   :${CL}  ${BL}${FORWARDERS}${CL}\n"
  printf "  ${DGN}RFC 2136     :${CL}  ${BL}${rfc_status}${CL}\n"
  echo ""
  echo -e "  ${YW}Next steps:${CL}"
  printf "  ${DGN}[▸]${CL}  Open http://${DNS_IP}:5380 and verify configuration\n"
  printf "  ${DGN}[▸]${CL}  Point DHCP clients to ${DNS_IP} as their DNS server\n"
  printf "  ${DGN}[▸]${CL}  Add A/CNAME/PTR records for your servers\n"
  echo ""
  echo -e "  ${YW}One-liner to run this script:${CL}"
  echo -e "  ${DGN}bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)${CL}"
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
  detect_os
  header_info
  preflight
  collect_config
  install_prerequisites
  install_technitium
  configure_dns
  create_zones
  create_reverse_zones
  configure_firewall
  verify_installation
  summary
}

main "$@"