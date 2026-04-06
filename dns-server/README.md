# Technitium DNS Server — Installation Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 3.0.0  
> Tested on: Ubuntu 22.04+, Debian 12+, Proxmox VE 8.x/9.x

---

## Version History

| Version | Date | Changes |
|---------|------|------|
| 3.0.0 | 2026-04-05 | Root hints only (no external forwarders), UniFi survey, dynamic zones |
| 2.0.0 | 2026-04-05 | DNSSEC, hagezi blocklists |
| 1.1.0 | 2026-03-31 | Initial release (deprecated) |

---

## Scripts Available

### 1. Full Installation Script (Recommended)
**Script:** [`technitium-dns-install.sh`](technitium-dns-install.sh)

Installs Technitium DNS Server from scratch with UniFi network discovery.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

**Features:**
- Installs Technitium DNS Server from official source
- **Surveys UniFi Controller** to discover all networks/VLANs
- **Root hints recursion only** — no data transmitted to external DNS (Google, Cloudflare, etc.)
- Dynamically creates zones for each discovered network
- Creates backend zones for reverse proxy integration
- DNSSEC validation and QNAME minimization enabled
- Hagezi ad/tracking blocklists
- Deploys `unifi-zeus-sync.py` for automatic A/PTR record sync
- Cron job runs sync every 5 minutes

### 2. Post-Install Configuration Script
**Script:** [`dns-server-install.sh`](dns-server-install.sh)

For use when Technitium is already installed (e.g., via community-scripts.org).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

---

## Zone Structure

The full installer dynamically discovers your UniFi networks and creates zones:

```
home.example.com                  (primary zone)
├── mgmt.home.example.com         (discovered VLAN zone)
├── servers.home.example.com      (discovered VLAN zone)
├── iot.home.example.com          (discovered VLAN zone)
├── backend.mgmt.home.example.com (for SSL proxy)
└── backend.servers.home.example.com
```

**Backend zones** store real server IPs while public zones point to the proxy.

---

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| DNS Server IP | This server's IP | `172.16.250.8` |
| Admin username | Technitium admin | `admin` |
| Admin password | Min 8 characters | (secure) |
| Base domain | Your internal domain | `home.example.com` |
| UniFi Controller URL | Full URL | `https://192.168.1.1` |
| UniFi username | API user | `customapi` |
| UniFi password | | |
| UniFi site | Usually default | `default` |
| Hermes/NPM IP | Reverse proxy IP | `172.16.250.9` |
| Reverse subnets | For PTR records | `172.16.250,192.168.1` |

---

## UniFi Sync

The sync script (`/usr/local/bin/unifi-zeus-sync.py`) automatically:
- Reads all DHCP clients from UniFi
- Creates A records in the appropriate zone
- Creates PTR records for reverse lookups
- Removes stale records for devices no longer present

**Log:** `/var/log/unifi-zeus-sync.log`  
**Config:** `/etc/unifi-zeus-sync.conf`  
**State:** `/var/lib/unifi-zeus-sync/state.json`

---

## Integration

For HTTPS access to internal servers with valid SSL, use with the [Nginx Proxy Manager installer](../npm-reverse-proxy/).

See the [Master User Manual](../docs/dns-npm-infrastructure-manual.md) for complete documentation.

---
*Van Auken Tech · Thomas Van Auken*
