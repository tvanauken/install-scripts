# Technitium DNS Server — User Manual

> **Created by:** Thomas Van Auken — Van Auken Tech
> **Version:** 3.0.0
> **Date:** 2026-04-05
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Version History

| Version | Date | Changes |
|---------|------|------|
| 3.0.0 | 2026-04-05 | Root hints only, UniFi survey, dynamic zones, auto-sync |
| 2.0.0 | 2026-04-05 | DNSSEC, hagezi blocklists |
| 1.1.0 | 2026-03-31 | Initial release (deprecated) |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [Configuration Prompts](#5-configuration-prompts)
6. [What Gets Installed](#6-what-gets-installed)
7. [UniFi Sync](#7-unifi-sync)
8. [DNS Configuration](#8-dns-configuration)
9. [Web Interface](#9-web-interface)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This script installs and configures Technitium DNS Server with full UniFi network integration. It automatically discovers your network topology and creates appropriate DNS zones, with a sync script that maintains A and PTR records for all DHCP clients.

**Key Design Principle:** This DNS server uses **root hints only** for external resolution. No DNS queries are forwarded to external providers like Google (8.8.8.8), Cloudflare (1.1.1.1), or Quad9 (9.9.9.9). All external resolution traverses the root → TLD → authoritative path, maximizing privacy.

---

## 2. Features

### Privacy-First Resolution
- Root hints recursion only — no external forwarders
- QNAME minimization to reduce information leakage
- DNSSEC validation for all responses

### UniFi Integration
- Surveys UniFi Controller to discover all networks
- Creates zones automatically based on discovered VLANs
- Deploys sync script for automatic A/PTR records
- Cron job runs every 5 minutes

### Security
- Ad/tracking blocking via Hagezi blocklists
- Recursion limited to private networks only
- API access with authentication

### Automation
- Dynamic zone creation from network discovery
- Backend zones for reverse proxy integration
- State tracking to remove stale records

---

## 3. Prerequisites

### Hardware Requirements
- CPU: 1 vCPU minimum
- RAM: 512 MB minimum
- Disk: 4 GB minimum

### Software Requirements
- Debian 12+ or Ubuntu 22.04+
- Root/sudo access
- Network connectivity

### Network Requirements
- Static IP address for this server
- Access to UniFi Controller API
- Firewall rules allowing:
  - TCP/UDP 53 (DNS)
  - TCP 5380 (Web UI)

---

## 4. Installation

### One-Liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

### Manual Download

```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh -o dns-install.sh
chmod +x dns-install.sh
sudo ./dns-install.sh
```

---

## 5. Configuration Prompts

The installer prompts for the following information:

| Prompt | Description | Example |
|--------|-------------|------|
| DNS Server IP | Static IP of this server | `172.16.250.8` |
| Admin username | Technitium web UI login | `admin` |
| Admin password | Minimum 8 characters | (secure password) |
| Base domain | Your internal domain | `home.example.com` |
| UniFi Controller URL | Full URL with protocol | `https://192.168.1.1` |
| UniFi username | Local-only API user | `customapi` |
| UniFi password | | |
| UniFi site | Site name | `default` |
| Hermes/NPM IP | Reverse proxy IP (optional) | `172.16.250.9` |
| Reverse subnets | Comma-separated | `172.16.250,192.168.1` |

---

## 6. What Gets Installed

### Software
- Technitium DNS Server (latest)
- Python 3 with `requests` library
- `unifi-zeus-sync.py` sync script

### Files Created

| Path | Purpose |
|------|------|
| `/etc/dns/` | Technitium configuration |
| `/usr/local/bin/unifi-zeus-sync.py` | UniFi sync script |
| `/etc/unifi-zeus-sync.conf` | Sync script config |
| `/var/lib/unifi-zeus-sync/state.json` | State tracking |
| `/var/log/unifi-zeus-sync.log` | Sync log |

### Cron Jobs
```
*/5 * * * * /usr/bin/python3 /usr/local/bin/unifi-zeus-sync.py >> /var/log/unifi-zeus-sync.log 2>&1
```

### Firewall Rules (if UFW enabled)
- Port 53 TCP/UDP (DNS)
- Port 5380 TCP (Web UI)

---

## 7. UniFi Sync

The sync script automatically maintains DNS records for all DHCP clients.

### How It Works

1. Script queries UniFi Controller for active clients
2. For each client with a hostname:
   - Determines zone from network_id → zone mapping
   - Creates/updates A record: `hostname.zone.domain`
   - Creates/updates PTR record for reverse lookup
3. Removes records for clients no longer present

### Configuration File

Located at `/etc/unifi-zeus-sync.conf`:

```ini
[unifi]
controller_url = https://192.168.1.1
username = customapi
password = ********
site = default
verify_ssl = false

[technitium]
api_url = http://127.0.0.1:5380
username = admin
password = ********

[mapping]
# network_id = zone
6543210abc = mgmt.home.example.com
6543210def = servers.home.example.com
6543210ghi = iot.home.example.com
```

### Manual Sync Run

```bash
python3 /usr/local/bin/unifi-zeus-sync.py
```

### View Sync Log

```bash
tail -f /var/log/unifi-zeus-sync.log
```

---

## 8. DNS Configuration

### Recursion Settings
- **Mode:** `AllowOnlyForPrivateNetworks`
- **Forwarders:** None (root hints only)
- **DNSSEC:** Validation enabled
- **QNAME Minimization:** Enabled

### Blocklists
The following Hagezi blocklists are enabled:
- Multi Pro
- Threat Intelligence Feeds
- DNS NoTrack

### Zone Structure

Zones are created dynamically based on UniFi network discovery:

```
home.example.com                    (primary)
├── mgmt.home.example.com           (from "Management" network)
├── servers.home.example.com        (from "Servers" network)
├── iot.home.example.com            (from "IoT" network)
├── backend.mgmt.home.example.com   (for proxy)
└── 250.16.172.in-addr.arpa         (reverse)
```

---

## 9. Web Interface

### Access
Open `http://<DNS-IP>:5380` in a browser.

### Key Sections
- **Dashboard:** Query statistics, cache status
- **Zones:** Manage all DNS zones and records
- **Settings → DNS:** Recursion, forwarders, DNSSEC
- **Settings → Blocking:** Blocklist management
- **Logs:** Query logs, audit logs

### Adding Manual Records

1. Go to **Zones** → select zone
2. Click **Add Record**
3. Select record type (A, AAAA, CNAME, SRV, etc.)
4. Fill in name and value
5. Click **Add**

---

## 10. Maintenance

### Service Management

```bash
# Status
systemctl status dns

# Restart
systemctl restart dns

# Stop
systemctl stop dns

# Start
systemctl start dns
```

### Backup

```bash
# Full backup
tar czf dns-backup-$(date +%Y%m%d).tar.gz \
  /etc/dns \
  /etc/unifi-zeus-sync.conf \
  /var/lib/unifi-zeus-sync
```

### Restore

```bash
# Stop service
systemctl stop dns

# Extract backup
tar xzf dns-backup-YYYYMMDD.tar.gz -C /

# Restart
systemctl start dns
```

### Log Rotation

Add to `/etc/logrotate.d/unifi-zeus-sync`:

```
/var/log/unifi-zeus-sync.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## 11. Troubleshooting

### DNS Not Resolving

1. Check service status:
   ```bash
   systemctl status dns
   ```

2. Test local resolution:
   ```bash
   dig @127.0.0.1 google.com
   ```

3. Check port binding:
   ```bash
   ss -tuln | grep :53
   ```

4. Check firewall:
   ```bash
   ufw status
   ```

### Sync Not Working

1. Check log for errors:
   ```bash
   tail -50 /var/log/unifi-zeus-sync.log
   ```

2. Verify UniFi credentials:
   ```bash
   curl -k -X POST https://CONTROLLER/api/login \
     -d '{"username":"USER","password":"PASS"}'
   ```

3. Test manual run:
   ```bash
   python3 /usr/local/bin/unifi-zeus-sync.py
   ```

4. Check cron is running:
   ```bash
   crontab -l | grep sync
   ```

### Slow External Resolution

Root hints resolution is inherently slower than forwarders on first query (cold cache). This is expected behavior. Subsequent queries use cache.

To warm the cache:
```bash
dig @127.0.0.1 google.com
dig @127.0.0.1 microsoft.com
dig @127.0.0.1 amazon.com
```

### Web UI Not Accessible

1. Check service:
   ```bash
   systemctl status dns
   ```

2. Check port:
   ```bash
   ss -tuln | grep :5380
   ```

3. Check firewall:
   ```bash
   ufw allow 5380/tcp
   ```

---

## Integration

For complete HTTPS access to internal servers with valid SSL certificates, deploy this DNS server alongside the [Nginx Proxy Manager installer](../../npm-reverse-proxy/).

See the [Master User Manual](../../docs/dns-npm-infrastructure-manual.md) for complete pair deployment documentation.

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
