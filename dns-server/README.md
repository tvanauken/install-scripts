# Technitium DNS Server Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Collection Version: 3.0.0

---

## Overview

Three scripts for deploying Technitium DNS Server on Proxmox VE:

1. **Standalone Installation** — Creates LXC and installs DNS server in one command
2. **Full Installation + UniFi** — Installs with UniFi network integration
3. **Post-Install Configuration** — Adds UniFi integration to existing installations

---

## 1. Standalone Installation (New!)

**Purpose:** One-command deployment of Technitium DNS Server in a new LXC container.

**Target:** Proxmox VE nodes (runs from node shell)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
```

**What It Does:**
- Creates Debian 13 LXC (2 CPU, 2GB RAM, 8GB disk)
- Installs Technitium DNS Server with .NET runtime
- Installs 5 apps (Advanced Blocking, Auto PTR, Drop Requests, Log Exporter, Query Logs)
- Configures 4 Hagezi blocklists
- Enables root hints recursion (privacy-first)
- No configuration prompts — enterprise defaults

**Documentation:** [Standalone Manual](docs/technitium-dns-standalone-manual.md) | [Quick README](docs/technitium-dns-standalone-README.md)

---

## 2. Full Installation with UniFi Integration

**Purpose:** Installs Technitium DNS with automatic UniFi network discovery and dynamic zone creation.

**Target:** Existing LXC containers (install LXC first via community-scripts)

**Prerequisites:**

1. **Fresh Technitium LXC** via community-scripts:
   ```bash
   bash -c "$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/technitium.sh)"
   ```
2. **UniFi controller** accessible on the network
3. **Root access** to the LXC

**Usage:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

**What It Does:**
- Surveys UniFi to discover all networks
- Creates DNS zones for each VLAN
- Deploys sync script for automatic A/PTR records
- Configures root hints recursion (no forwarders)
- Sets up cron job for dynamic updates

**Documentation:** [Full Manual](docs/user-manual.md)

---

## 3. Post-Install Configuration (UniFi Integration)

**Purpose:** Adds UniFi integration to an already-installed Technitium DNS server.

**Prerequisites:**

1. **Technitium DNS already installed** (via community-scripts or manual install)
2. **UniFi controller** accessible on the network
3. **Root access** to the LXC

**Usage:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-configure.sh)
```

## What It Does

1. **Surveys UniFi** — discovers all networks and VLANs
2. **Configures DNS settings:**
   - Root hints recursion (no external forwarders — privacy-first)
   - DNSSEC validation
   - QNAME minimization
   - Cache: 40,000 entries, stale serving, prefetch
   - Blocking enabled
3. **Creates zones** for each discovered network
4. **Deploys sync script** — `unifi-zeus-sync.py`
5. **Sets up cron** — runs every 5 minutes

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| Technitium username | Admin account | `admin` |
| Technitium password | Set during install | |
| Base domain | Your internal domain | `home.example.com` |
| DNS server hostname | This server's FQDN | `dns.dmz.home.example.com` |
| UniFi URL | Controller address | `https://192.168.1.1` |
| UniFi username | API user recommended | `customapi` |
| UniFi password | | |
| NPM/Hermes IP | Reverse proxy (optional) | `172.16.250.9` |

## UniFi Sync

The sync script automatically:
- Reads DHCP clients from UniFi
- Creates A records in appropriate zones
- Creates PTR records for reverse lookups
- Removes stale records when devices leave

**Log:** `/var/log/unifi-zeus-sync.log`  
**Config:** `/etc/unifi-zeus-sync.conf`  
**State:** `/var/lib/unifi-zeus-sync/state.json`

## Integration

Use with the [NPM configuration script](../npm-reverse-proxy/) for HTTPS access to internal servers.

---
*Van Auken Tech · Thomas Van Auken*