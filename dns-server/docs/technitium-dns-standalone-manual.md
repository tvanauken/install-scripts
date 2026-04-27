# Technitium DNS Server — Standalone LXC Installation Manual

> **Created by:** Thomas Van Auken — Van Auken Tech  
> **Version:** 1.0.0  
> **Date:** 2026-04-27  
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [What Gets Installed](#5-what-gets-installed)
6. [Post-Installation](#6-post-installation)
7. [Web Interface](#7-web-interface)
8. [DNS Configuration](#8-dns-configuration)
9. [Maintenance](#9-maintenance)
10. [Troubleshooting](#10-troubleshooting)
11. [Comparison with Other Scripts](#11-comparison-with-other-scripts)

---

## 1. Overview

This script automates the complete deployment of Technitium DNS Server on Proxmox VE. Unlike configuration-only scripts that require pre-existing LXC containers, this standalone installer creates the LXC container from scratch and installs everything in one step.

**Key Design:** Enterprise-ready defaults with privacy-first DNS resolution using root hints only (no external forwarders).

---

## 2. Features

### Automated LXC Creation
- Debian 13 (Trixie) base OS
- 2 CPU cores, 2GB RAM, 8GB disk
- Auto-selects available storage pools
- DHCP networking
- Unprivileged container with keyctl and nesting

### Complete DNS Installation
- Technitium DNS Server (latest version)
- .NET 9.0 Runtime (via official Technitium installer)
- Systemd service auto-start on boot

### Pre-Configured Apps
Five essential Technitium apps installed and ready:
- **Advanced Blocking v10** — Enhanced ad/tracker blocking
- **Auto PTR v4** — Automatic reverse DNS records
- **Drop Requests v7** — Request filtering
- **Log Exporter v2.1** — External log forwarding
- **Query Logs (Sqlite) v8** — Local query logging

### Privacy-First DNS
- Root hints recursion (no external forwarders)
- QNAME minimization enabled
- 4 Hagezi blocklists:
  - Multi Pro
  - Popup Ads
  - Threat Intelligence Feeds
  - Fake

---

## 3. Prerequisites

### Required
- Proxmox VE 8.x or 9.x
- Root access to Proxmox node
- Internet connectivity
- Available storage pool with rootdir and vztmpl support

### Recommended
- At least 10GB free storage
- Static IP configuration available for container (post-install)

---

## 4. Installation

### One-Liner Installation

Run from **any Proxmox VE node** command prompt:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
```

### Installation Steps

The script automatically:
1. Detects template and container storage pools
2. Downloads Debian 13 LXC template (if not cached)
3. Creates LXC container with next available ID
4. Starts container and waits for network
5. Updates Debian system packages
6. Installs Technitium DNS via official installer
7. Installs and configures 5 apps
8. Applies blocklists
9. Configures root hints recursion
10. Displays completion summary with credentials

**Typical installation time:** 3-5 minutes

---

## 5. What Gets Installed

### LXC Container Specifications

| Setting | Value |
|---------|-------|
| OS | Debian 13 (Trixie) |
| Hostname | technitium-dns |
| CPU | 2 cores |
| RAM | 2048 MB |
| Disk | 8 GB |
| Network | DHCP (eth0 on vmbr0) |
| Features | keyctl=1, nesting=1 |
| Privilege | Unprivileged |

### Software Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Technitium DNS | Latest | DNS server |
| .NET Runtime | 9.0 | ASP.NET Core runtime |
| curl, wget, jq | Latest | Dependencies |
| mc (Midnight Commander) | Latest | Container management |

### Technitium Apps

| App Name | Version | Function |
|----------|---------|----------|
| Advanced Blocking | v10 | Enhanced ad/tracker blocking |
| Auto PTR | v4 | Automatic reverse DNS |
| Drop Requests | v7 | Request filtering |
| Log Exporter | v2.1 | External log forwarding |
| Query Logs (Sqlite) | v8 | Local query logging |

### DNS Configuration Applied

| Setting | Value |
|---------|-------|
| Recursion | Allow |
| QNAME Minimization | Enabled |
| DNSSEC Validation | Default |
| Forwarders | None (root hints only) |
| Blocking | Enabled |
| Blocklists | 4 Hagezi lists |

---

## 6. Post-Installation

### Accessing the Web Interface

The script displays the container IP address at completion:

```
Web Interface: http://172.16.x.x:5380
```

### Default Credentials

| Field | Value |
|-------|-------|
| Username | admin |
| Password | admin |

**⚠ CRITICAL:** Change the default password immediately upon first login.

### Credentials File

Container root password and API token are saved to:
```
~/technitium-dns-<CTID>.creds
```

Example for container 123:
```
~/technitium-dns-123.creds
```

### Setting Static IP (Recommended)

DHCP is used initially for automatic setup. For production use, set a static IP:

```bash
# From Proxmox node
pct stop 123
pct set 123 -net0 name=eth0,bridge=vmbr0,ip=172.16.250.8/16,gw=172.16.0.1
pct start 123
```

---

## 7. Web Interface

### First Login

1. Navigate to `http://<container-ip>:5380`
2. Login with admin / admin
3. **Change password immediately** (Settings → User Management)

### Dashboard Overview

- **Query Statistics** — Real-time DNS query metrics
- **Cache Status** — Cache hit rate and size
- **Top Clients** — Most active DNS clients
- **Top Domains** — Most queried domains
- **Top Blocked** — Most blocked domains

### Key Sections

#### Zones
Manage DNS zones and records:
- Create new zones
- Add A, AAAA, CNAME, MX, SRV, PTR records
- Enable dynamic updates (RFC 2136)

#### Apps
View installed apps:
- Advanced Blocking
- Auto PTR
- Drop Requests
- Log Exporter
- Query Logs (Sqlite)

#### Settings
- **DNS Settings** — Recursion, forwarders, DNSSEC
- **Blocking** — Manage blocklists
- **Logging** — Query logging configuration
- **Advanced** — API, network bindings

---

## 8. DNS Configuration

### Recursion Settings

The server is configured for **privacy-first** DNS resolution:

- **Recursion:** Enabled (Allow)
- **Forwarders:** None
- **Root Hints:** Enabled
- **QNAME Minimization:** Enabled

This means:
- All external queries traverse: Root → TLD → Authoritative
- No queries sent to Google (8.8.8.8), Cloudflare (1.1.1.1), or other third parties
- Maximum privacy — no external resolver sees your full query load

### Blocklists

Four Hagezi blocklists are pre-configured:

| Blocklist | URL | Purpose |
|-----------|-----|---------|
| Multi Pro | `gitlab.com/hagezi/mirror/.../multi.txt` | Multi-category blocking |
| Popup Ads | `gitlab.com/hagezi/mirror/.../popupads.txt` | Popup advertisement blocking |
| TIF | `gitlab.com/hagezi/mirror/.../tif.txt` | Threat Intelligence Feeds |
| Fake | `gitlab.com/hagezi/mirror/.../fake.txt` | Fake/phishing sites |

**Blocklist Updates:** Automatic (configured in Advanced Blocking app)

### Creating Zones

To create your own DNS zones:

1. Go to **Zones** → **Add Zone**
2. Select **Primary Zone**
3. Enter zone name (e.g., `home.example.com`)
4. Click **Add**

### Adding Records

1. Select zone from list
2. Click **Add Record**
3. Select record type (A, AAAA, CNAME, etc.)
4. Enter details:
   - **Name:** Hostname (e.g., `server1`)
   - **IP Address:** Target IP
   - **TTL:** Time to live (default 3600)
5. Click **Add**

---

## 9. Maintenance

### Container Management

```bash
# Start container
pct start 123

# Stop container
pct stop 123

# Restart container
pct restart 123

# View container status
pct status 123

# Enter container console
pct enter 123
```

### Service Management

From inside the container:

```bash
# View service status
systemctl status dns

# Restart DNS service
systemctl restart dns

# View DNS logs
journalctl -u dns -f

# Stop service
systemctl stop dns

# Start service
systemctl start dns
```

### Backup

#### Full Container Backup (from Proxmox node)

```bash
# Manual backup
vzdump 123 --compress zstd --mode stop --storage <storage-name>
```

#### Configuration Backup (from inside container)

```bash
tar czf dns-backup-$(date +%Y%m%d).tar.gz /etc/dns
```

### Restore

#### Restore Container

```bash
# List backups
pvesm list <storage-name> --content backup

# Restore backup
pct restore 123 <storage-name>:backup/vzdump-lxc-123-*.tar.zst
```

#### Restore Configuration

```bash
# Stop service
systemctl stop dns

# Extract backup
tar xzf dns-backup-YYYYMMDD.tar.gz -C /

# Restart service
systemctl start dns
```

### Updates

```bash
# Enter container
pct enter 123

# Update packages
apt-get update && apt-get upgrade -y

# Check Technitium version
curl -s http://localhost:5380/api/version | jq
```

---

## 10. Troubleshooting

### DNS Service Not Running

```bash
# Check service status
systemctl status dns

# View recent logs
journalctl -u dns -n 50

# Check dotnet installation
which dotnet
dotnet --version

# Restart service
systemctl restart dns
```

### Container Won't Start

```bash
# View container status
pct status 123

# Check container configuration
pct config 123

# View Proxmox logs
tail -50 /var/log/pve/tasks/*
```

### Web Interface Not Accessible

```bash
# Check port binding
pct exec 123 -- ss -tuln | grep 5380

# Check firewall (if enabled)
pct exec 123 -- ufw status

# Test from Proxmox node
curl -v http://<container-ip>:5380
```

### DNS Queries Not Resolving

```bash
# Test DNS from inside container
pct exec 123 -- dig @127.0.0.1 google.com

# Check recursion settings
pct exec 123 -- curl -s "http://localhost:5380/api/settings/get" | jq '.recursion'

# View query logs
# Login to web interface → Logs → Query Logs
```

### API Token Issues

```bash
# Retrieve API token
pct exec 123 -- cat /etc/dns/.creds

# Or from dns.config
pct exec 123 -- cat /etc/dns/dns.config | jq -r '.webServiceRootApiToken'
```

### Slow External Resolution

Root hints resolution is inherently slower on first query (cold cache). This is expected and maximizes privacy.

To warm cache for common domains:

```bash
pct exec 123 -- dig @127.0.0.1 google.com
pct exec 123 -- dig @127.0.0.1 microsoft.com
pct exec 123 -- dig @127.0.0.1 cloudflare.com
```

Subsequent queries will be fast (cached).

---

## 11. Comparison with Other Scripts

The Van Auken Tech Install Scripts Collection includes three Technitium DNS scripts:

| Script | Purpose | Creates LXC | Requires Existing LXC | UniFi Integration |
|--------|---------|-------------|----------------------|-------------------|
| **technitium-dns-standalone.sh** | **Standalone install** | **✓** | | |
| technitium-dns-install.sh | Full install + UniFi | | ✓ | ✓ |
| technitium-dns-configure.sh | Post-install config | | ✓ | ✓ |

### Use This Script When:

- You want a **quick, simple DNS server**
- You don't use UniFi networking
- You want enterprise-ready defaults without configuration prompts
- You need a standalone recursive DNS resolver

### Use technitium-dns-install.sh When:

- You have a **UniFi network**
- You want **automatic zone creation** from UniFi network discovery
- You need **dynamic DNS sync** with DHCP clients
- You want **split-horizon DNS** with VLAN zones

### Use technitium-dns-configure.sh When:

- You already **installed Technitium** via Proxmox community scripts
- You want to **add UniFi integration** to existing installation

---

## Integration

### Use with Nginx Proxy Manager

For complete internal infrastructure, pair this DNS server with the [Nginx Proxy Manager installer](../../npm-reverse-proxy/):

- DNS server provides internal resolution
- NPM provides HTTPS for internal services
- Wildcard certificate covers all subdomains
- Dynamic SRV-based routing

See [DNS & NPM Infrastructure Manual](../../docs/dns-npm-infrastructure-manual.md) for complete integration guide.

---

## Support

For issues, questions, or contributions:

**Repository:** https://github.com/tvanauken/install-scripts  
**Script Location:** dns-server/technitium-dns-standalone.sh

---

*Created by: Thomas Van Auken — Van Auken Tech*  
*Repository: https://github.com/tvanauken/install-scripts*
