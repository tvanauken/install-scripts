#!/usr/bin/env bash

# Technitium DNS Generic Installer
# Copyright (c) 2025 Thomas Van Auken - Van Auken Tech
# License: MIT
# Repository: https://github.com/tvanauken/install-scripts
# Source: https://technitium.com/dns/
#
# Description: Generic Technitium DNS Server installer with hardcoded configuration.
# Note: This is NOT a replication script. For production deployments that need to
# replicate specific configurations, use a dedicated replication installer instead.

set -euo pipefail

# Update system and install dependencies
apt-get update >/dev/null 2>&1
apt-get -y upgrade >/dev/null 2>&1
apt-get install -y curl libicu76 python3 >/dev/null 2>&1

# Install .NET ASP.NET Core Runtime using official Microsoft install script
curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --runtime aspnetcore --install-dir /usr/share/dotnet --no-path
ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet

# Download Technitium DNS Server portable archive with curl SSL workaround
mkdir -p /opt/technitium/dns
# Use HTTP/1.1 with retry logic to handle OpenSSL 3.x SSL_read EOF issue
curl --http1.1 --no-keepalive --retry 3 --retry-delay 2 --retry-max-time 60 -fsSL \
  https://download.technitium.com/dns/DnsServerPortable.tar.gz | tar -xz -C /opt/technitium/dns

# Disable systemd-resolved to free port 53
systemctl disable --now systemd-resolved >/dev/null 2>&1 || true

# Create systemd service
cat > /etc/systemd/system/dns.service <<'EOF'
[Unit]
Description=Technitium DNS Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/dotnet /opt/technitium/dns/DnsServerApp.dll /etc/dns
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/dns
systemctl daemon-reload
systemctl enable --now dns >/dev/null 2>&1

# Wait for DNS service to start and API to become available
for i in {1..30}; do
    if curl -sf http://127.0.0.1:5380 >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Configure DNS server via API using Python
python3 <<'PYEOF'
import json, urllib.request, urllib.parse, sys

base = "http://127.0.0.1:5380"

# Login and get session token
try:
    login_data = urllib.parse.urlencode({"user": "admin", "pass": "admin"}).encode()
    req = urllib.request.Request(base + "/api/user/login", login_data)
    login_res = urllib.request.urlopen(req, timeout=30).read().decode()
    token = json.loads(login_res)["token"]
except Exception as e:
    print(f"API login failed: {e}", file=sys.stderr)
    sys.exit(1)

# Get store app list and install required apps
app_names = ["Advanced Blocking", "DNS Block List (DNSBL)", "Failover", "Geo Country", "What Is My Dns"]
try:
    req = urllib.request.Request(base + "/api/apps/listStoreApps")
    req.add_header("Authorization", "Bearer " + token)
    store_res = urllib.request.urlopen(req, timeout=30).read().decode()
    store_apps = json.loads(store_res)["response"]["storeApps"]
    
    for app in store_apps:
        if app["name"] in app_names:
            install_data = urllib.parse.urlencode({"name": app["name"], "url": app["url"]}).encode()
            req = urllib.request.Request(base + "/api/apps/downloadAndInstall", install_data)
            req.add_header("Authorization", "Bearer " + token)
            urllib.request.urlopen(req, timeout=120)
except Exception as e:
    print(f"App install failed: {e}", file=sys.stderr)

# Configure recursion ACLs (empty = allow all)
try:
    settings_data = urllib.parse.urlencode({
        "recursionDeniedNetworks": "",
        "recursionAllowedNetworks": ""
    }).encode()
    req = urllib.request.Request(base + "/api/settings/set", settings_data)
    req.add_header("Authorization", "Bearer " + token)
    urllib.request.urlopen(req, timeout=30)
except Exception as e:
    print(f"Recursion config failed: {e}", file=sys.stderr)

# Enable logging with query logging (UTC time)
try:
    log_data = urllib.parse.urlencode({
        "enableLogging": "true",
        "logQueries": "true",
        "useLocalTime": "false",
        "logFolder": "logs"
    }).encode()
    req = urllib.request.Request(base + "/api/settings/set", log_data)
    req.add_header("Authorization", "Bearer " + token)
    urllib.request.urlopen(req, timeout=30)
except Exception as e:
    print(f"Logging config failed: {e}", file=sys.stderr)

PYEOF