#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Post-Install Configuration
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#  PRE-REQUISITES:
#    - Fresh LXC with Technitium DNS installed via Proxmox community-scripts
#    - UniFi controller accessible on the network
#    - Root access
#
#  WHAT THIS SCRIPT DOES:
#    - Surveys UniFi controller to discover networks
#    - Configures Technitium for privacy-first DNS (root hints, no forwarders)
#    - Creates DNS zones for each discovered network
#    - Deploys sync script for automatic A/PTR records from UniFi clients
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-configure.sh)
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
  ─────────────────────────────────────────────
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

if ! curl -s --connect-timeout 3 "http://127.0.0.1:${TECHNITIUM_PORT}/api" &>/dev/null; then
  msg_error "Technitium DNS not running on port ${TECHNITIUM_PORT}"
  echo "  Install via: bash -c \"\$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/technitium.sh)\""
  exit 1
fi
msg_ok "Technitium DNS is running"

for cmd in curl jq; do
  if ! command -v $cmd &>/dev/null; then
    msg_info "Installing $cmd"
    apt-get update -qq && apt-get install -y $cmd &>/dev/null
  fi
  msg_ok "$cmd available"
done

# ── Get Technitium Token ──────────────────────────────────────────────────────
section "Technitium Authentication"

echo "  Enter your Technitium admin credentials."
echo "  (These were set during initial setup)"
echo ""
read -rp "  Username [admin]: " tech_user
tech_user="${tech_user:-admin}"
read -rsp "  Password: " tech_pass; echo ""

msg_info "Authenticating"
response=$(curl -s -X POST "http://127.0.0.1:${TECHNITIUM_PORT}/api/user/login" \
  --data-urlencode "user=${tech_user}" \
  --data-urlencode "pass=${tech_pass}" 2>/dev/null)

ZEUS_TOKEN=$(echo "$response" | jq -r '.token // empty' 2>/dev/null)

if [[ -z "$ZEUS_TOKEN" ]]; then
  msg_error "Authentication failed"
  exit 1
fi
msg_ok "Authenticated (token obtained)"

# ── Collect Configuration ─────────────────────────────────────────────────────
section "Configuration"

echo "  ${BLD}Domain Configuration:${CL}"
read -rp "  Base domain (e.g., home.example.com): " BASE_DOMAIN
[[ -z "$BASE_DOMAIN" ]] && { msg_error "Base domain required"; exit 1; }

read -rp "  DNS server hostname (e.g., dns.dmz.${BASE_DOMAIN}): " DNS_HOSTNAME
[[ -z "$DNS_HOSTNAME" ]] && DNS_HOSTNAME="dns.dmz.${BASE_DOMAIN}"

echo ""
echo "  ${BLD}UniFi Controller:${CL}"
read -rp "  UniFi URL (e.g., https://192.168.1.1): " UNIFI_URL
[[ -z "$UNIFI_URL" ]] && { msg_error "UniFi URL required"; exit 1; }

read -rp "  UniFi username: " UNIFI_USER
[[ -z "$UNIFI_USER" ]] && { msg_error "UniFi username required"; exit 1; }

read -rsp "  UniFi password: " UNIFI_PASS; echo ""
[[ -z "$UNIFI_PASS" ]] && { msg_error "UniFi password required"; exit 1; }

read -rp "  UniFi site [default]: " site_input
[[ -n "$site_input" ]] && UNIFI_SITE="$site_input"

echo ""
echo "  ${BLD}Reverse Proxy Integration (optional):${CL}"
read -rp "  NPM/Hermes IP (or Enter to skip): " HERMES_IP
if [[ -n "$HERMES_IP" ]]; then
  read -rp "  NPM admin email: " NPM_USER
  read -rsp "  NPM admin password: " NPM_PASS; echo ""
fi

# ── Survey UniFi ──────────────────────────────────────────────────────────────
section "Surveying UniFi Network"

