# Technitium DNS Server — Installation Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 2.0.0  
> Tested on: Ubuntu 22.04+, Debian 12+, Proxmox VE 8.x/9.x

---

## Scripts Available

### 1. Full Installation Script (Recommended)
**Script:** [`technitium-dns-install.sh`](technitium-dns-install.sh)

Installs Technitium DNS Server from scratch on any Debian-based system.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

**Features:**
- Installs Technitium DNS Server from official source
- Auto-detects OS and adapts accordingly
- Creates admin account via API
- Configures recursion and upstream forwarders
- Creates primary zone + VLAN sub-zones + backend zones
- Creates reverse DNS zones
- Enables RFC 2136 dynamic updates
- Configures firewall (UFW/firewalld)

### 2. Post-Install Configuration Script
**Script:** [`dns-server-install.sh`](dns-server-install.sh)

For use when Technitium is already installed (e.g., via community-scripts.org).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

---

## Zone Structure

The full installer creates a hierarchical zone structure for UniFi integration:

```
home.vanauken.tech              (primary zone)
├── dmz.home.vanauken.tech      (VLAN zone)
├── pro.home.vanauken.tech      (VLAN zone)
├── storage.home.vanauken.tech  (VLAN zone)
├── backend.home.vanauken.tech  (for SSL proxy)
└── backend.dmz.home.vanauken.tech
```

**Backend zones** store real server IPs while public zones point to the proxy.

---

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| DNS Server IP | This server's IP | `172.16.250.8` |
| Admin username | Technitium admin | `admin` |
| Admin password | Min 8 characters | (secure) |
| Primary domain | Internal DNS zone | `home.vanauken.tech` |
| VLAN names | Comma-separated | `dmz,pro,storage,mgmt` |
| Backend zones | For SSL proxy | Yes/No |
| Forwarders | Upstream DNS | `1.1.1.1,9.9.9.9` |
| RFC 2136 | Dynamic updates | Yes/No |

---

## Integration

For HTTPS access to internal servers, use with the [Nginx Proxy Manager installer](../npm-reverse-proxy/).

---
*Van Auken Tech · Thomas Van Auken*