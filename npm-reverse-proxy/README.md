# Nginx Proxy Manager — Installation Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 2.0.0  
> Tested on: Ubuntu 22.04+, Debian 12+, Proxmox VE 8.x/9.x

---

## Scripts Available

### 1. Full Installation Script (Recommended)
**Script:** [`nginx-proxy-manager-install.sh`](nginx-proxy-manager-install.sh)

Installs NPM from scratch with dynamic SSL proxy configuration.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

**Features:**
- Installs Docker and NPM container
- Creates admin account via API
- Requests wildcard Let's Encrypt certificate (Cloudflare DNS challenge)
- Configures dynamic SSL proxy with Lua SRV resolver
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

1. Browser requests `https://server.vlan.home.vanauken.tech`
2. DNS returns the proxy server's IP (not the real server)
3. Wildcard certificate validates the connection
4. Lua script queries SRV record for backend target + port
5. Request is proxied to the real server with valid SSL

**Result:** Any internal server gets valid HTTPS without individual certificates.

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
| Install method | Docker or native | Docker |
| Admin email | NPM login email | `admin@domain.com` |
| Admin password | Min 8 characters | (secure) |
| Wildcard domain | For SSL cert | `home.vanauken.tech` |
| DNS provider | For DNS challenge | Cloudflare |
| CF API token | Zone:DNS:Edit | (token) |
| Internal DNS | For SRV lookups | `172.16.250.8` |

---

## Integration

Use with the [Technitium DNS installer](../dns-server/) for complete split-horizon DNS + SSL proxy.

---
*Van Auken Tech · Thomas Van Auken*