msg_info "Connecting to UniFi"
cookie_jar="/tmp/unifi_cookies_$$"

login_response=$(curl -sk -c "$cookie_jar" -b "$cookie_jar" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${UNIFI_USER}\",\"password\":\"${UNIFI_PASS}\"}" \
  "${UNIFI_URL}/api/auth/login" 2>/dev/null)

if ! echo "$login_response" | grep -q "unique_id"; then
  msg_error "UniFi authentication failed"
  rm -f "$cookie_jar"
  exit 1
fi
msg_ok "Connected to UniFi"

msg_info "Discovering networks"
networks=$(curl -sk -b "$cookie_jar" \
  "${UNIFI_URL}/proxy/network/api/s/${UNIFI_SITE}/rest/networkconf" 2>/dev/null)

network_count=0
while IFS= read -r line; do
  net_id=$(echo "$line" | jq -r '._id // empty')
  net_name=$(echo "$line" | jq -r '.name // empty')
  purpose=$(echo "$line" | jq -r '.purpose // empty')
  
  [[ -z "$net_id" || -z "$net_name" ]] && continue
  [[ "$purpose" == "wan" ]] && continue
  
  # Sanitize for DNS
  zone_name=$(echo "$net_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
  zone_fqdn="${zone_name}.${BASE_DOMAIN}"
  
  NETWORK_ZONE_MAP["$net_id"]="$zone_fqdn"
  ALL_ZONES+=("$zone_fqdn")
  ((network_count++))
done < <(echo "$networks" | jq -c '.data[]' 2>/dev/null)

rm -f "$cookie_jar"
msg_ok "Discovered ${network_count} networks"

# Add base domain
ALL_ZONES+=("$BASE_DOMAIN")

echo ""
echo "  Zones to create:"
for zone in "${ALL_ZONES[@]}"; do
  printf "    • %s\n" "$zone"
done
echo ""

read -rp "  Continue? [Y/n]: " proceed
[[ "${proceed,,}" == "n" ]] && exit 0

# ── Configure Technitium Settings ─────────────────────────────────────────────
section "Configuring DNS Settings"

api_call() {
  curl -s "http://127.0.0.1:${TECHNITIUM_PORT}/api/$1?token=${ZEUS_TOKEN}&$2" 2>/dev/null
}

msg_info "Setting DNS server domain"
api_call "settings/set" "dnsServerDomain=${DNS_HOSTNAME}" >/dev/null
msg_ok "Server domain: ${DNS_HOSTNAME}"

msg_info "Configuring recursion (root hints only)"
api_call "settings/set" "recursion=AllowOnlyForPrivateNetworks&forwarders=" >/dev/null
msg_ok "Root hints recursion enabled (no forwarders)"

msg_info "Enabling DNSSEC validation"
api_call "settings/set" "dnssecValidation=true" >/dev/null
msg_ok "DNSSEC validation enabled"

msg_info "Enabling QNAME minimization"
api_call "settings/set" "qnameMinimization=true" >/dev/null
msg_ok "QNAME minimization enabled"

msg_info "Configuring cache settings"
api_call "settings/set" "serveStale=true&cachePrefetchTrigger=9&cacheMaximumEntries=40000" >/dev/null
msg_ok "Cache: stale=on, prefetch=9, max=40000"

msg_info "Enabling blocking"
api_call "settings/set" "enableBlocking=true" >/dev/null
msg_ok "Blocking enabled"

# ── Create Zones ──────────────────────────────────────────────────────────────
section "Creating DNS Zones"

for zone in "${ALL_ZONES[@]}"; do
  msg_info "Creating zone: ${zone}"
  api_call "zones/create" "zone=${zone}&type=Primary" >/dev/null
  msg_ok "Zone: ${zone}"
done

# ── Deploy Sync Script ────────────────────────────────────────────────────────
section "Deploying UniFi Sync Script"

# Build network_zone_map JSON
zone_map_json="{"
first=true
for net_id in "${!NETWORK_ZONE_MAP[@]}"; do
  [[ "$first" != "true" ]] && zone_map_json+=","
  zone_map_json+="\"${net_id}\":\"${NETWORK_ZONE_MAP[$net_id]}\""
  first=false
done
zone_map_json+="}"

msg_info "Creating sync config"
mkdir -p /var/lib/unifi-zeus-sync

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
  "base_domain": "${BASE_DOMAIN}",
  "hermes_ip": "${HERMES_IP:-}",
  "npm_url": "http://${HERMES_IP:-localhost}:81",
  "npm_user": "${NPM_USER:-}",
  "npm_pass": "${NPM_PASS:-}",
  "log_file": "/var/log/unifi-zeus-sync.log",
  "network_zone_map": ${zone_map_json}
}
EOF
chmod 600 /etc/unifi-zeus-sync.conf
msg_ok "Config: /etc/unifi-zeus-sync.conf"

