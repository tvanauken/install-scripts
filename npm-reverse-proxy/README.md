# Nginx Proxy Manager — Installation Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 3.0.0  
> Tested on: Ubuntu 22.04+, Debian 12+, Proxmox VE 8.x/9.x

---

## Version History

| Version | Date | Changes |
|---------|------|------|
| 3.0.0 | 2026-04-05 | Native install (no Docker), Lua SRV resolver, dynamic backend routing |
| 2.0.0 | 2026-04-05 | Wildcard SSL, SRV-based routing |
| 1.1.0 | 2026-03-31 | Initial release (deprecated) |

---

## Scripts Available

### 1. Full Installation Script (Recommended)
**Script:** [`nginx-proxy-manager-install.sh`](nginx-proxy-manager-install.sh)

Installs NPM natively (no Docker) with dynamic SSL proxy configuration.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

**Features:**
- **Native installation** using OpenResty (no Docker)
- Installs Node.js and NPM from source
- Requests wildcard Let's Encrypt certificate (Cloudflare DNS challenge)
- **Lua SRV resolver** for dynamic backend routing
- Auto-protocol detection (HTTP/HTTPS)
- Routes HTTPS requests to backends via SRV records
- Configures firewall (UFW/firewalld)

### 2. Post-Install Configuration Script
**Script:** [`npm-reverse-proxy-install.sh`](npm-reverse-proxy-install.sh)

For use when NPM is already installed (e.g., via community-scripts.org).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

---

## How the Dynamic SSL Proxy Works

1. Browser requests `https://server.vlan.home.example.com`
2. DNS returns the proxy server's IP (not the real server)
3. Wildcard certificate validates the connection
4. Lua script queries SRV record: `_https._tcp.server.vlan.home.example.com`
5. SRV record returns backend target and port
6. Request is proxied to the real server with valid SSL

**Result:** Any internal server gets valid HTTPS without individual certificates or manual NPM configuration.

---

## Required DNS Records (per server)

| Record Type | Name | Value |
|-------------|------|-------|
| A Record | `server.vlan.domain.tld` | Proxy IP (e.g., `172.16.250.9`) |
| Backend A | `server.backend.vlan.domain.tld` | Real server IP |
| SRV Record | `_https._tcp.server.vlan.domain.tld` | `0 0 PORT backend-target` |

---

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| Server IP | This server's IP | `172.16.250.9` |
| Admin email | NPM login email | `admin@example.com` |
| Admin password | Min 8 characters | (secure) |
| Wildcard domain | For SSL cert | `home.example.com` |
| Cloudflare API token | Zone:DNS:Edit | (token) |
| DNS Server IP | For SRV lookups | `172.16.250.8` |

---

## File Locations

| File | Purpose |
|------|--------|
| `/data/nginx/custom/srv_resolver.lua` | Lua SRV resolver module |
| `/data/nginx/custom/http.conf` | Custom nginx config |
| `/etc/ssl/<domain>/fullchain.pem` | Wildcard certificate |
| `/data/logs/dynamic_proxy_*.log` | Proxy access/error logs |

---

## Integration

Use with the [Technitium DNS installer](../dns-server/) for complete split-horizon DNS + SSL proxy.

See the [Master User Manual](../docs/dns-npm-infrastructure-manual.md) for complete documentation.

---
*Van Auken Tech · Thomas Van Auken*
