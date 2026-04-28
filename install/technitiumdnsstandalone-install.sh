#!/usr/bin/env bash

# Copyright (c) 2025 Thomas Van Auken - Van Auken Tech
# License: MIT
# Repository: https://github.com/tvanauken/install-scripts
# Source: https://technitium.com/dns/

set -euo pipefail

# Update system
apt-get update >/dev/null 2>&1
apt-get -y upgrade >/dev/null 2>&1

# Install dependencies
apt-get install -y curl wget gnupg2 ca-certificates apt-transport-https jq >/dev/null 2>&1

# Add Microsoft repo for .NET
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/13/prod trixie main" > /etc/apt/sources.list.d/microsoft-prod.list
apt-get update >/dev/null 2>&1
apt-get install -y aspnetcore-runtime-10.0 >/dev/null 2>&1

# Install Technitium using official installer
RELEASE=$(curl -fsSL https://technitium.com/dns/ | grep -oP 'Version \K[\d.]+')
mkdir -p /opt/technitium/dns
curl -fsSL https://download.technitium.com/dns/DnsServerPortable.tar.gz | tar -xz -C /opt/technitium/dns
echo "${RELEASE}" >~/.technitium

# Create service
mkdir -p /etc/dns /var/log/technitium/dns
sed -i '/^User=/d;/^Group=/d' /opt/technitium/dns/systemd.service
cp /opt/technitium/dns/systemd.service /etc/systemd/system/technitium.service
systemctl enable --now technitium >/dev/null 2>&1

# Wait for service to start
sleep 20

# Get API token
TOKEN=$(cat /etc/dns/dns.config 2>/dev/null | jq -r '.webServiceRootApiToken // empty' 2>/dev/null)
if [ -n "$TOKEN" ]; then
    # Install apps
    curl -fsSL https://download.technitium.com/dns/apps/AdvancedBlockingApp-v10.zip -o /tmp/AdvancedBlocking.zip
    curl -X POST -F 'dnsApp=@/tmp/AdvancedBlocking.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/AdvancedBlocking.zip
    
    curl -fsSL https://download.technitium.com/dns/apps/AutoPtrApp-v4.zip -o /tmp/AutoPtr.zip
    curl -X POST -F 'dnsApp=@/tmp/AutoPtr.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/AutoPtr.zip
    
    curl -fsSL https://download.technitium.com/dns/apps/DropRequestsApp-v7.zip -o /tmp/DropRequests.zip
    curl -X POST -F 'dnsApp=@/tmp/DropRequests.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/DropRequests.zip
    
    curl -fsSL https://download.technitium.com/dns/apps/LogExporterApp-v2.1.zip -o /tmp/LogExporter.zip
    curl -X POST -F 'dnsApp=@/tmp/LogExporter.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/LogExporter.zip
    
    curl -fsSL https://download.technitium.com/dns/apps/QueryLogsSqliteApp-v8.zip -o /tmp/QueryLogs.zip
    curl -X POST -F 'dnsApp=@/tmp/QueryLogs.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/QueryLogs.zip
    
    # Configure recursion to use root hints only
    curl -fsSL -X POST "http://localhost:5380/api/settings/set?token=$TOKEN&recursion=UseRootHints" >/dev/null 2>&1
fi
