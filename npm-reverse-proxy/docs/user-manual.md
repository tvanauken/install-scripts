# Nginx Proxy Manager — User Manual

> **Created by:** Thomas Van Auken — Van Auken Tech
> **Version:** 3.0.0
> **Date:** 2026-04-05
> **Repository:** https://github.com/tvanauken/install-scripts

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [Configuration Prompts](#5-configuration-prompts)
6. [What Gets Installed](#6-what-gets-installed)
7. [Adding Proxy Hosts](#7-adding-proxy-hosts)
8. [DNS Setup](#8-dns-setup)
9. [Web Interface](#9-web-interface)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This script installs Nginx Proxy Manager **natively** (no Docker) with a wildcard SSL certificate. After installation, you configure proxy hosts through the NPM web interface to route external traffic to internal services with valid HTTPS.

---

## 2. Features

- **Native installation** using OpenResty (no Docker)
- Wildcard Let's Encrypt certificate via Cloudflare DNS challenge
- Certificate auto-imported to NPM
- Automatic certificate renewal
- Web UI for managing proxy hosts

---

## 3. Prerequisites

### Hardware Requirements
- CPU: 2 vCPU minimum
- RAM: 2 GB minimum
- Disk: 8 GB minimum

### Software Requirements
- Debian 12+ or Ubuntu 22.04+
- Root/sudo access

### External Requirements
- Cloudflare account with your domain
- Cloudflare API Token (Zone:DNS:Edit permission)

### Network Requirements
- Static IP address
- Ports 80, 443, 81 accessible

---

## 4. Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

---

## 5. Configuration Prompts

| Prompt | Description | Example |
|--------|-------------|------|
| Server IP | This server's IP | `172.16.250.9` |
| Admin email | NPM login | `admin@example.com` |
| Admin password | Min 8 characters | |
| Wildcard domain | Without the `*` | `home.example.com` |
| Cloudflare API Token | For DNS challenge | (from Cloudflare) |

---

## 6. What Gets Installed

- OpenResty (nginx)
- Node.js + Nginx Proxy Manager
- Certbot with Cloudflare plugin
- Wildcard certificate for `*.yourdomain.com`

### Services
- `openresty` — Web server
- `npm` — NPM backend

---

## 7. Adding Proxy Hosts

This is how you publish internal services to the outside world.

### Step-by-Step

1. Open NPM Web UI: `http://<NPM-IP>:81`
2. Log in with your admin credentials
3. Go to **Hosts** → **Proxy Hosts** → **Add Proxy Host**
4. **Details tab:**
   - **Domain Names:** `anyname.home.example.com`
   - **Scheme:** `http` or `https` (to the backend)
   - **Forward Hostname/IP:** backend server IP (e.g., `192.168.1.50`)
   - **Forward Port:** backend service port (e.g., `8006`)
   - Enable **Block Common Exploits**
   - Enable **Websockets Support** if needed
5. **SSL tab:**
   - Select `Wildcard home.example.com` certificate
   - Enable **Force SSL**
   - Enable **HTTP/2 Support**
6. Click **Save**

### Example: Proxmox

| Setting | Value |
|---------|-------|
| Domain Names | `proxmox.home.example.com` |
| Scheme | `https` |
| Forward Hostname/IP | `192.168.1.50` |
| Forward Port | `8006` |
| SSL Certificate | `Wildcard home.example.com` |

Now `https://proxmox.home.example.com` works with valid SSL.

---

## 8. DNS Setup

For each service you proxy, create a public DNS A record:

```
proxmox.home.example.com  A  <NPM-PUBLIC-IP>
grafana.home.example.com  A  <NPM-PUBLIC-IP>
```

The wildcard certificate covers all `*.home.example.com` subdomains.

---

## 9. Web Interface

### Access
`http://<NPM-IP>:81`

### Key Sections
- **Hosts → Proxy Hosts:** Add/edit/delete proxy configurations
- **SSL Certificates:** View and manage certificates
- **Access Lists:** IP-based access control
- **Audit Log:** Activity history

---

## 10. Maintenance

### Service Management

```bash
systemctl status openresty npm
systemctl restart openresty npm
```

### Certificate Renewal

Automatic via cron. Manual renewal:

```bash
certbot renew
```

### Backup

```bash
tar czf npm-backup-$(date +%Y%m%d).tar.gz /data /etc/ssl /etc/letsencrypt
```

---

## 11. Troubleshooting

### 502 Bad Gateway

1. Verify backend service is running
2. Check backend IP/port in proxy host config
3. Confirm NPM can reach backend (network/firewall)

### SSL Certificate Errors

1. Check certificate in NPM → SSL Certificates
2. Verify correct certificate assigned to proxy host
3. Renew if expired: `certbot renew`

### NPM Web UI Not Loading

```bash
systemctl status npm
ss -tuln | grep :81
```

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
