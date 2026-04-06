#!/usr/bin/env bash
# ============================================================================
#  Nginx Proxy Manager — Full Installation & Dynamic SSL Proxy Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    3.0.0
#  Date:       2026-04-05
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  Installs Nginx Proxy Manager natively (no Docker) on any Debian-based distro.
#  Configures dynamic SSL proxy with wildcard Let's Encrypt certificates
#  using SRV record-based backend resolution via Lua.
#
#  Template: Hermes production server
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
# ============================================================================

set -o pipefail

RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="    "

SCRIPT_VERSION="3.0.0"
LOGFILE="/var/log/npm-install-$(date +%Y%m%d-%H%M%S).log"
NPM_PORT="81"
NPM_DATA_DIR="/data/nginx"
NPM_SSL_DIR="/etc/ssl"

NPM_IP=""
ADMIN_EMAIL=""
ADMIN_PASS=""
WILDCARD_DOMAIN=""
DNS_SERVER_IP=""
CF_API_TOKEN=""
API_TOKEN=""

cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  if [[ $code -ne 0 ]]; then
    echo -e "\n${RD}  Script interrupted or failed (exit ${code})${CL}"
    echo -e "${YW}  Check the log file for details: ${LOGFILE}${CL}\n"
  fi
}
trap cleanup EXIT

