#!/usr/bin/env bash
# ============================================================================
#  Nginx Proxy Manager — Full Installation & Dynamic SSL Proxy Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    2.0.0
#  Date:       2026-04-05
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  Installs Nginx Proxy Manager from scratch on any Debian-based distro.
#  Configures dynamic SSL proxy with wildcard Let's Encrypt certificates
#  for UniFi network integration using SRV record-based backend resolution.
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
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
LOGFILE="/var/log/npm-install-$(date +%Y%m%d-%H%M%S).log"
NPM_PORT="81"
NPM_HTTP_PORT="80"
NPM_HTTPS_PORT="443"
NPM_DATA_DIR="/data/nginx"
NPM_SSL_DIR="/etc/ssl"
DOCKER_COMPOSE_FILE="/opt/npm/docker-compose.yml"

# Configuration collected from user
NPM_IP=""
ADMIN_EMAIL=""
ADMIN_PASS=""
WILDCARD_DOMAIN=""
DNS_SERVER_IP=""
DNS_PROVIDER=""
CF_API_TOKEN=""
INSTALL_METHOD=""  # docker or native
SETUP_DYNAMIC_PROXY="y"

# API
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
  
  if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt"
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
  echo -e "${DGN}  ── Nginx Proxy Manager — Full Installation & SSL Proxy ─────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}OS     :${CL}  ${BL}%s %s (%s)${CL}\n" "$OS_NAME" "$OS_VERSION" "$OS_CODENAME"
  printf "  ${DGN}Script :${CL}  ${BL}v%s${CL}\n" "$SCRIPT_VERSION"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "NPM Full Install Log - $(date)" > "$LOGFILE"
  log "OS: $OS_NAME $OS_VERSION ($OS_CODENAME) - ID: $OS_ID"
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
    ubuntu|debian|linuxmint|pop|elementary|zorin|raspbian|armbian)
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
  
  # Get current IP
  NPM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z "$NPM_IP" ]]; then
    NPM_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
  fi
  msg_ok "Detected IP address: ${NPM_IP}"
  
  # Check for existing installation
  if docker ps 2>/dev/null | grep -q "nginx-proxy-manager"; then
    msg_warn "Nginx Proxy Manager container already running"
    read -rp "  ${YW}Continue and reconfigure? [y/N]:${CL} " continue_install
    [[ "${continue_install,,}" != "y" ]] && { echo ""; exit 0; }
    INSTALL_METHOD="docker"
  fi
}

