#!/usr/bin/env bash

# Copyright (c) 2025 Thomas Van Auken - Van Auken Tech
# License: MIT
# Repository: https://github.com/tvanauken/install-scripts
# Source: https://technitium.com/dns/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
setup_deb822_repo \
  "microsoft" \
  "https://packages.microsoft.com/keys/microsoft-2025.asc" \
  "https://packages.microsoft.com/debian/13/prod/" \
  "trixie" \
  "main"
$STD apt install -y aspnetcore-runtime-10.0
msg_ok "Installed Dependencies"

RELEASE=$(curl -fsSL https://technitium.com/dns/ | grep -oP 'Version \K[\d.]+')
fetch_and_deploy_from_url "https://download.technitium.com/dns/DnsServerPortable.tar.gz" /opt/technitium/dns
echo "${RELEASE}" >~/.technitium

msg_info "Creating service"
mkdir -p /etc/dns /var/log/technitium/dns
sed -i '/^User=/d;/^Group=/d' /opt/technitium/dns/systemd.service
cp /opt/technitium/dns/systemd.service /etc/systemd/system/technitium.service
systemctl enable -q --now technitium
msg_ok "Service created"

# Wait for Technitium to start
msg_info "Waiting for Technitium API to be ready"
sleep 15

# Get API token
TOKEN=$(cat /etc/dns/dns.config 2>/dev/null | jq -r '.webServiceRootApiToken // empty' 2>/dev/null)
if [ -n "$TOKEN" ]; then
    msg_info "Installing Technitium Apps"
    
    # Advanced Blocking v10
    curl -fsSL https://download.technitium.com/dns/apps/AdvancedBlockingApp-v10.zip -o /tmp/AdvancedBlocking.zip 2>/dev/null
    curl -X POST -F 'dnsApp=@/tmp/AdvancedBlocking.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/AdvancedBlocking.zip
    
    # Auto PTR v4
    curl -fsSL https://download.technitium.com/dns/apps/AutoPtrApp-v4.zip -o /tmp/AutoPtr.zip 2>/dev/null
    curl -X POST -F 'dnsApp=@/tmp/AutoPtr.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/AutoPtr.zip
    
    # Drop Requests v7
    curl -fsSL https://download.technitium.com/dns/apps/DropRequestsApp-v7.zip -o /tmp/DropRequests.zip 2>/dev/null
    curl -X POST -F 'dnsApp=@/tmp/DropRequests.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/DropRequests.zip
    
    # Log Exporter v2.1
    curl -fsSL https://download.technitium.com/dns/apps/LogExporterApp-v2.1.zip -o /tmp/LogExporter.zip 2>/dev/null
    curl -X POST -F 'dnsApp=@/tmp/LogExporter.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/LogExporter.zip
    
    # Query Logs (Sqlite) v8
    curl -fsSL https://download.technitium.com/dns/apps/QueryLogsSqliteApp-v8.zip -o /tmp/QueryLogs.zip 2>/dev/null
    curl -X POST -F 'dnsApp=@/tmp/QueryLogs.zip' "http://localhost:5380/api/apps/install?token=$TOKEN" >/dev/null 2>&1
    rm -f /tmp/QueryLogs.zip
    
    msg_ok "Installed Technitium Apps"
    
    # Install Hagezi blocklists
    msg_info "Installing Hagezi blocklists"
    
    # Pro++ Blocklist
    curl -fsSL -X POST "http://localhost:5380/api/apps/config/set?token=$TOKEN&name=Advanced%20Blocking&config=%7B%22enableBlocking%22%3Atrue%2C%22allowListUrls%22%3A%5B%5D%2C%22blockListUrls%22%3A%5B%22https%3A%2F%2Fraw.githubusercontent.com%2Fhagezi%2Fdns-blocklists%2Fmain%2Fadblock%2Fpro.plus.txt%22%5D%2C%22blockingBypassList%22%3A%5B%5D%7D" >/dev/null 2>&1
    
    # TIF Blocklist
    curl -fsSL -X POST "http://localhost:5380/api/apps/config/set?token=$TOKEN&name=Advanced%20Blocking%20%282%29&config=%7B%22enableBlocking%22%3Atrue%2C%22allowListUrls%22%3A%5B%5D%2C%22blockListUrls%22%3A%5B%22https%3A%2F%2Fraw.githubusercontent.com%2Fhagezi%2Fdns-blocklists%2Fmain%2Fadblock%2Ftif.txt%22%5D%2C%22blockingBypassList%22%3A%5B%5D%7D" >/dev/null 2>&1
    
    # DynDNS Blocklist
    curl -fsSL -X POST "http://localhost:5380/api/apps/config/set?token=$TOKEN&name=Advanced%20Blocking%20%283%29&config=%7B%22enableBlocking%22%3Atrue%2C%22allowListUrls%22%3A%5B%5D%2C%22blockListUrls%22%3A%5B%22https%3A%2F%2Fraw.githubusercontent.com%2Fhagezi%2Fdns-blocklists%2Fmain%2Fadblock%2Fdyndns.txt%22%5D%2C%22blockingBypassList%22%3A%5B%5D%7D" >/dev/null 2>&1
    
    # Badware Hoster Blocklist
    curl -fsSL -X POST "http://localhost:5380/api/apps/config/set?token=$TOKEN&name=Advanced%20Blocking%20%284%29&config=%7B%22enableBlocking%22%3Atrue%2C%22allowListUrls%22%3A%5B%5D%2C%22blockListUrls%22%3A%5B%22https%3A%2F%2Fraw.githubusercontent.com%2Fhagezi%2Fdns-blocklists%2Fmain%2Fadblock%2Fhoster.txt%22%5D%2C%22blockingBypassList%22%3A%5B%5D%7D" >/dev/null 2>&1
    
    msg_ok "Installed Hagezi blocklists"
    
    # Configure root hints recursion
    msg_info "Configuring DNS recursion"
    curl -fsSL -X POST "http://localhost:5380/api/settings/set?token=$TOKEN&recursion=UseRootHints&recursionDeniedNetworks=&recursionAllowedNetworks=&randomizeName=true&qnameMinimization=true&nsRevalidation=true&qpmLimitRequests=3000&qpmLimitErrors=300&qpmLimitSampleMinutes=5&qpmLimitIPv4PrefixLength=24&qpmLimitIPv6PrefixLength=56&serveStale=true&serveStaleTtl=259200&cacheMinimumRecordTtl=10&cacheMaximumRecordTtl=86400&cacheNegativeRecordTtl=300&cacheFailureRecordTtl=60&cachePrefetchEligibility=2&cachePrefetchTrigger=9&cachePrefetchSampleIntervalInMinutes=5&cachePrefetchSampleEligibilityHitsPerHour=30" >/dev/null 2>&1
    msg_ok "Configured DNS recursion"
else
    msg_warn "Could not retrieve API token - apps and configuration will need to be set up manually"
fi

motd_ssh
customize
cleanup_lxc
