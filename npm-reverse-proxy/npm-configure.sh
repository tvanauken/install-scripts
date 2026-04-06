#!/usr/bin/env bash
# ============================================================================
#  Nginx Proxy Manager — Post-Install Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  PRE-REQUISITES:
#    - Fresh LXC with NPM installed via Proxmox community-scripts
#    - Cloudflare account with API token (Zone:DNS:Edit permission)
#    - Root access
#
#  WHAT THIS SCRIPT DOES:
#    - Updates NPM admin credentials
#    - Requests wildcard Let's Encrypt certificate via Cloudflare DNS
#    - Imports certificate to NPM as custom SSL
#    - Provides instructions for adding proxy hosts
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-configure.sh)
# ============================================================================

set -o pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RD="\033[01;31m"; YW="\033[33m"; GN="\033[1;92m"; BL="\033[36m"; CL="\033[m"; BLD="\033[1m"

# ── Helpers ───────────────────────────────────────────────────────────────────
msg_info()  { printf "  ${YW}◆ %s...${CL}\r" "$1"; }
msg_ok()    { printf "  ${GN}✔ %-50s${CL}\n" "$1"; }
msg_error() { printf "  ${RD}✘ %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}── %s ──${CL}\n\n" "$1"; }

# ── Globals ───────────────────────────────────────────────────────────────────
NPM_PORT="81"
NPM_IP=""
ADMIN_EMAIL=""
ADMIN_PASS=""
WILDCARD_DOMAIN=""
CF_API_TOKEN=""
API_TOKEN=""

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo -e "${BL}${BLD}"
cat << 'BANNER'
  Nginx Proxy Manager — Post-Install Configuration
  ─────────────────────────────────────────────────
BANNER
echo -e "${CL}"
printf "  Host: ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
printf "  Date: ${BL}%s${CL}\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# ── Pre-flight ────────────────────────────────────────────────────────────────
section "Pre-flight Checks"

if [[ $EUID -ne 0 ]]; then
  msg_error "Must run as root"
  exit 1
fi
msg_ok "Running as root"

NPM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

if ! curl -s --connect-timeout 3 "http://127.0.0.1:${NPM_PORT}/api" &>/dev/null; then
  msg_error "NPM not running on port ${NPM_PORT}"
  echo "  Install via: bash -c \"\$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/nginxproxymanager.sh)\""
  exit 1
fi
msg_ok "NPM is running"

for cmd in curl jq certbot; do
  if ! command -v $cmd &>/dev/null; then
    msg_info "Installing $cmd"
    apt-get update -qq && apt-get install -y $cmd &>/dev/null
  fi
  msg_ok "$cmd available"
done

# Check for Cloudflare certbot plugin
if ! python3 -c "import certbot_dns_cloudflare" 2>/dev/null; then
  msg_info "Installing certbot-dns-cloudflare"
  apt-get install -y python3-certbot-dns-cloudflare &>/dev/null || pip3 install certbot-dns-cloudflare &>/dev/null
  msg_ok "certbot-dns-cloudflare installed"
fi

# ── Collect Configuration ─────────────────────────────────────────────────────
section "Configuration"

echo "  ${BLD}NPM Admin Account:${CL}"
echo "  (Will update the default admin@example.com account)"
echo ""
read -rp "  Admin email: " ADMIN_EMAIL
[[ -z "$ADMIN_EMAIL" ]] && { msg_error "Admin email required"; exit 1; }

