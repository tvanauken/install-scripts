# DNS & Reverse Proxy Infrastructure — Master User Manual

> **Created by:** Thomas Van Auken — Van Auken Tech
> **Version:** 3.0.0
> **Date:** 2026-04-05
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Deployment Order](#4-deployment-order)
5. [DNS Server Installation](#5-dns-server-installation)
6. [Reverse Proxy Installation](#6-reverse-proxy-installation)
7. [How the System Works](#7-how-the-system-works)
8. [Adding Services to NPM](#8-adding-services-to-npm)
9. [Internal DNS Records](#9-internal-dns-records)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This manual covers deploying internal DNS and reverse proxy infrastructure for UniFi-based networks:

- **Internal DNS (Zeus)** — Technitium DNS with UniFi sync, root hints, DNSSEC
- **Reverse Proxy (Hermes)** — NPM with wildcard SSL certificate

Both can be deployed together or separately.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        UniFi Controller                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │ Survey networks
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DNS Server (Zeus)                            │
│  • Root hints recursion (no external forwarders)                 │
│  • DNSSEC validation, QNAME minimization                         │
│  • Dynamic zones from UniFi networks                             │
│  • Auto-sync DHCP clients every 5 min                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  Reverse Proxy (Hermes)                          │
│  • Native NPM installation (no Docker)                           │
│  • Wildcard Let's Encrypt certificate                            │
│  • Proxy hosts configured via Web UI                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Prerequisites

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| DNS Server | 1 vCPU | 512 MB | 4 GB |
| Reverse Proxy | 2 vCPU | 2 GB | 8 GB |

- Debian 12+ or Ubuntu 22.04+
- UniFi Controller with API access
- Cloudflare account for wildcard SSL

---

## 4. Deployment Order

1. **DNS Server first** — Creates zones, starts sync
2. **Reverse Proxy second**

---

## 5. DNS Server Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

### What It Does

- Installs Technitium DNS
- Surveys UniFi Controller, discovers networks
- Creates DNS zones for each network
- Root hints recursion (no external forwarders)
- Deploys `unifi-zeus-sync.py` for automatic A/PTR records

### Post-Installation

- Web UI: `http://<DNS-IP>:5380`
- Sync log: `/var/log/unifi-zeus-sync.log`

---

## 6. Reverse Proxy Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

### What It Does

- Installs OpenResty + NPM natively
- Requests wildcard SSL certificate via Cloudflare
- Imports certificate to NPM
- Auto-renewal configured

### Post-Installation

- Web UI: `http://<NPM-IP>:81`

---

## 7. How the System Works

### Internal DNS (Zeus)

- Resolves internal hostnames for devices on your network
- Auto-syncs DHCP clients from UniFi as A/PTR records
- Uses root hints for external resolution (privacy-first)

### Reverse Proxy (Hermes)

- Receives external HTTPS requests
- Routes to internal services based on configured proxy hosts
- Provides valid SSL via wildcard certificate

### External Access Flow

1. User requests `https://proxmox.home.example.com`
2. Public DNS resolves to NPM's public IP
3. NPM matches hostname to configured proxy host
4. Wildcard certificate validates the connection
5. Request proxied to backend server

---

## 8. Adding Services to NPM

To publish an internal service externally:

### In NPM Web UI

1. Go to **Hosts** → **Proxy Hosts** → **Add**
2. **Domain Names:** `anyname.home.example.com`
3. **Forward Hostname/IP:** internal server IP
4. **Forward Port:** service port
5. **SSL tab:** Select wildcard certificate, enable Force SSL
6. **Save**

### In Public DNS (Cloudflare)

Create an A record:
```
anyname.home.example.com  A  <NPM-PUBLIC-IP>
```

### Example: Proxmox

| NPM Setting | Value |
|-------------|-------|
| Domain Names | `proxmox.home.example.com` |
| Forward Hostname/IP | `172.16.250.10` |
| Forward Port | `8006` |
| Scheme | `https` |
| SSL Certificate | Wildcard |

Public DNS: `proxmox.home.example.com A <public-ip>`

Result: `https://proxmox.home.example.com` works with valid SSL.

---

## 9. Internal DNS Records

### Auto-Created by Sync

DHCP clients are automatically added:
- `hostname.vlan.domain` A records
- PTR records for reverse lookups

### Manual Records

For static devices, add A records in Technitium Web UI.

---

## 10. Maintenance

### DNS Server

```bash
tail -f /var/log/unifi-zeus-sync.log
systemctl restart dns
```

### Reverse Proxy

```bash
systemctl restart openresty npm
certbot renew
```

### Backups

```bash
# DNS
tar czf dns-backup.tar.gz /etc/dns /etc/unifi-zeus-sync.conf

# NPM
tar czf npm-backup.tar.gz /data /etc/ssl /etc/letsencrypt
```

---

## 11. Troubleshooting

### DNS Not Resolving

1. `systemctl status dns`
2. `dig @<DNS-IP> example.com`

### 502 Bad Gateway

1. Check proxy host config in NPM
2. Verify backend is running and reachable

### SSL Certificate Errors

1. Check certificate in NPM → SSL Certificates
2. `certbot renew` if expired

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