msg_info "Deploying sync script"
cat > /usr/local/bin/unifi-zeus-sync.py << 'SYNCSCRIPT'
#!/usr/bin/env python3
"""
unifi-zeus-sync.py
Syncs UniFi active clients to Technitium DNS A/PTR records.
Author: Thomas Van Auken - Van Auken Tech
"""

import urllib.request
import urllib.parse
import http.cookiejar
import ssl
import json
import re
import os
import sys
import logging

CONFIG_FILE = "/etc/unifi-zeus-sync.conf"
STATE_FILE = "/var/lib/unifi-zeus-sync/state.json"

with open(CONFIG_FILE) as f:
    cfg = json.load(f)

UNIFI_URL = cfg["unifi_url"]
UNIFI_USER = cfg["unifi_user"]
UNIFI_PASS = cfg["unifi_pass"]
UNIFI_SITE = cfg["unifi_site"]
ZEUS_URL = cfg["zeus_url"]
ZEUS_TOKEN = cfg["zeus_token"]
DNS_TTL = cfg["dns_ttl"]
SYNC_COMMENT = cfg["sync_comment"]
LOG_FILE = cfg["log_file"]
NET_ZONE_MAP = cfg["network_zone_map"]
BASE_DOMAIN = cfg["base_domain"]
HERMES_IP = cfg.get("hermes_ip", "")
NPM_URL = cfg.get("npm_url", "")
NPM_USER = cfg.get("npm_user", "")
NPM_PASS = cfg.get("npm_pass", "")

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


def ip_to_ptr(ip):
    parts = ip.split(".")
    return f"{parts[3]}.{parts[2]}.{parts[1]}.{parts[0]}.in-addr.arpa"


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
        raise RuntimeError(f"UniFi login failed: {json.dumps(body)[:200]}")
    csrf = resp.headers.get("x-csrf-token", "")
    log.info(f"UniFi login OK")
    return csrf


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
        raise RuntimeError(f"Zeus API error: {data.get('errorMessage')}")
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


def zeus_upsert_cname(cname_fqdn, target_fqdn):
    params = urllib.parse.urlencode({
        "token": ZEUS_TOKEN, "domain": cname_fqdn, "type": "CNAME",
        "cname": target_fqdn, "ttl": str(DNS_TTL), "overwrite": "true",
        "comments": SYNC_COMMENT
    })
    zeus_get(f"api/zones/records/add?{params}")


def zeus_delete_cname(cname_fqdn):
    params = urllib.parse.urlencode({
        "token": ZEUS_TOKEN, "domain": cname_fqdn, "type": "CNAME"
    })
    zeus_get(f"api/zones/records/delete?{params}")