while true; do
  read -rsp "  Admin password (min 8 chars): " ADMIN_PASS; echo ""
  [[ ${#ADMIN_PASS} -ge 8 ]] && break
  msg_error "Password must be at least 8 characters"
done

echo ""
echo "  ${BLD}Wildcard Certificate:${CL}"
echo "  Example: For '*.home.example.com', enter 'home.example.com'"
read -rp "  Domain (without *): " WILDCARD_DOMAIN
[[ -z "$WILDCARD_DOMAIN" ]] && { msg_error "Domain required"; exit 1; }

echo ""
echo "  ${BLD}Cloudflare API Token:${CL}"
echo "  Create at: https://dash.cloudflare.com/profile/api-tokens"
echo "  Required permissions: Zone:DNS:Edit"
read -rsp "  API Token: " CF_API_TOKEN; echo ""
[[ -z "$CF_API_TOKEN" ]] && { msg_error "API token required for DNS challenge"; exit 1; }

echo ""
echo "  ${BLD}Summary:${CL}"
printf "    Server IP    : %s\n" "$NPM_IP"
printf "    Admin email  : %s\n" "$ADMIN_EMAIL"
printf "    Wildcard cert: *.%s\n" "$WILDCARD_DOMAIN"
echo ""

read -rp "  Continue? [Y/n]: " proceed
[[ "${proceed,,}" == "n" ]] && exit 0

# ── Update NPM Admin ──────────────────────────────────────────────────────────
section "Updating NPM Admin Account"

api_base="http://127.0.0.1:${NPM_PORT}/api"
default_email="admin@example.com"
default_pass="changeme"

msg_info "Authenticating with default credentials"
response=$(curl -s -X POST "${api_base}/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${default_email}\",\"secret\":\"${default_pass}\"}" 2>/dev/null)

API_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)

if [[ -n "$API_TOKEN" ]]; then
  msg_ok "Fresh installation detected"
  
  msg_info "Updating admin account"
  user_id=$(curl -s "${api_base}/users" \
    -H "Authorization: Bearer ${API_TOKEN}" 2>/dev/null | jq -r '.[0].id // 1')
  
  curl -s -X PUT "${api_base}/users/${user_id}" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"nickname\":\"Admin\",\"is_disabled\":false}" &>/dev/null
  
  curl -s -X PUT "${api_base}/users/${user_id}/auth" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"password\",\"current\":\"${default_pass}\",\"secret\":\"${ADMIN_PASS}\"}" &>/dev/null
  
  msg_ok "Admin account updated: ${ADMIN_EMAIL}"
else
  msg_info "Credentials already changed, authenticating"
fi

# Re-authenticate with new credentials
response=$(curl -s -X POST "${api_base}/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${ADMIN_EMAIL}\",\"secret\":\"${ADMIN_PASS}\"}" 2>/dev/null)

API_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)

if [[ -z "$API_TOKEN" ]]; then
  msg_error "Authentication failed with provided credentials"
  exit 1
fi
msg_ok "Authenticated as ${ADMIN_EMAIL}"

# ── Request Wildcard Certificate ──────────────────────────────────────────────
section "Requesting Wildcard Certificate"

cert_dir="/etc/ssl/${WILDCARD_DOMAIN}"
mkdir -p "$cert_dir"
mkdir -p /etc/letsencrypt

msg_info "Creating Cloudflare credentials"
cat > /etc/letsencrypt/cloudflare.ini << EOF
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF
chmod 600 /etc/letsencrypt/cloudflare.ini
msg_ok "Cloudflare credentials saved"

msg_info "Requesting certificate (this may take 30-60 seconds)"
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d "*.${WILDCARD_DOMAIN}" \
  -d "${WILDCARD_DOMAIN}" \
  --email "${ADMIN_EMAIL}" \
  --agree-tos \
  --non-interactive \
  --quiet 2>/dev/null

if [[ $? -eq 0 ]]; then
  msg_ok "Certificate issued successfully"
  
  msg_info "Copying certificate to ${cert_dir}"
  cp "/etc/letsencrypt/live/${WILDCARD_DOMAIN}/fullchain.pem" "${cert_dir}/fullchain.pem"
  cp "/etc/letsencrypt/live/${WILDCARD_DOMAIN}/privkey.pem" "${cert_dir}/key.pem"
  msg_ok "Certificate copied"
else
  msg_error "Certificate request failed"
  echo "  Check /var/log/letsencrypt/letsencrypt.log for details"
  exit 1
fi

# ── Import Certificate to NPM ─────────────────────────────────────────────────
section "Importing Certificate to NPM"

msg_info "Importing certificate"

cert_content=$(cat "${cert_dir}/fullchain.pem" | jq -Rs .)
key_content=$(cat "${cert_dir}/key.pem" | jq -Rs .)

response=$(curl -s -X POST "${api_base}/nginx/certificates" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"nice_name\":\"Wildcard ${WILDCARD_DOMAIN}\",\"provider\":\"other\",\"certificate\":${cert_content},\"certificate_key\":${key_content}}" 2>/dev/null)

cert_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)

if [[ -n "$cert_id" ]]; then
  msg_ok "Certificate imported (ID: ${cert_id})"
else
  msg_error "Import failed — add manually via Web UI"
  echo "  Go to: SSL Certificates → Add SSL Certificate → Custom"
  echo "  Certificate: ${cert_dir}/fullchain.pem"
  echo "  Key: ${cert_dir}/key.pem"
fi

# ── Configure Auto-Renewal ────────────────────────────────────────────────────
section "Configuring Auto-Renewal"

msg_info "Setting up certbot renewal"
cat > /etc/cron.d/certbot-renew << EOF
0 0,12 * * * root certbot renew --quiet --post-hook "systemctl reload openresty 2>/dev/null || true"
EOF
msg_ok "Auto-renewal configured (twice daily)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BL}${BLD}════════════════════════════════════════════════════════${CL}"
echo -e "${BL}${BLD}       CONFIGURATION COMPLETE${CL}"
echo -e "${BL}${BLD}════════════════════════════════════════════════════════${CL}"
echo ""
printf "  Web UI      : ${BL}http://%s:81${CL}\n" "$NPM_IP"
printf "  Admin       : ${BL}%s${CL}\n" "$ADMIN_EMAIL"
printf "  Certificate : ${BL}*.%s${CL}\n" "$WILDCARD_DOMAIN"
echo ""
echo -e "  ${YW}To add a proxy host:${CL}"
echo "    1. Open NPM Web UI → Hosts → Proxy Hosts → Add"
echo "    2. Domain Names: anyname.${WILDCARD_DOMAIN}"
echo "    3. Forward Hostname/IP: backend server IP"
echo "    4. Forward Port: backend service port"
echo "    5. SSL tab: Select 'Wildcard ${WILDCARD_DOMAIN}'"
echo "    6. Enable Force SSL, HTTP/2"
echo "    7. Save"
echo ""
echo -e "  ${YW}DNS Setup:${CL}"
echo "    Create public A record for each service:"
echo "    anyname.${WILDCARD_DOMAIN} → ${NPM_IP} (or your public IP)"
echo ""
echo -e "${GN}Created by: Thomas Van Auken — Van Auken Tech${CL}"
echo ""