# ── Collect Configuration ─────────────────────────────────────────────────────
collect_config() {
  section "Configuration"
  
  echo -e "  ${BL}${BLD}This script will install Nginx Proxy Manager and configure${CL}"
  echo -e "  ${BL}${BLD}a dynamic SSL proxy with wildcard Let's Encrypt certificates.${CL}"
  echo ""
  
  # Confirm/override IP
  read -rp "  ${BL}NPM Server IP address${CL} [${NPM_IP}]: " ip_input
  [[ -n "$ip_input" ]] && NPM_IP="$ip_input"
  
  # Installation method
  echo ""
  echo -e "  ${BL}${BLD}Installation Method:${CL}"
  echo -e "  ${DGN}  1) Docker (recommended)${CL}"
  echo -e "  ${DGN}  2) Native (bare-metal)${CL}"
  read -rp "  ${BL}Select [1]:${CL} " method_input
  case "${method_input:-1}" in
    2) INSTALL_METHOD="native" ;;
    *) INSTALL_METHOD="docker" ;;
  esac
  
  # Admin credentials
  echo ""
  echo -e "  ${BL}${BLD}Admin Account:${CL}"
  read -rp "  ${BL}Admin email address${CL}: " ADMIN_EMAIL
  [[ -z "$ADMIN_EMAIL" ]] && { msg_error "Admin email is required"; exit 1; }
  
  while true; do
    read -rsp "  ${BL}Admin password${CL}: " ADMIN_PASS; echo ""
    if [[ ${#ADMIN_PASS} -lt 8 ]]; then
      msg_warn "Password must be at least 8 characters"
      continue
    fi
    read -rsp "  ${BL}Confirm password${CL}: " pass_confirm; echo ""
    [[ "$ADMIN_PASS" == "$pass_confirm" ]] && break
    msg_warn "Passwords do not match — try again"
  done
  
  # Wildcard domain
  echo ""
  echo -e "  ${BL}${BLD}Wildcard Certificate Domain:${CL}"
  echo -e "  ${DGN}Example: For '*.home.vanauken.tech', enter 'home.vanauken.tech'${CL}"
  read -rp "  ${BL}Domain (without wildcard)${CL}: " WILDCARD_DOMAIN
  [[ -z "$WILDCARD_DOMAIN" ]] && { msg_error "Domain is required for wildcard certificate"; exit 1; }
  
  # DNS provider for Let's Encrypt
  echo ""
  echo -e "  ${BL}${BLD}DNS Provider for Let's Encrypt DNS Challenge:${CL}"
  echo -e "  ${DGN}  1) Cloudflare (recommended)${CL}"
  echo -e "  ${DGN}  2) Route53 (AWS)${CL}"
  echo -e "  ${DGN}  3) DigitalOcean${CL}"
  echo -e "  ${DGN}  4) Manual (skip auto-certificate)${CL}"
  read -rp "  ${BL}Select [1]:${CL} " dns_input
  
  case "${dns_input:-1}" in
    1) 
      DNS_PROVIDER="cloudflare"
      echo ""
      echo -e "  ${BL}${BLD}Cloudflare API Token:${CL}"
      echo -e "  ${DGN}Create at: https://dash.cloudflare.com/profile/api-tokens${CL}"
      echo -e "  ${DGN}Required permissions: Zone:DNS:Edit${CL}"
      read -rsp "  ${BL}API Token${CL}: " CF_API_TOKEN; echo ""
      [[ -z "$CF_API_TOKEN" ]] && { msg_warn "No API token — certificate must be added manually"; DNS_PROVIDER="manual"; }
      ;;
    2) DNS_PROVIDER="route53" ;;
    3) DNS_PROVIDER="digitalocean" ;;
    *) DNS_PROVIDER="manual" ;;
  esac
  
  # DNS server for backend resolution
  echo ""
  echo -e "  ${BL}${BLD}Internal DNS Server (for SRV record resolution):${CL}"
  echo -e "  ${DGN}This is your Technitium DNS server IP${CL}"
  read -rp "  ${BL}DNS Server IP${CL}: " DNS_SERVER_IP
  [[ -z "$DNS_SERVER_IP" ]] && { msg_error "DNS server IP is required for dynamic proxy"; exit 1; }
  
  # Dynamic proxy setup
  read -rp "  ${BL}Configure dynamic SSL proxy (SRV-based)?${CL} [Y/n]: " proxy_input
  [[ "${proxy_input,,}" == "n" ]] && SETUP_DYNAMIC_PROXY="n"
  
  echo ""
  msg_ok "Configuration collected"
  
  # Summary
  echo ""
  echo -e "  ${BL}${BLD}Configuration Summary:${CL}"
  printf "  ${DGN}  Server IP      :${CL} %s\n" "$NPM_IP"
  printf "  ${DGN}  Install method :${CL} %s\n" "$INSTALL_METHOD"
  printf "  ${DGN}  Admin email    :${CL} %s\n" "$ADMIN_EMAIL"
  printf "  ${DGN}  Wildcard domain:${CL} *.%s\n" "$WILDCARD_DOMAIN"
  printf "  ${DGN}  DNS provider   :${CL} %s\n" "$DNS_PROVIDER"
  printf "  ${DGN}  Internal DNS   :${CL} %s\n" "$DNS_SERVER_IP"
  printf "  ${DGN}  Dynamic proxy  :${CL} %s\n" "$SETUP_DYNAMIC_PROXY"
  echo ""
  
  read -rp "  ${YW}Proceed with installation? [Y/n]:${CL} " proceed
  [[ "${proceed,,}" == "n" ]] && { echo ""; exit 0; }
}