log()       { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"; }
msg_info()  { printf "${TAB}${YW}◆  %s...${CL}\r" "$1"; log "INFO: $1"; }
msg_ok()    { printf "${TAB}${GN}✔  %-55s${CL}\n" "$1"; log "OK: $1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; log "ERROR: $1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; log "WARN: $1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; log "SECTION: $1"; }

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
  
  NPM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  msg_ok "Detected IP address: ${NPM_IP}"
}

collect_config() {
  section "Configuration"
  
  echo -e "  ${BL}${BLD}This script installs Nginx Proxy Manager natively and configures${CL}"
  echo -e "  ${BL}${BLD}a dynamic SSL proxy with wildcard Let's Encrypt certificates.${CL}"
  echo ""
  
  read -rp "  ${BL}NPM Server IP address${CL} [${NPM_IP}]: " ip_input
  [[ -n "$ip_input" ]] && NPM_IP="$ip_input"
  
  echo ""
  echo -e "  ${BL}${BLD}Admin Account:${CL}"
  read -rp "  ${BL}Admin email address${CL}: " ADMIN_EMAIL
  [[ -z "$ADMIN_EMAIL" ]] && { msg_error "Admin email is required"; exit 1; }
  
  while true; do
    read -rsp "  ${BL}Admin password${CL}: " ADMIN_PASS; echo ""
    [[ ${#ADMIN_PASS} -ge 8 ]] && break
    msg_warn "Password must be at least 8 characters"
  done
  
  echo ""
  echo -e "  ${BL}${BLD}Wildcard Certificate Domain:${CL}"
  echo -e "  ${DGN}Example: For '*.home.example.com', enter 'home.example.com'${CL}"
  read -rp "  ${BL}Domain (without wildcard)${CL}: " WILDCARD_DOMAIN
  [[ -z "$WILDCARD_DOMAIN" ]] && { msg_error "Domain is required"; exit 1; }
  
  echo ""
  echo -e "  ${BL}${BLD}Internal DNS Server (for SRV record resolution):${CL}"
  read -rp "  ${BL}DNS Server IP${CL}: " DNS_SERVER_IP
  [[ -z "$DNS_SERVER_IP" ]] && { msg_error "DNS server IP is required"; exit 1; }
  
  echo ""
  echo -e "  ${BL}${BLD}Cloudflare API Token (for Let's Encrypt DNS challenge):${CL}"
  echo -e "  ${DGN}Create at: https://dash.cloudflare.com/profile/api-tokens${CL}"
  read -rsp "  ${BL}API Token (or Enter to skip auto-cert)${CL}: " CF_API_TOKEN; echo ""
  
  msg_ok "Configuration collected"
  
  echo ""
  echo -e "  ${BL}${BLD}Configuration Summary:${CL}"
  printf "  ${DGN}  Server IP      :${CL} %s\n" "$NPM_IP"
  printf "  ${DGN}  Admin email    :${CL} %s\n" "$ADMIN_EMAIL"
  printf "  ${DGN}  Wildcard domain:${CL} *.%s\n" "$WILDCARD_DOMAIN"
  printf "  ${DGN}  DNS Server     :${CL} %s\n" "$DNS_SERVER_IP"
  printf "  ${DGN}  Auto SSL       :${CL} %s\n" "$([[ -n "$CF_API_TOKEN" ]] && echo "Yes" || echo "Manual")"
  echo ""
  
  read -rp "  ${YW}Proceed with installation? [Y/n]:${CL} " proceed
  [[ "${proceed,,}" == "n" ]] && exit 0
}

install_prerequisites() {
  section "Installing Prerequisites"
  
  msg_info "Updating package lists"
  DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
  msg_ok "Package lists updated"
  
  local prereqs=(curl wget gnupg2 ca-certificates jq openssl certbot python3-certbot-dns-cloudflare build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libgd-dev libgeoip-dev libperl-dev)
  
  for pkg in "${prereqs[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      msg_ok "${pkg} already installed"
    else
      msg_info "Installing ${pkg}"
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1 || true
      msg_ok "${pkg} installed"
    fi
  done
}

install_openresty() {
  section "Installing OpenResty"
  
  msg_info "Adding OpenResty repository"
  wget -qO - https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg 2>> "$LOGFILE"
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/${OS_ID} ${OS_CODENAME} main" > /etc/apt/sources.list.d/openresty.list
  
  DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOGFILE" 2>&1
  msg_ok "Repository added"
  
  msg_info "Installing OpenResty"
  DEBIAN_FRONTEND=noninteractive apt-get install -y openresty >> "$LOGFILE" 2>&1
  msg_ok "OpenResty installed"
  
  systemctl enable openresty >> "$LOGFILE" 2>&1
  systemctl start openresty >> "$LOGFILE" 2>&1
  msg_ok "OpenResty service started"
}

install_npm() {
  section "Installing Nginx Proxy Manager"
  
  msg_info "Installing Node.js"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$LOGFILE" 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs >> "$LOGFILE" 2>&1
  msg_ok "Node.js installed"
  
  msg_info "Downloading NPM"
  local npm_version="2.11.3"
  mkdir -p /opt/npm
  curl -fsSL "https://github.com/NginxProxyManager/nginx-proxy-manager/archive/refs/tags/v${npm_version}.tar.gz" -o /tmp/npm.tar.gz >> "$LOGFILE" 2>&1
  tar -xzf /tmp/npm.tar.gz -C /opt/npm --strip-components=1 >> "$LOGFILE" 2>&1
  rm -f /tmp/npm.tar.gz
  msg_ok "NPM downloaded"
  
  msg_info "Building NPM (this takes several minutes)"
  cd /opt/npm/frontend
  npm install >> "$LOGFILE" 2>&1
  npm run build >> "$LOGFILE" 2>&1
  
  cd /opt/npm/backend
  npm install >> "$LOGFILE" 2>&1
  msg_ok "NPM built"
  
  mkdir -p /data/nginx/custom
  mkdir -p /data/logs
  mkdir -p /data/letsencrypt
  mkdir -p "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}"
  
  msg_info "Creating systemd service"
  cat > /etc/systemd/system/npm.service << 'EOF'
[Unit]
Description=Nginx Proxy Manager
After=network.target openresty.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/npm/backend
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload >> "$LOGFILE" 2>&1
  systemctl enable npm >> "$LOGFILE" 2>&1
  systemctl start npm >> "$LOGFILE" 2>&1
  msg_ok "NPM service created and started"
  
  msg_info "Waiting for NPM to start"
  local attempts=0
  while (( attempts < 60 )); do
    if curl -s --connect-timeout 2 "http://127.0.0.1:${NPM_PORT}/api" &>/dev/null; then
      msg_ok "NPM is running"
      return 0
    fi
    ((attempts++))
    sleep 2
  done
  
  msg_error "NPM failed to start"
  exit 1
}

configure_npm() {
  section "Configuring Nginx Proxy Manager"
  
  local api_base="http://127.0.0.1:${NPM_PORT}/api"
  local default_email="admin@example.com"
  local default_pass="changeme"
  
  sleep 5
  
  msg_info "Checking for fresh installation"
  local response
  response=$(curl -s -X POST "${api_base}/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${default_email}\",\"secret\":\"${default_pass}\"}" 2>>"$LOGFILE")
  
  local token
  token=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)
  
  if [[ -n "$token" ]]; then
    msg_ok "Fresh installation detected — updating admin account"
    
    local user_id
    user_id=$(curl -s -X GET "${api_base}/users" \
      -H "Authorization: Bearer ${token}" 2>>"$LOGFILE" | jq -r '.[0].id // 1' 2>/dev/null)
    
    curl -s -X PUT "${api_base}/users/${user_id}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${ADMIN_EMAIL}\",\"nickname\":\"Admin\",\"is_disabled\":false}" \
      >> "$LOGFILE" 2>&1
    
    curl -s -X PUT "${api_base}/users/${user_id}/auth" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"password\",\"current\":\"${default_pass}\",\"secret\":\"${ADMIN_PASS}\"}" \
      >> "$LOGFILE" 2>&1
    
    msg_ok "Admin account updated: ${ADMIN_EMAIL}"
  fi
  
  msg_info "Authenticating as ${ADMIN_EMAIL}"
  response=$(curl -s -X POST "${api_base}/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${ADMIN_EMAIL}\",\"secret\":\"${ADMIN_PASS}\"}" 2>>"$LOGFILE")
  
  API_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)
  
  if [[ -z "$API_TOKEN" ]]; then
    msg_error "Authentication failed"
    exit 1
  fi
  msg_ok "Authenticated"
}

request_certificate() {
  [[ -z "$CF_API_TOKEN" ]] && { msg_warn "Skipping auto-certificate — manual setup required"; return; }
  
  section "Requesting Wildcard SSL Certificate"
  
  local cert_dir="${NPM_SSL_DIR}/${WILDCARD_DOMAIN}"
  mkdir -p "$cert_dir"
  mkdir -p /etc/letsencrypt
  
  msg_info "Creating Cloudflare credentials"
  cat > /etc/letsencrypt/cloudflare.ini << EOF
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF
  chmod 600 /etc/letsencrypt/cloudflare.ini
  
  msg_info "Requesting certificate via certbot"
  certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    -d "*.${WILDCARD_DOMAIN}" \
    -d "${WILDCARD_DOMAIN}" \
    --email "${ADMIN_EMAIL}" \
    --agree-tos \
    --non-interactive \
    >> "$LOGFILE" 2>&1
  
  if [[ $? -eq 0 ]]; then
    msg_ok "Certificate issued successfully"
    
    cp "/etc/letsencrypt/live/${WILDCARD_DOMAIN}/fullchain.pem" "$cert_dir/fullchain.pem"
    cp "/etc/letsencrypt/live/${WILDCARD_DOMAIN}/privkey.pem" "$cert_dir/key.pem"
    msg_ok "Certificate copied to ${cert_dir}"
    
    cat > /etc/cron.d/certbot-renew << EOF
0 0,12 * * * root certbot renew --quiet --post-hook "systemctl reload openresty"
EOF
    msg_ok "Auto-renewal configured"
  else
    msg_error "Certificate request failed — check log"
  fi
}

configure_dynamic_proxy() {
  section "Configuring Dynamic SSL Proxy"
  
  local custom_dir="/data/nginx/custom"
  mkdir -p "$custom_dir"
  mkdir -p /data/logs
  
  msg_info "Creating SRV resolver module"
  cat > "${custom_dir}/srv_resolver.lua" << LUAEOF
local resolver = require "resty.dns.resolver"

local _M = {}

local DNS_SERVER = "${DNS_SERVER_IP}"
local DNS_PORT = 53

function _M.resolve_backend(host)
    local r, err = resolver:new{
        nameservers = {{DNS_SERVER, DNS_PORT}},
        retrans = 3,
        timeout = 2000,
    }
    
    if not r then
        ngx.log(ngx.ERR, "failed to create resolver: ", err)
        return nil, nil, "resolver creation failed"
    end
    
    local srv_name = "_https._tcp." .. host
    local answers, err = r:query(srv_name, {qtype = r.TYPE_SRV})
    
    if not answers then
        return nil, nil, "SRV query failed"
    end
    
    if answers.errcode then
        return nil, nil, answers.errstr
    end
    
    local best_srv = nil
    for i, ans in ipairs(answers) do
        if ans.type == r.TYPE_SRV then
            if not best_srv or ans.priority < best_srv.priority then
                best_srv = ans
            end
        end
    end
    
    if not best_srv then
        return nil, nil, "no SRV record"
    end
    
    local target = best_srv.target
    local port = best_srv.port
    
    local ip_answers, err = r:query(target, {qtype = r.TYPE_A})
    
    if not ip_answers or ip_answers.errcode then
        return nil, nil, "target resolution failed"
    end
    
    local ip = nil
    for i, ans in ipairs(ip_answers) do
        if ans.type == r.TYPE_A then
            ip = ans.address
            break
        end
    end
    
    if not ip then
        return nil, nil, "no A record for target"
    end
    
    ngx.log(ngx.INFO, "Resolved ", host, " -> ", ip, ":", port)
    return ip, port, nil
end

return _M
LUAEOF
  msg_ok "SRV resolver module created"
  
  msg_info "Creating dynamic proxy configuration"
  local escaped_domain="${WILDCARD_DOMAIN//./\\.}"
  cat > "${custom_dir}/http.conf" << EOF
lua_package_path "/data/nginx/custom/?.lua;;";

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    
    server_name ~^(?<subdomain>.+)\.${escaped_domain}\$;
    
    ssl_certificate ${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:DYNSSL:10m;
    ssl_session_timeout 1d;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    access_log /data/logs/dynamic_proxy_access.log;
    error_log /data/logs/dynamic_proxy_error.log;
    
    resolver ${DNS_SERVER_IP} valid=30s ipv6=off;
    resolver_timeout 5s;
    
    set \$backend_upstream "";
    
    location / {
        access_by_lua_block {
            local srv = require "srv_resolver"
            local host = ngx.var.host
            
            local ip, port, err = srv.resolve_backend(host)
            
            if not ip then
                ngx.log(ngx.ERR, "Backend resolution failed for ", host, ": ", err)
                ngx.exit(502)
                return
            end
            
            local protocol = "https"
            local http_ports = {80, 5380, 8080, 3000, 9000, 81}
            for _, p in ipairs(http_ports) do
                if port == p then
                    protocol = "http"
                    break
                end
            end
            
            ngx.var.backend_upstream = protocol .. "://" .. ip .. ":" .. port
        }
        
        proxy_pass \$backend_upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }
}
EOF
  msg_ok "Dynamic proxy configuration created"
  
  msg_info "Verifying nginx configuration"
  if /usr/local/openresty/nginx/sbin/nginx -t >> "$LOGFILE" 2>&1; then
    msg_ok "Nginx configuration valid"
    systemctl restart openresty >> "$LOGFILE" 2>&1
    msg_ok "OpenResty restarted"
  else
    msg_error "Nginx configuration invalid — check ${custom_dir}/http.conf"
  fi
}

configure_firewall() {
  section "Configuring Firewall"
  
  if command -v ufw &>/dev/null; then
    msg_info "Configuring UFW firewall"
    ufw allow 80/tcp >> "$LOGFILE" 2>&1
    ufw allow 443/tcp >> "$LOGFILE" 2>&1
    ufw allow 81/tcp >> "$LOGFILE" 2>&1
    msg_ok "UFW rules added"
  else
    msg_ok "No firewall detected — skipping"
  fi
}

verify_installation() {
  section "Verification"
  
  if systemctl is-active --quiet openresty 2>/dev/null; then
    msg_ok "OpenResty service is running"
  else
    msg_error "OpenResty service is not running"
  fi
  
  if systemctl is-active --quiet npm 2>/dev/null; then
    msg_ok "NPM service is running"
  else
    msg_error "NPM service is not running"
  fi
  
  if curl -s --connect-timeout 3 "http://127.0.0.1:${NPM_PORT}/" &>/dev/null; then
    msg_ok "Web UI is accessible on port ${NPM_PORT}"
  else
    msg_error "Web UI is not accessible"
  fi
  
  if [[ -f "/data/nginx/custom/http.conf" ]]; then
    msg_ok "Dynamic proxy configuration present"
  fi
  
  if [[ -f "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem" ]]; then
    msg_ok "Wildcard certificate installed"
  else
    msg_warn "Wildcard certificate not found — manual setup required"
  fi
}

summary() {
  local cert_status
  if [[ -f "${NPM_SSL_DIR}/${WILDCARD_DOMAIN}/fullchain.pem" ]]; then
    cert_status="Installed"
  else
    cert_status="Pending — add via Web UI or certbot"
  fi
  
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INSTALLATION COMPLETE — Nginx Proxy Manager${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf "  ${DGN}Web UI        :${CL}  ${BL}http://${NPM_IP}:81${CL}\n"
  printf "  ${DGN}Admin         :${CL}  ${BL}${ADMIN_EMAIL}${CL}\n"
  printf "  ${DGN}Wildcard Cert :${CL}  ${BL}*.${WILDCARD_DOMAIN} — ${cert_status}${CL}\n"
  printf "  ${DGN}Dynamic Proxy :${CL}  ${BL}Configured${CL}\n"
  printf "  ${DGN}DNS Resolver  :${CL}  ${BL}${DNS_SERVER_IP}${CL}\n"
  echo ""
  echo -e "  ${YW}How Dynamic SSL Proxy Works:${CL}"
  echo -e "  ${DGN}  1. Browser requests https://server.vlan.${WILDCARD_DOMAIN}${CL}"
  echo -e "  ${DGN}  2. DNS returns this server's IP (${NPM_IP})${CL}"
  echo -e "  ${DGN}  3. Wildcard certificate validates the connection${CL}"
  echo -e "  ${DGN}  4. Lua queries SRV record for backend target/port${CL}"
  echo -e "  ${DGN}  5. Request proxied to real server with valid SSL${CL}"
  echo ""
  echo -e "  ${YW}Required DNS Records (per server):${CL}"
  echo -e "  ${DGN}  A Record   : server.vlan.${WILDCARD_DOMAIN} → ${NPM_IP}${CL}"
  echo -e "  ${DGN}  Backend A  : server.backend.vlan.${WILDCARD_DOMAIN} → Real IP${CL}"
  echo -e "  ${DGN}  SRV Record : _https._tcp.server.vlan.${WILDCARD_DOMAIN} → 0 0 PORT backend${CL}"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

main() {
  detect_os
  header_info
  preflight
  collect_config
  install_prerequisites
  install_openresty
  install_npm
  configure_npm
  request_certificate
  configure_dynamic_proxy
  configure_firewall
  verify_installation
  summary
}

main "$@"