def get_zeus_label_for_ip(ip):
    parts = ip.split(".")
    if len(parts) != 4:
        return None
    ptr_domain = f"{parts[3]}.{parts[2]}.{parts[1]}.{parts[0]}.in-addr.arpa"
    reverse_zone = f"{parts[2]}.{parts[1]}.{parts[0]}.in-addr.arpa"
    params = urllib.parse.urlencode({
        "token": ZEUS_TOKEN, "domain": ptr_domain, "zone": reverse_zone
    })
    try:
        data = zeus_get(f"api/zones/records/get?{params}")
        for rec in data.get("response", {}).get("records", []):
            if rec.get("type") != "PTR":
                continue
            if rec.get("comments", "") == SYNC_COMMENT:
                return None
            ptr_name = rec.get("rData", {}).get("ptrName", "").rstrip(".")
            if ptr_name:
                return sanitize_label(ptr_name.split(".")[0])
    except RuntimeError:
        pass
    return None


def get_npm_proxy_labels():
    if not HERMES_IP or not NPM_USER or not NPM_PASS:
        return set()
    try:
        payload = json.dumps({"identity": NPM_USER, "secret": NPM_PASS}).encode()
        req = urllib.request.Request(
            f"{NPM_URL}/api/tokens",
            data=payload,
            headers={"Content-Type": "application/json"}
        )
        resp = urllib.request.urlopen(req)
        token = json.loads(resp.read().decode()).get("token", "")
        if not token:
            return set()
        req = urllib.request.Request(
            f"{NPM_URL}/api/nginx/proxy-hosts",
            headers={"Authorization": f"Bearer {token}"}
        )
        hosts = json.loads(urllib.request.urlopen(req).read().decode())
        labels = set()
        suffix = f".{BASE_DOMAIN}"
        for h in hosts:
            for domain in h.get("domain_names", []):
                if domain.endswith(suffix):
                    label = domain[:-len(suffix)]
                    if "." not in label:
                        labels.add(label)
        log.info(f"NPM proxy labels: {sorted(labels)}")
        return labels
    except Exception as e:
        log.warning(f"Could not read NPM: {e}")
        return set()


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
    csrf = unifi_login(opener)
    clients = unifi_get(opener, "stat/sta")
    log.info(f"UniFi: {len(clients)} active clients")
    
    expected = {}
    skipped = 0
    
    for client in clients:
        ip = client.get("ip", "").strip()
        if not ip:
            skipped += 1
            continue
        
        network_id = client.get("network_id", "")
        zone = NET_ZONE_MAP.get(network_id)
        if not zone:
            skipped += 1
            continue
        
        zeus_label = get_zeus_label_for_ip(ip)
        if zeus_label:
            raw_label = zeus_label
        else:
            raw_label = client.get("name", "").strip() or client.get("hostname", "").strip()
        
        if not raw_label:
            skipped += 1
            continue
        
        label = sanitize_label(raw_label)
        if not label:
            skipped += 1
            continue
        
        fqdn = f"{label}.{zone}"
        if fqdn in expected and expected[fqdn] != ip:
            skipped += 1
            continue
        
        expected[fqdn] = ip
    
    npm_proxy_labels = get_npm_proxy_labels()
    
    label_to_fqdns = {}
    for fqdn in expected:
        label = fqdn.split(".")[0]
        label_to_fqdns.setdefault(label, []).append(fqdn)
    
    proxy_expected = {}
    cname_expected = {}
    for label, fqdns in label_to_fqdns.items():
        alias_fqdn = f"{label}.{BASE_DOMAIN}"
        if label in npm_proxy_labels:
            proxy_expected[alias_fqdn] = HERMES_IP
        elif len(fqdns) == 1:
            cname_expected[alias_fqdn] = fqdns[0]
    
    log.info(f"Expected: {len(expected)} A, {len(cname_expected)} CNAME, {len(proxy_expected)} proxy")
    
    state = load_state()
    current = state.get("a_records", {})
    current_cnames = state.get("cnames", {})
    current_proxy = state.get("proxy_aliases", {})
    
    added = updated = errors = 0
    for fqdn, ip in expected.items():
        try:
            if fqdn not in current or current[fqdn] != ip:
                zeus_upsert_a(fqdn, ip)
                log.info(f"{'ADD' if fqdn not in current else 'UPDATE'} {fqdn} → {ip}")
                added += 1
        except RuntimeError as e:
            log.error(f"Failed {fqdn}: {e}")
            errors += 1
    
    for alias_fqdn, hermes_ip in proxy_expected.items():
        try:
            if alias_fqdn not in current_proxy:
                try:
                    zeus_delete_cname(alias_fqdn)
                except RuntimeError:
                    pass
                zeus_upsert_a(alias_fqdn, hermes_ip)
                log.info(f"ADD proxy {alias_fqdn} → {hermes_ip}")
        except RuntimeError as e:
            log.error(f"Failed proxy {alias_fqdn}: {e}")
            errors += 1
    
    for cname_fqdn, target_fqdn in cname_expected.items():
        if cname_fqdn in proxy_expected:
            continue
        try:
            if cname_fqdn not in current_cnames or current_cnames[cname_fqdn] != target_fqdn:
                zeus_upsert_cname(cname_fqdn, target_fqdn)
                log.info(f"CNAME {cname_fqdn} → {target_fqdn}")
        except RuntimeError as e:
            log.error(f"Failed CNAME {cname_fqdn}: {e}")
            errors += 1
    
    for fqdn, old_ip in current.items():
        if fqdn not in expected:
            try:
                zeus_delete_a(fqdn, old_ip)
                log.info(f"REMOVE stale {fqdn}")
            except RuntimeError:
                pass
    
    for cname_fqdn in current_cnames:
        if cname_fqdn not in cname_expected:
            try:
                zeus_delete_cname(cname_fqdn)
                log.info(f"REMOVE stale CNAME {cname_fqdn}")
            except RuntimeError:
                pass
    
    log.info(f"=== Sync complete: {added} changes, {errors} errors ===")
    
    if errors == 0:
        save_state({
            "a_records": expected,
            "cnames": cname_expected,
            "proxy_aliases": proxy_expected
        })


