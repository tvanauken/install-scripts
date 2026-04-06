# Technitium DNS — Post-Install Configuration

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0

---

## Overview

Configures a fresh Technitium DNS LXC (installed via Proxmox community-scripts) for UniFi network integration with privacy-first DNS.

## Pre-requisites

1. **Fresh Technitium LXC** via community-scripts:
   ```bash
   bash -c "$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/technitium.sh)"
   ```
2. **UniFi controller** accessible on the network
3. **Root access** to the LXC

## Usage

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