# ── Install Prerequisites ─────────────────────────────────────────────────────
install_prerequisites() {
  section "Installing Prerequisites"
  
  msg_info "Updating package lists"
  DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
  msg_ok "Package lists updated"
  
  local prereqs=(curl wget gnupg2 ca-certificates apt-transport-https jq openssl)
  
  for pkg in "${prereqs[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      msg_ok "${pkg} already installed"
    else
      msg_info "Installing ${pkg}"
      if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1; then
        msg_ok "${pkg} installed"
      else
        msg_warn "Failed to install ${pkg}"
      fi
    fi
  done
}

# ── Install Docker ────────────────────────────────────────────────────────────
install_docker() {
  section "Installing Docker"
  
  if command -v docker &>/dev/null; then
    local docker_version
    docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    msg_ok "Docker already installed (${docker_version})"
  else
    msg_info "Installing Docker"
    
    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg -o /etc/apt/keyrings/docker.asc >> "$LOGFILE" 2>&1
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
    
    DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOGFILE" 2>&1
    
    if command -v docker &>/dev/null; then
      msg_ok "Docker installed successfully"
    else
      msg_error "Docker installation failed"
      exit 1
    fi
  fi
  
  # Ensure Docker is running
  systemctl enable docker >> "$LOGFILE" 2>&1
  systemctl start docker >> "$LOGFILE" 2>&1
  msg_ok "Docker service running"
}

# ── Install NPM via Docker ────────────────────────────────────────────────────
install_npm_docker() {
  section "Installing Nginx Proxy Manager (Docker)"
  
  # Create directories
  mkdir -p /opt/npm
  mkdir -p /data/nginx/custom
  mkdir -p /data/letsencrypt
  mkdir -p "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}"
  
  msg_info "Creating Docker Compose configuration"
  cat > "$DOCKER_COMPOSE_FILE" << 'EOF'
version: '3.8'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    volumes:
      - /data/nginx:/data
      - /data/letsencrypt:/etc/letsencrypt
      - /etc/ssl:/etc/ssl:ro
    environment:
      - DISABLE_IPV6=true
    healthcheck:
      test: ["CMD", "/bin/check-health"]
      interval: 10s
      timeout: 3s
EOF
  msg_ok "Docker Compose file created"
  
  msg_info "Starting Nginx Proxy Manager container"
  cd /opt/npm
  docker compose up -d >> "$LOGFILE" 2>&1
  
  # Wait for NPM to start
  local attempts=0
  while (( attempts < 60 )); do
    if curl -s --connect-timeout 2 "http://127.0.0.1:${NPM_PORT}/api" &>/dev/null; then
      msg_ok "Nginx Proxy Manager started successfully"
      return 0
    fi
    (( attempts++ ))
    sleep 2
  done
  
  msg_error "Nginx Proxy Manager failed to start"
  docker logs nginx-proxy-manager >> "$LOGFILE" 2>&1
  exit 1
}

# ── Install NPM Native ────────────────────────────────────────────────────────
install_npm_native() {
  section "Installing Nginx Proxy Manager (Native)"
  
  msg_info "This method uses the official NPM installer script"
  
  # Download and run official installer
  if ! curl -fsSL https://raw.githubusercontent.com/NginxProxyManager/nginx-proxy-manager/master/scripts/install >> "$LOGFILE" 2>&1; then
    msg_error "Failed to download NPM installer"
    exit 1
  fi
  
  # Note: Native install is complex - recommend Docker
  msg_warn "Native installation is complex — Docker method is recommended"
  msg_ok "Please follow manual installation steps for native install"
}