if __name__ == "__main__":
    main()
SYNCSCRIPT

chmod +x /usr/local/bin/unifi-zeus-sync.py
msg_ok "Script: /usr/local/bin/unifi-zeus-sync.py"

msg_info "Setting up cron job"
(crontab -l 2>/dev/null | grep -v unifi-zeus-sync; echo "*/5 * * * * /usr/bin/python3 /usr/local/bin/unifi-zeus-sync.py >> /var/log/unifi-zeus-sync.log 2>&1") | crontab -
msg_ok "Cron: every 5 minutes"

msg_info "Running initial sync"
python3 /usr/local/bin/unifi-zeus-sync.py
msg_ok "Initial sync complete"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BL}${BLD}════════════════════════════════════════════════════════${CL}"
echo -e "${BL}${BLD}       CONFIGURATION COMPLETE${CL}"
echo -e "${BL}${BLD}════════════════════════════════════════════════════════${CL}"
echo ""
printf "  Web UI     : ${BL}http://%s:5380${CL}\n" "$(hostname -I | awk '{print $1}')"
printf "  Domain     : ${BL}%s${CL}\n" "$BASE_DOMAIN"
printf "  Zones      : ${BL}%d created${CL}\n" "${#ALL_ZONES[@]}"
printf "  Sync       : ${BL}Every 5 minutes${CL}\n"
printf "  Log        : ${BL}/var/log/unifi-zeus-sync.log${CL}\n"
echo ""
echo -e "  ${YW}DNS Settings:${CL}"
echo "    • Root hints recursion (no external forwarders)"
echo "    • DNSSEC validation enabled"
echo "    • QNAME minimization enabled"
echo ""
echo -e "${GN}Created by: Thomas Van Auken — Van Auken Tech${CL}"
echo ""
