# DNS & Reverse Proxy Infrastructure — Master User Manual

> **Created by:** Thomas Van Auken — Van Auken Tech
> **Version:** 3.0.0
> **Date:** 2026-04-05
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | 2026-04-05 | Complete rewrite: UniFi survey, dynamic zone building, root hints, native NPM |
| 2.0.0 | 2026-04-05 | Added root hints, DNSSEC, hagezi blocklists |
| 1.1.0 | 2026-03-31 | Initial release with forwarders (deprecated) |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Deployment Order](#4-deployment-order)
5. [DNS Server Installation](#5-dns-server-installation)
6. [Reverse Proxy Installation](#6-reverse-proxy-installation)
7. [How the System Works](#7-how-the-system-works)
8. [DNS Record Structure](#8-dns-record-structure)
9. [Adding New Services](#9-adding-new-services)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This manual covers deploying a complete internal DNS and reverse proxy infrastructure for UniFi-based networks. The system provides:

- **Split-horizon DNS** with automatic VLAN zone discovery
- **Privacy-first resolution** using root hints (no external DNS forwarders)
- **Automatic DNS record sync** from UniFi DHCP clients
- **Dynamic SSL proxy** with wildcard certificates
- **SRV-based backend routing** for zero-config service discovery

Both scripts can be deployed together as an integrated solution or separately.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        UniFi Controller                          │
│                    (Network Discovery Source)                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ Survey networks
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DNS Server (Zeus)                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Technitium DNS                                           │   │
│  │ • Root hints recursion (no external forwarders)          │   │
│  │ • DNSSEC validation                                      │   │
│  │ • QNAME minimization                                     │   │
│  │ • Hagezi ad blocking                                     │   │
│  │ • Dynamic zones from UniFi networks                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ unifi-zeus-sync.py (cron every 5 min)                   │   │
│  │ • Reads UniFi DHCP clients                               │   │
│  │ • Creates A + PTR records automatically                  │   │
│  │ • Removes stale records                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │ DNS queries
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Reverse Proxy (Hermes)                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ OpenResty + Nginx Proxy Manager                          │   │
│  │ • Native installation (no Docker)                        │   │
│  │ • Wildcard Let's Encrypt certificate                     │   │
│  │ • Lua SRV resolver for dynamic backend routing           │   │
│  │ • Auto-protocol detection (HTTP/HTTPS)                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Prerequisites

### Hardware/VM Requirements

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| DNS Server | 1 vCPU | 512 MB | 4 GB |
| Reverse Proxy | 2 vCPU | 2 GB | 8 GB |

### Software Requirements

- Debian 12+ or Ubuntu 22.04+ (both servers)
- UniFi Controller with API access
- Cloudflare account (for wildcard SSL certificate)
- Root/sudo access

### Network Requirements

- Static IP for DNS server
- Static IP for reverse proxy
- DNS server reachable from all VLANs
- Reverse proxy reachable from WAN (if external access needed)

---

## 4. Deployment Order

**Deploy in this order:**

1. **DNS Server first** — Creates zones, starts sync
2. **Reverse Proxy second** — Requires DNS for backend resolution

---

## 5. DNS Server Installation

### One-Liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

### What It Does

1. Installs Technitium DNS Server
2. Connects to UniFi Controller and discovers all networks
3. Creates DNS zones for each network (e.g., `mgmt.home.example.com`, `iot.home.example.com`)
4. Creates backend zones for reverse proxy integration
5. Configures root hints recursion (no external forwarders)
6. Enables DNSSEC validation and QNAME minimization
7. Deploys `unifi-zeus-sync.py` with discovered network mappings
8. Sets up cron job for automatic sync every 5 minutes

### Configuration Prompts

| Prompt | Description | Example |
|--------|-------------|---------|
| DNS Server IP | IP address of this server | `172.16.250.8` |
| Admin username | Technitium admin account | `admin` |
| Admin password | Minimum 8 characters | |
| Base domain | Your internal domain | `home.example.com` |
| UniFi Controller URL | Full URL with protocol | `https://192.168.1.1` |
| UniFi username | API-capable user | `customapi` |
| UniFi password | | |
| UniFi site | Usually `default` | `default` |
| Hermes/NPM IP | Reverse proxy IP (optional) | `172.16.250.9` |
| Reverse subnets | For PTR records | `172.16.250,192.168.1` |

### Post-Installation

- Web UI: `http://<DNS-IP>:5380`
- Sync log: `/var/log/unifi-zeus-sync.log`
- Config: `/etc/unifi-zeus-sync.conf`

---

## 6. Reverse Proxy Installation

### One-Liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

### What It Does

1. Installs OpenResty (nginx with Lua support)
2. Installs Nginx Proxy Manager natively (no Docker)
3. Requests wildcard SSL certificate via Cloudflare DNS challenge
4. Deploys Lua SRV resolver for dynamic backend routing
5. Configures catch-all server for `*.yourdomain.com`
6. Sets up auto-renewal for SSL certificate

### Configuration Prompts

| Prompt | Description | Example |
|--------|-------------|---------|
| NPM Server IP | IP address of this server | `172.16.250.9` |
| Admin email | NPM login and cert contact | `admin@example.com` |
| Admin password | Minimum 8 characters | |
| Wildcard domain | Without the `*` | `home.example.com` |
| DNS Server IP | Your DNS server | `172.16.250.8` |
| Cloudflare API Token | For DNS challenge | (from Cloudflare dashboard) |

### Post-Installation

- Web UI: `http://<NPM-IP>:81`
- Certificate: `/etc/ssl/<domain>/fullchain.pem`
- Custom config: `/data/nginx/custom/http.conf`
- Lua resolver: `/data/nginx/custom/srv_resolver.lua`

---

## 7. How the System Works

### DNS Resolution Flow

1. Client requests `server.vlan.home.example.com`
2. DNS server returns the **reverse proxy IP** (not the actual server)
3. Client connects to reverse proxy with valid SSL

### Reverse Proxy Flow

1. Reverse proxy receives HTTPS request for `server.vlan.home.example.com`
2. Wildcard certificate validates the connection
3. Lua script queries DNS for SRV record: `_https._tcp.server.vlan.home.example.com`
4. SRV record returns backend target and port
5. Lua script queries A record for backend target
6. Request proxied to actual server IP:port

### UniFi Sync Flow

1. Every 5 minutes, sync script runs
2. Queries UniFi for all active DHCP clients
3. For each client with a name/hostname:
   - Determines zone from network_id mapping
   - Creates/updates A record
   - Creates/updates PTR record
4. Removes records for clients no longer present

---

## 8. DNS Record Structure

### For Each Service

| Record Type | Name | Value |
|-------------|------|-------|
| A | `service.vlan.domain` | Reverse proxy IP |
| A | `service.backend.vlan.domain` | Actual server IP |
| SRV | `_https._tcp.service.vlan.domain` | `0 0 PORT service.backend.vlan.domain` |

### Example: Proxmox Server

```
proxmox.mgmt.home.example.com        A     172.16.250.9  (Hermes)
proxmox.backend.mgmt.home.example.com A    172.16.250.10 (actual Proxmox)
_https._tcp.proxmox.mgmt.home.example.com SRV 0 0 8006 proxmox.backend.mgmt.home.example.com
```

### Auto-Created by Sync

The sync script automatically creates:
- `hostname.vlan.domain` A records pointing to actual device IPs

These are for direct access. For proxied access, manually add the backend A and SRV records.

---

## 9. Adding New Services

### For Proxied Access (with valid SSL)

1. **In DNS (Technitium Web UI):**
   - Create A record: `service.vlan.domain` → Hermes IP
   - Create A record: `service.backend.vlan.domain` → Actual server IP
   - Create SRV record: `_https._tcp.service.vlan.domain` → `0 0 PORT service.backend.vlan.domain`

2. **No NPM configuration needed** — the Lua resolver handles it automatically

### For Direct Access (no proxy)

The sync script handles this automatically for DHCP clients. For static devices:

1. **In DNS:** Create A record: `service.vlan.domain` → Actual server IP

---

## 10. Maintenance

### DNS Server

```bash
# View sync log
tail -f /var/log/unifi-zeus-sync.log

# Manual sync run
python3 /usr/local/bin/unifi-zeus-sync.py

# Restart DNS service
systemctl restart dns

# View DNS query log
# (via Technitium Web UI → Logs)
```

### Reverse Proxy

```bash
# View proxy logs
tail -f /data/logs/dynamic_proxy_access.log
tail -f /data/logs/dynamic_proxy_error.log

# Restart services
systemctl restart openresty
systemctl restart npm

# Test nginx config
/usr/local/openresty/nginx/sbin/nginx -t

# Renew certificate manually
certbot renew
```

### Backups

```bash
# DNS server
tar czf dns-backup-$(date +%Y%m%d).tar.gz /etc/dns /etc/unifi-zeus-sync.conf /var/lib/unifi-zeus-sync

# Reverse proxy
tar czf npm-backup-$(date +%Y%m%d).tar.gz /data /etc/ssl/<domain>
```

---

## 11. Troubleshooting

### DNS Not Resolving

1. Check DNS service: `systemctl status dns`
2. Test query: `dig @<DNS-IP> example.com`
3. Check zone exists in Technitium Web UI
4. Root hints may be slow on first query (cache warming)

### Sync Not Working

1. Check log: `tail -f /var/log/unifi-zeus-sync.log`
2. Verify UniFi credentials in `/etc/unifi-zeus-sync.conf`
3. Test UniFi API manually
4. Check cron: `crontab -l | grep sync`

### SSL Certificate Issues

1. Verify certificate exists: `ls -la /etc/ssl/<domain>/`
2. Check certbot log: `cat /var/log/letsencrypt/letsencrypt.log`
3. Verify Cloudflare API token permissions
4. Test DNS propagation: `dig TXT _acme-challenge.<domain>`

### 502 Bad Gateway

1. Check SRV record exists: `dig SRV _https._tcp.<hostname>`
2. Check backend A record exists
3. Verify backend service is running
4. Check Lua error log: `tail -f /data/logs/dynamic_proxy_error.log`

### Service Not Proxied

1. Confirm A record points to Hermes (not actual server)
2. Confirm SRV record exists with correct port
3. Confirm backend A record points to actual server
4. Check port is in http_ports list if using HTTP (not HTTPS)

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