# ── Configure NPM via API ─────────────────────────────────────────────────────
configure_npm() {
  section "Configuring Nginx Proxy Manager"
  
  local api_base="http://127.0.0.1:${NPM_PORT}/api"
  
  # Default credentials for fresh NPM install
  local default_email="admin@example.com"
  local default_pass="changeme"
  
  # Wait a bit more for API to be fully ready
  sleep 5
  
  # Try to login with default credentials first
  msg_info "Checking for fresh installation"
  local response
  response=$(curl -s -X POST "${api_base}/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${default_email}\",\"secret\":\"${default_pass}\"}" \
    2>>"$LOGFILE")
  
  local token
  token=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)
  
  if [[ -n "$token" ]]; then
    msg_ok "Fresh installation detected — updating admin account"
    
    # Get user ID
    local user_id
    user_id=$(curl -s -X GET "${api_base}/users" \
      -H "Authorization: Bearer ${token}" \
      2>>"$LOGFILE" | jq -r '.[0].id // 1' 2>/dev/null)
    
    # Update admin user
    curl -s -X PUT "${api_base}/users/${user_id}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${ADMIN_EMAIL}\",\"nickname\":\"Admin\",\"is_disabled\":false}" \
      >> "$LOGFILE" 2>&1
    
    # Change password
    curl -s -X PUT "${api_base}/users/${user_id}/auth" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"password\",\"current\":\"${default_pass}\",\"secret\":\"${ADMIN_PASS}\"}" \
      >> "$LOGFILE" 2>&1
    
    msg_ok "Admin account updated: ${ADMIN_EMAIL}"
  else
    msg_ok "Existing installation — using provided credentials"
  fi
  
  # Login with new/existing credentials
  msg_info "Authenticating as ${ADMIN_EMAIL}"
  response=$(curl -s -X POST "${api_base}/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${ADMIN_EMAIL}\",\"secret\":\"${ADMIN_PASS}\"}" \
    2>>"$LOGFILE")
  
  API_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)
  
  if [[ -z "$API_TOKEN" ]]; then
    msg_error "Authentication failed"
    log "Auth response: $response"
    exit 1
  fi
  msg_ok "Authenticated — token acquired"
}

# ── Request Wildcard Certificate ──────────────────────────────────────────────
request_certificate() {
  [[ "$DNS_PROVIDER" == "manual" ]] && { 
    msg_warn "Skipping certificate request — manual mode"
    return 
  }
  
  section "Requesting Wildcard SSL Certificate"
  
  local api_base="http://127.0.0.1:${NPM_PORT}/api"
  
  msg_info "Requesting Let's Encrypt certificate for *.${WILDCARD_DOMAIN}"
  
  local dns_challenge_config=""
  case "$DNS_PROVIDER" in
    cloudflare)
      dns_challenge_config="{\"dns_challenge\":true,\"dns_provider\":\"cloudflare\",\"dns_provider_credentials\":\"dns_cloudflare_api_token = ${CF_API_TOKEN}\"}"
      ;;
    *)
      msg_warn "DNS provider ${DNS_PROVIDER} requires manual configuration"
      return
      ;;
  esac
  
  local response
  response=$(curl -s -X POST "${api_base}/nginx/certificates" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"domain_names\": [\"*.${WILDCARD_DOMAIN}\", \"${WILDCARD_DOMAIN}\"],
      \"meta\": {
        \"letsencrypt_email\": \"${ADMIN_EMAIL}\",
        \"letsencrypt_agree\": true,
        \"dns_challenge\": true,
        \"dns_provider\": \"cloudflare\",
        \"dns_provider_credentials\": \"dns_cloudflare_api_token = ${CF_API_TOKEN}\"
      }
    }" \
    2>>"$LOGFILE")
  
  log "Certificate request response: $response"
  
  local cert_id
  cert_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)
  
  if [[ -n "$cert_id" ]]; then
    msg_ok "Certificate requested (ID: ${cert_id})"
    msg_info "Waiting for certificate issuance (this may take 1-2 minutes)"
    
    # Wait for certificate to be issued
    local attempts=0
    while (( attempts < 60 )); do
      local cert_status
      cert_status=$(curl -s -X GET "${api_base}/nginx/certificates/${cert_id}" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        2>>"$LOGFILE" | jq -r '.meta.letsencrypt_status // empty' 2>/dev/null)
      
      if [[ "$cert_status" == "valid" ]]; then
        msg_ok "Wildcard certificate issued successfully"
        
        # Copy certificate to standard location
        copy_certificate "$cert_id"
        return 0
      fi
      (( attempts++ ))
      sleep 3
    done
    
    msg_warn "Certificate status unknown — check NPM web UI"
  else
    local error
    error=$(echo "$response" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
    msg_warn "Certificate request: ${error}"
  fi
}

