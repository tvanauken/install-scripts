# Nginx Proxy Manager — User Manual

> **Created by:** Thomas Van Auken — Van Auken Tech
> **Version:** 3.0.0
> **Date:** 2026-04-05
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Version History

| Version | Date | Changes |
|---------|------|------|
| 3.0.0 | 2026-04-05 | Native install (no Docker), Lua SRV resolver, dynamic backend routing |
| 2.0.0 | 2026-04-05 | Wildcard SSL, SRV-based routing |
| 1.1.0 | 2026-03-31 | Initial release (deprecated) |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [Configuration Prompts](#5-configuration-prompts)
6. [What Gets Installed](#6-what-gets-installed)
7. [How Dynamic Proxy Works](#7-how-dynamic-proxy-works)
8. [DNS Record Setup](#8-dns-record-setup)
9. [Web Interface](#9-web-interface)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This script installs Nginx Proxy Manager **natively** (no Docker) with a Lua-based dynamic proxy system. Once configured, any service can be accessed via HTTPS with valid SSL certificates simply by creating DNS records — no manual NPM configuration required.

**Key Design Principle:** This is a **native installation** using OpenResty. No Docker containers are used. The system uses a Lua script to resolve SRV records and dynamically route requests to backend services.

---

## 2. Features

### Native Installation
- OpenResty (nginx + Lua)
- Node.js + NPM from source
- No Docker dependency

### Dynamic SSL Proxy
- Wildcard Let's Encrypt certificate
- Automatic renewal via certbot
- Cloudflare DNS challenge for validation

### Lua SRV Resolver
- Queries DNS for SRV records
- Extracts backend target and port
- Auto-protocol detection (HTTP/HTTPS)
- No manual proxy host configuration needed

### Zero-Config Service Discovery
- Add DNS records only
- Proxy routes automatically
- Works with any internal service

---

## 3. Prerequisites

### Hardware Requirements
- CPU: 2 vCPU minimum
- RAM: 2 GB minimum
- Disk: 8 GB minimum

### Software Requirements
- Debian 12+ or Ubuntu 22.04+
- Root/sudo access
- Network connectivity

### External Requirements
- Cloudflare account with domain
- Cloudflare API Token (Zone:DNS:Edit)
- Internal DNS server (for SRV lookups)

### Network Requirements
- Static IP address for this server
- Firewall rules allowing:
  - TCP 80 (HTTP)
  - TCP 443 (HTTPS)
  - TCP 81 (NPM Web UI)

---

## 4. Installation

### One-Liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

### Manual Download

```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh -o npm-install.sh
chmod +x npm-install.sh
sudo ./npm-install.sh
```

---

## 5. Configuration Prompts

The installer prompts for the following information:

| Prompt | Description | Example |
|--------|-------------|------|
| NPM Server IP | Static IP of this server | `172.16.250.9` |
| Admin email | NPM login and cert contact | `admin@example.com` |
| Admin password | Minimum 8 characters | (secure password) |
| Wildcard domain | Without the `*` | `home.example.com` |
| DNS Server IP | Your internal DNS | `172.16.250.8` |
| Cloudflare API Token | For DNS challenge | (from Cloudflare) |

---

## 6. What Gets Installed

### Software
- OpenResty (nginx with Lua support)
- Node.js 18.x LTS
- Nginx Proxy Manager
- Certbot with Cloudflare plugin
- Python 3

### Files Created

| Path | Purpose |
|------|------|
| `/usr/local/openresty/` | OpenResty installation |
| `/data/nginx/custom/srv_resolver.lua` | Lua SRV resolver module |
| `/data/nginx/custom/http.conf` | Custom nginx config |
| `/etc/ssl/<domain>/fullchain.pem` | Wildcard certificate |
| `/etc/ssl/<domain>/privkey.pem` | Private key |
| `/data/logs/dynamic_proxy_*.log` | Proxy logs |
| `/etc/letsencrypt/` | Certbot configuration |

### Services
- `openresty` — Web server
- `npm` — NPM backend

### Cron Jobs
```
0 0,12 * * * certbot renew --quiet
```

---

## 7. How Dynamic Proxy Works

### Request Flow

```
Browser → DNS → Hermes IP → Lua Resolver → Backend Service
```

1. **Browser** requests `https://service.vlan.domain.com`
2. **DNS** returns Hermes (proxy) IP address
3. **Browser** connects to Hermes with HTTPS
4. **Wildcard certificate** validates the connection
5. **Lua script** extracts hostname from request
6. **Lua script** queries SRV record: `_https._tcp.service.vlan.domain.com`
7. **SRV record** returns backend target + port
8. **Lua script** queries A record for backend IP
9. **Request** proxied to actual backend

### Protocol Detection

The Lua resolver checks if the port is in the HTTP ports list:
- Ports 80, 8080, 8000, 3000 → HTTP
- All other ports → HTTPS

This can be customized in `/data/nginx/custom/srv_resolver.lua`.

### Fallback Behavior

If no SRV record exists, the request returns 502 Bad Gateway.

---

## 8. DNS Record Setup

### Records Required Per Service

| Record Type | Name | Value |
|-------------|------|------|
| A | `service.vlan.domain` | Hermes IP |
| A | `service.backend.vlan.domain` | Actual server IP |
| SRV | `_https._tcp.service.vlan.domain` | `0 0 PORT service.backend.vlan.domain` |

### Example: Proxmox Web UI

Proxmox runs on port 8006 at `172.16.250.10`.

**DNS Records:**
```
proxmox.mgmt.home.example.com           A     172.16.250.9
proxmox.backend.mgmt.home.example.com   A     172.16.250.10
_https._tcp.proxmox.mgmt.home.example.com SRV 0 0 8006 proxmox.backend.mgmt.home.example.com
```

**Result:** `https://proxmox.mgmt.home.example.com` works with valid SSL.

### Example: HTTP Service (Grafana on port 3000)

**DNS Records:**
```
grafana.mgmt.home.example.com           A     172.16.250.9
grafana.backend.mgmt.home.example.com   A     172.16.250.20
_https._tcp.grafana.mgmt.home.example.com SRV 0 0 3000 grafana.backend.mgmt.home.example.com
```

Port 3000 is in the HTTP ports list, so backend connection uses HTTP.

---

## 9. Web Interface

### Access
Open `http://<NPM-IP>:81` in a browser.

**Default credentials:**
- Email: (configured during install)
- Password: (configured during install)

### Key Sections

The NPM web interface is optional for the dynamic proxy system but useful for:
- Viewing access logs
- Managing static proxy hosts (if needed)
- Viewing SSL certificate status

**Note:** The dynamic proxy system bypasses NPM's proxy host configuration. Services are routed based on DNS SRV records, not NPM settings.

---

## 10. Maintenance

### Service Management

```bash
# OpenResty status
systemctl status openresty

# NPM status
systemctl status npm

# Restart all
systemctl restart openresty npm

# Test nginx config
/usr/local/openresty/nginx/sbin/nginx -t
```

### Certificate Renewal

Certbot handles automatic renewal. To manually renew:

```bash
certbot renew
```

To check certificate expiry:

```bash
openssl x509 -in /etc/ssl/home.example.com/fullchain.pem -noout -dates
```

### View Logs

```bash
# Dynamic proxy access
tail -f /data/logs/dynamic_proxy_access.log

# Dynamic proxy errors
tail -f /data/logs/dynamic_proxy_error.log

# OpenResty error log
tail -f /usr/local/openresty/nginx/logs/error.log
```

### Backup

```bash
# Full backup
tar czf npm-backup-$(date +%Y%m%d).tar.gz \
  /data \
  /etc/ssl \
  /etc/letsencrypt
```

### Restore

```bash
# Stop services
systemctl stop openresty npm

# Extract backup
tar xzf npm-backup-YYYYMMDD.tar.gz -C /

# Restart
systemctl start openresty npm
```

---

## 11. Troubleshooting

### 502 Bad Gateway

1. Check SRV record exists:
   ```bash
   dig SRV _https._tcp.service.vlan.domain @DNS-IP
   ```

2. Check backend A record exists:
   ```bash
   dig A service.backend.vlan.domain @DNS-IP
   ```

3. Verify backend service is running:
   ```bash
   curl -k https://BACKEND-IP:PORT
   ```

4. Check Lua error log:
   ```bash
   tail -50 /data/logs/dynamic_proxy_error.log
   ```

### SSL Certificate Errors

1. Check certificate exists:
   ```bash
   ls -la /etc/ssl/home.example.com/
   ```

2. Check certificate validity:
   ```bash
   openssl x509 -in /etc/ssl/home.example.com/fullchain.pem -noout -dates
   ```

3. Renew if expired:
   ```bash
   certbot renew --force-renewal
   ```

4. Restart nginx:
   ```bash
   systemctl restart openresty
   ```

### Service Not Proxied (Direct Connection)

This means the A record points to the actual server, not Hermes.

1. Check A record:
   ```bash
   dig A service.vlan.domain @DNS-IP
   ```

2. Should return Hermes IP, not backend IP

### Wrong Protocol (HTTPS to HTTP service)

If connecting to an HTTP-only service via HTTPS backend:

1. Edit `/data/nginx/custom/srv_resolver.lua`
2. Add port to `http_ports` table:
   ```lua
   local http_ports = {
       [80] = true,
       [8080] = true,
       [3000] = true,
       [YOUR_PORT] = true,  -- Add here
   }
   ```
3. Reload nginx:
   ```bash
   systemctl reload openresty
   ```

### NPM Web UI Not Loading

1. Check npm service:
   ```bash
   systemctl status npm
   ```

2. Check port 81:
   ```bash
   ss -tuln | grep :81
   ```

3. Check firewall:
   ```bash
   ufw allow 81/tcp
   ```

### Nginx Config Test Fails

```bash
# Test config
/usr/local/openresty/nginx/sbin/nginx -t

# Check for syntax errors in custom config
cat /data/nginx/custom/http.conf

# Check Lua syntax
luajit -bl /data/nginx/custom/srv_resolver.lua
```

---

## Integration

This proxy server is designed to work with the [Technitium DNS installer](../../dns-server/). Deploy DNS first, then the proxy.

See the [Master User Manual](../../docs/dns-npm-infrastructure-manual.md) for complete pair deployment documentation.

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