# ── Copy Certificate to Standard Location ─────────────────────────────────────
copy_certificate() {
  local cert_id="$1"
  local cert_dir="${NPM_SSL_DIR}/${WILDCARD_DOMAIN}"
  
  mkdir -p "$cert_dir"
  
  # NPM stores certs in /data/letsencrypt/live/npm-X/
  local npm_cert_dir="/data/letsencrypt/live/npm-${cert_id}"
  
  if [[ -d "$npm_cert_dir" ]]; then
    cp "$npm_cert_dir/fullchain.pem" "$cert_dir/fullchain.pem" 2>/dev/null
    cp "$npm_cert_dir/privkey.pem" "$cert_dir/privkey.pem" 2>/dev/null
    msg_ok "Certificate copied to ${cert_dir}"
  else
    # Try alternative locations
    local alt_dir=$(find /data/letsencrypt/live -name "*.${WILDCARD_DOMAIN}*" -type d 2>/dev/null | head -1)
    if [[ -n "$alt_dir" ]]; then
      cp "$alt_dir/fullchain.pem" "$cert_dir/fullchain.pem" 2>/dev/null
      cp "$alt_dir/privkey.pem" "$cert_dir/privkey.pem" 2>/dev/null
      msg_ok "Certificate copied to ${cert_dir}"
    else
      msg_warn "Certificate files not found — may need manual copy"
    fi
  fi
}

# ── Configure Dynamic SSL Proxy ───────────────────────────────────────────────
configure_dynamic_proxy() {
  [[ "$SETUP_DYNAMIC_PROXY" != "y" ]] && return
  
  section "Configuring Dynamic SSL Proxy"
  
  local custom_dir="/data/nginx/custom"
  mkdir -p "$custom_dir"
  
  # Create Lua SRV resolver script
  msg_info "Creating SRV resolver script"
  cat > "${custom_dir}/srv_resolver.lua" << 'LUAEOF'
-- SRV Record Resolver for Dynamic SSL Proxy
-- Van Auken Tech — Thomas Van Auken
-- Queries DNS for backend target and port based on hostname

local host = ngx.var.host
if not host then
    ngx.log(ngx.ERR, "No host header")
    return ngx.exit(502)
end

-- Extract components: server.vlan.domain.tld
local pattern = "^([^%.]+)%.([^%.]+)%.(.+)$"
local server, vlan, base_domain = host:match(pattern)

if not server or not vlan then
    -- Try simpler pattern: server.domain.tld
    pattern = "^([^%.]+)%.(.+)$"
    server, base_domain = host:match(pattern)
    vlan = nil
end

if not server then
    ngx.log(ngx.ERR, "Invalid hostname format: ", host)
    return ngx.exit(502)
end

-- Build SRV record name
local srv_name
if vlan then
    srv_name = "_https._tcp." .. server .. "." .. vlan .. "." .. base_domain
else
    srv_name = "_https._tcp." .. server .. "." .. base_domain
end

-- Query SRV record
local resolver = require "resty.dns.resolver"

local r, err = resolver:new{
    nameservers = {ngx.var.dns_resolver},
    retrans = 3,
    timeout = 2000,
}

if not r then
    ngx.log(ngx.ERR, "Failed to create resolver: ", err)
    return ngx.exit(502)
end

local answers, err = r:query(srv_name, {qtype = r.TYPE_SRV})

if not answers or #answers == 0 or answers.errcode then
    ngx.log(ngx.ERR, "SRV lookup failed for: ", srv_name, " - ", err or (answers and answers.errstr) or "no records")
    return ngx.exit(502)
end

-- Use first SRV answer
local srv = answers[1]
if not srv or not srv.target or not srv.port then
    ngx.log(ngx.ERR, "Invalid SRV response for: ", srv_name)
    return ngx.exit(502)
end

ngx.var.backend_host = srv.target
ngx.var.backend_port = srv.port

-- Determine protocol based on port (common HTTP ports)
local http_ports = {["80"]=true, ["81"]=true, ["3000"]=true, ["5380"]=true, ["8080"]=true, ["8081"]=true, ["9000"]=true}
if http_ports[tostring(srv.port)] then
    ngx.var.backend_proto = "http"
else
    ngx.var.backend_proto = "https"
end

ngx.log(ngx.INFO, "Proxying ", host, " to: ", ngx.var.backend_proto, "://", ngx.var.backend_host, ":", ngx.var.backend_port)
LUAEOF
  msg_ok "SRV resolver script created"
  
  # Create nginx custom configuration
  msg_info "Creating dynamic proxy configuration"
  cat > "${custom_dir}/http.conf" << EOF
# Dynamic SSL Proxy for *.${WILDCARD_DOMAIN}
# Van Auken Tech — Thomas Van Auken
# Resolves backend via SRV records at runtime

lua_package_path "/data/nginx/custom/?.lua;;";

server {
    listen 443 ssl http2 default_server;
    server_name *.${WILDCARD_DOMAIN};
    
    ssl_certificate ${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    # DNS resolver for SRV lookups
    set \$dns_resolver "${DNS_SERVER_IP}";
    
    location / {
        set \$backend_host "";
        set \$backend_port "";
        set \$backend_proto "https";
        
        access_by_lua_file /data/nginx/custom/srv_resolver.lua;
        
        resolver ${DNS_SERVER_IP} valid=30s ipv6=off;
        
        proxy_pass \$backend_proto://\$backend_host:\$backend_port;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_verify off;
        proxy_ssl_server_name on;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
        proxy_buffering off;
        
        # WebSocket support
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Health check endpoint
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF
  msg_ok "Dynamic proxy configuration created"
  
  # Restart NPM to apply configuration
  msg_info "Restarting Nginx Proxy Manager to apply configuration"
  if [[ "$INSTALL_METHOD" == "docker" ]]; then
    docker restart nginx-proxy-manager >> "$LOGFILE" 2>&1
  else
    systemctl restart nginx >> "$LOGFILE" 2>&1
  fi
  
  sleep 5
  msg_ok "Configuration applied"
}

# ── Configure Firewall ────────────────────────────────────────────────────────
configure_firewall() {
  section "Configuring Firewall"
  
  if command -v ufw &>/dev/null; then
    msg_info "Configuring UFW firewall"
    ufw allow 80/tcp >> "$LOGFILE" 2>&1
    ufw allow 443/tcp >> "$LOGFILE" 2>&1
    ufw allow 81/tcp >> "$LOGFILE" 2>&1
    msg_ok "UFW rules added for HTTP (80), HTTPS (443), and Web UI (81)"
  elif command -v firewall-cmd &>/dev/null; then
    msg_info "Configuring firewalld"
    firewall-cmd --permanent --add-service=http >> "$LOGFILE" 2>&1
    firewall-cmd --permanent --add-service=https >> "$LOGFILE" 2>&1
    firewall-cmd --permanent --add-port=81/tcp >> "$LOGFILE" 2>&1
    firewall-cmd --reload >> "$LOGFILE" 2>&1
    msg_ok "Firewalld rules added"
  else
    msg_ok "No firewall detected — skipping"
  fi
}

# ── Verification ──────────────────────────────────────────────────────────────
verify_installation() {
  section "Verification"
  
  # Container/service status
  if [[ "$INSTALL_METHOD" == "docker" ]]; then
    if docker ps | grep -q nginx-proxy-manager; then
      msg_ok "NPM container is running"
    else
      msg_error "NPM container is not running"
    fi
  fi
  
  # Web UI accessibility
  if curl -s --connect-timeout 3 "http://127.0.0.1:${NPM_PORT}/" &>/dev/null; then
    msg_ok "Web UI is accessible on port ${NPM_PORT}"
  else
    msg_error "Web UI is not accessible"
  fi
  
  # HTTPS port
  if curl -sk --connect-timeout 3 "https://127.0.0.1:${NPM_HTTPS_PORT}/" &>/dev/null; then
    msg_ok "HTTPS is responding on port ${NPM_HTTPS_PORT}"
  else
    msg_warn "HTTPS not yet responding — certificate may still be processing"
  fi
  
  # Check custom config
  if [[ -f "/data/nginx/custom/http.conf" ]]; then
    msg_ok "Dynamic proxy configuration present"
  fi
  
  # Check certificate
  if [[ -f "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem" ]]; then
    msg_ok "Wildcard certificate installed"
  else
    msg_warn "Wildcard certificate not found — may need manual setup"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  local cert_status
  if [[ -f "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem" ]]; then
    cert_status="Installed"
  else
    cert_status="Pending — add via Web UI"
  fi
  
  local proxy_status
  proxy_status=$([ "$SETUP_DYNAMIC_PROXY" == "y" ] && echo "Configured" || echo "Skipped")
  
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Nginx Proxy Manager${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  echo -e "  ${GN}${BLD}Nginx Proxy Manager installed and configured successfully.${CL}"
  echo ""
  printf "  ${DGN}Web UI        :${CL}  ${BL}http://${NPM_IP}:81${CL}\n"
  printf "  ${DGN}Admin         :${CL}  ${BL}${ADMIN_EMAIL}${CL}\n"
  printf "  ${DGN}Wildcard Cert :${CL}  ${BL}*.${WILDCARD_DOMAIN} — ${cert_status}${CL}\n"
  printf "  ${DGN}Dynamic Proxy :${CL}  ${BL}${proxy_status}${CL}\n"
  printf "  ${DGN}DNS Resolver  :${CL}  ${BL}${DNS_SERVER_IP}${CL}\n"
  echo ""
  echo -e "  ${YW}How Dynamic SSL Proxy Works:${CL}"
  echo -e "  ${DGN}  1. Browser requests https://server.vlan.${WILDCARD_DOMAIN}${CL}"
  echo -e "  ${DGN}  2. DNS returns this server's IP (${NPM_IP})${CL}"
  echo -e "  ${DGN}  3. Wildcard certificate validates the connection${CL}"
  echo -e "  ${DGN}  4. Lua script queries SRV record for backend target/port${CL}"
  echo -e "  ${DGN}  5. Request proxied to real server with valid SSL${CL}"
  echo ""
  echo -e "  ${YW}Required DNS Records (per server):${CL}"
  echo -e "  ${DGN}  A Record   : server.vlan.${WILDCARD_DOMAIN} → ${NPM_IP}${CL}"
  echo -e "  ${DGN}  Backend A  : server.backend.vlan.${WILDCARD_DOMAIN} → Real IP${CL}"
  echo -e "  ${DGN}  SRV Record : _https._tcp.server.vlan.${WILDCARD_DOMAIN} → 0 0 PORT backend${CL}"
  echo ""
  echo -e "  ${YW}One-liner to run this script:${CL}"
  echo -e "  ${DGN}bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)${CL}"
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
  
  if [[ "$INSTALL_METHOD" == "docker" ]]; then
    install_docker
    install_npm_docker
  else
    install_npm_native
  fi
  
  configure_npm
  request_certificate
  configure_dynamic_proxy
  configure_firewall
  verify_installation
  summary
}

main "$@"