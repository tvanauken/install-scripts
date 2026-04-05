# Nginx Proxy Manager — User Manual

> **Van Auken Tech — Install Scripts Collection**  
> Created by: Thomas Van Auken — Van Auken Tech  
> Document Version: 2.0.0  
> Last Updated: April 2026

---

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Pre-Installation Checklist](#pre-installation-checklist)
4. [Installation](#installation)
5. [Configuration Walkthrough](#configuration-walkthrough)
6. [Post-Installation Verification](#post-installation-verification)
7. [Understanding the Dynamic SSL Proxy](#understanding-the-dynamic-ssl-proxy)
8. [Adding New Servers](#adding-new-servers)
9. [Certificate Management](#certificate-management)
10. [Maintenance & Administration](#maintenance--administration)
11. [Troubleshooting](#troubleshooting)
12. [Security Considerations](#security-considerations)
13. [Appendix](#appendix)

---

## Overview

### What This Script Does

The Nginx Proxy Manager installer deploys a complete reverse proxy solution with a dynamic SSL proxy capability. Unlike traditional reverse proxies that require manual configuration for each backend server, this implementation uses DNS SRV records to automatically route HTTPS requests to the correct backend—providing valid SSL certificates for any internal service without individual certificate management.

### Key Features

- **Docker Deployment**: Runs NPM in a container for isolation and easy updates
- **Wildcard SSL Certificate**: Single Let's Encrypt wildcard cert covers all subdomains
- **Dynamic Backend Resolution**: Lua script resolves backends via DNS SRV records at runtime
- **API-Driven Setup**: Admin account and certificate created programmatically
- **Cloudflare DNS Challenge**: Automated certificate issuance without exposing port 80
- **WebSocket Support**: Full proxy support for WebSocket connections

### The Problem This Solves

**Traditional Approach (Manual):**
- Deploy a service on `server.local:8080`
- Access via browser shows "Not Secure" warning
- Create individual Let's Encrypt certificate (if even possible internally)
- Configure NPM proxy host manually
- Repeat for every single service

**Dynamic SSL Proxy Approach (Automated):**
- Deploy a service anywhere on any port
- Add 3 DNS records (A, Backend A, SRV)
- Access via `https://server.vlan.home.vanauken.tech` with valid SSL
- No NPM configuration needed—routing is automatic

---

## System Requirements

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Disk | 8 GB | 20 GB |
| Network | 1 NIC | 1 NIC |

### Software Requirements

| Component | Requirement |
|-----------|-------------|
| Operating System | Ubuntu 22.04+, Debian 12+, or compatible derivative |
| Architecture | x86_64 (amd64) or ARM64 |
| Package Manager | APT (apt-get) |
| Shell | Bash 4.0+ |
| Privileges | Root access required |
| Docker | Installed automatically by script |

### Network Requirements

| Port | Protocol | Purpose |
|------|----------|--------|
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS traffic |
| 81 | TCP | NPM Web administration UI |

### External Requirements

| Requirement | Purpose |
|-------------|--------|
| Cloudflare Account | DNS challenge for wildcard certificate |
| Cloudflare API Token | Zone:DNS:Edit permission |
| Technitium DNS Server | SRV record resolution for dynamic routing |
| Domain Name | Managed by Cloudflare |

---

## Pre-Installation Checklist

### Required Information

- [ ] **Server IP Address**: Static IP for the proxy server
- [ ] **Admin Email**: Email for NPM login and Let's Encrypt
- [ ] **Admin Password**: Minimum 8 characters
- [ ] **Wildcard Domain**: Domain for SSL certificate (e.g., `home.vanauken.tech`)
- [ ] **Cloudflare API Token**: With Zone:DNS:Edit permissions
- [ ] **Internal DNS Server IP**: Your Technitium DNS server

### Creating a Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to **My Profile** → **API Tokens**
3. Click **Create Token**
4. Use the **Edit zone DNS** template
5. Configure:
   - **Zone Resources**: Include → Specific zone → `vanauken.tech`
   - **Permissions**: Zone → DNS → Edit
6. Click **Continue to summary** → **Create Token**
7. Copy the token (you won't see it again)

### Pre-Installation Steps

1. **Deploy Technitium DNS Server**: Complete the DNS setup first
2. **Deploy LXC/VM**: Create a fresh Ubuntu or Debian container/VM
3. **Assign Static IP**: Configure networking with a static IP
4. **Point Public DNS**: Ensure your domain's public DNS has an A record pointing to this server's public IP (or use NAT/port forwarding)

---

## Installation

### Quick Start (One-Liner)

Run this command as root on a fresh system:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

### Step-by-Step Installation

#### Step 1: Connect to Your Server

```bash
ssh root@<server-ip>
```

#### Step 2: Verify Root Access

```bash
whoami
# Output should be: root
```

#### Step 3: Run the Installer

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

#### Step 4: Follow the Prompts

The installer will guide you through configuration (see next section).

---

## Configuration Walkthrough

### Stage 1: Preflight Checks

The script automatically verifies system requirements:

```
  ── Preflight Checks ──────────────────────────────────────────

    ✔  Running as root
    ✔  Compatible OS detected: Ubuntu
    ✔  APT package manager available
    ✔  Internet connectivity confirmed
    ✔  Detected IP address: 172.16.250.9
```

### Stage 2: Basic Configuration

#### IP Address Confirmation

```
  NPM Server IP address [172.16.250.9]:
```

Press **Enter** to accept or type a different IP.

#### Installation Method

```
  Installation Method:
    1) Docker (recommended)
    2) Native (bare-metal)
  Select [1]:
```

**Docker** is strongly recommended for:
- Easy updates
- Isolation from host system
- Consistent behavior across platforms

### Stage 3: Admin Account

```
  Admin Account:
  Admin email address: admin@vanauken.tech
  Admin password: ********
  Confirm password: ********
```

- **Email**: Used for NPM login and Let's Encrypt notifications
- **Password**: Minimum 8 characters

### Stage 4: SSL Certificate Configuration

#### Wildcard Domain

```
  Wildcard Certificate Domain:
  Example: For '*.home.vanauken.tech', enter 'home.vanauken.tech'
  Domain (without wildcard): home.vanauken.tech
```

This creates a certificate valid for:
- `home.vanauken.tech`
- `*.home.vanauken.tech` (all subdomains)

#### DNS Provider

```
  DNS Provider for Let's Encrypt DNS Challenge:
    1) Cloudflare (recommended)
    2) Route53 (AWS)
    3) DigitalOcean
    4) Manual (skip auto-certificate)
  Select [1]: 1
```

#### Cloudflare API Token

```
  Cloudflare API Token:
  Create at: https://dash.cloudflare.com/profile/api-tokens
  Required permissions: Zone:DNS:Edit
  API Token: ************************************
```

Paste your Cloudflare API token (it won't be displayed).

### Stage 5: Dynamic Proxy Configuration

#### Internal DNS Server

```
  Internal DNS Server (for SRV record resolution):
  This is your Technitium DNS server IP
  DNS Server IP: 172.16.250.8
```

This is the IP of your Technitium DNS server where SRV records are stored.

#### Enable Dynamic Proxy

```
  Configure dynamic SSL proxy (SRV-based)? [Y/n]: y
```

**Yes** enables the Lua-based SRV resolver for automatic backend routing.

### Configuration Summary

```
  Configuration Summary:
    Server IP      : 172.16.250.9
    Install method : docker
    Admin email    : admin@vanauken.tech
    Wildcard domain: *.home.vanauken.tech
    DNS provider   : cloudflare
    Internal DNS   : 172.16.250.8
    Dynamic proxy  : y

  Proceed with installation? [Y/n]:
```

---

## Post-Installation Verification

### Automatic Verification

```
  ── Verification ──────────────────────────────────────────

    ✔  NPM container is running
    ✔  Web UI is accessible on port 81
    ✔  HTTPS is responding on port 443
    ✔  Dynamic proxy configuration present
    ✔  Wildcard certificate installed
```

### Manual Verification Steps

#### 1. Access the Web UI

Open a browser and navigate to:
```
http://<server-ip>:81
```

Log in with your configured email and password.

#### 2. Verify Certificate

In NPM, go to **SSL Certificates** and verify the wildcard certificate shows as "Valid".

#### 3. Test HTTPS

Create a test DNS record and access it:
```bash
# Assuming DNS is configured
curl -I https://test.home.vanauken.tech
```

---

## Understanding the Dynamic SSL Proxy

### How It Works

The dynamic SSL proxy eliminates the need to manually configure each proxy host in NPM. Instead, it uses DNS SRV records to determine where to route requests at runtime.

### Traffic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLIENT                                     │
│                                                                         │
│     Browser: https://proxmox.mgmt.home.vanauken.tech                   │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         STEP 1: DNS LOOKUP                              │
│                                                                         │
│     Query: proxmox.mgmt.home.vanauken.tech                             │
│     Response: 172.16.250.9 (Proxy IP)                                  │
│                                                                         │
│     Note: This is NOT the real Proxmox IP                              │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    STEP 2: TLS HANDSHAKE                                │
│                                                                         │
│     Client connects to 172.16.250.9:443                                │
│     NPM presents wildcard certificate: *.home.vanauken.tech            │
│     Certificate is VALID - browser shows padlock                       │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    STEP 3: LUA SRV RESOLVER                             │
│                                                                         │
│     Host header: proxmox.mgmt.home.vanauken.tech                       │
│                                                                         │
│     Lua script extracts:                                               │
│       server = "proxmox"                                               │
│       vlan = "mgmt"                                                    │
│       domain = "home.vanauken.tech"                                    │
│                                                                         │
│     Queries SRV record:                                                │
│       _https._tcp.proxmox.mgmt.home.vanauken.tech                      │
│                                                                         │
│     SRV Response:                                                      │
│       Priority: 0                                                      │
│       Weight: 0                                                        │
│       Port: 8006                                                       │
│       Target: proxmox.backend.mgmt.home.vanauken.tech                  │
│                                                                         │
│     Resolves target A record:                                          │
│       proxmox.backend.mgmt.home.vanauken.tech → 172.16.250.2           │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    STEP 4: PROXY TO BACKEND                             │
│                                                                         │
│     NPM proxies request to: https://172.16.250.2:8006                  │
│                                                                         │
│     Headers forwarded:                                                 │
│       Host: proxmox.mgmt.home.vanauken.tech                            │
│       X-Real-IP: <client-ip>                                           │
│       X-Forwarded-For: <client-ip>                                     │
│       X-Forwarded-Proto: https                                         │
│       X-Forwarded-Host: proxmox.mgmt.home.vanauken.tech                │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PROXMOX SERVER                                  │
│                                                                         │
│     Receives request on 172.16.250.2:8006                              │
│     Responds with Proxmox web interface                                │
│     Response proxied back through NPM to client                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Protocol Detection

The Lua script automatically detects whether to use HTTP or HTTPS for backend connections based on port:

| Port | Protocol |
|------|----------|
| 80, 81, 3000, 5380, 8080, 8081, 9000 | HTTP |
| All other ports | HTTPS |

---

## Adding New Servers

### Step-by-Step: Add a New Service

To make any internal service accessible via HTTPS:

#### Example: Adding Portainer (172.16.200.10:9443)

**Goal:** Access Portainer at `https://portainer.pro.home.vanauken.tech`

#### Step 1: Create Public A Record

In Technitium, zone `pro.home.vanauken.tech`:

| Field | Value |
|-------|-------|
| Name | `portainer` |
| Type | A |
| IPv4 Address | `172.16.250.9` (Proxy IP) |
| TTL | 300 |

#### Step 2: Create Backend A Record

In Technitium, zone `backend.pro.home.vanauken.tech`:

| Field | Value |
|-------|-------|
| Name | `portainer` |
| Type | A |
| IPv4 Address | `172.16.200.10` (Real server IP) |
| TTL | 300 |

#### Step 3: Create SRV Record

In Technitium, zone `pro.home.vanauken.tech`:

| Field | Value |
|-------|-------|
| Name | `_https._tcp.portainer` |
| Type | SRV |
| Priority | 0 |
| Weight | 0 |
| Port | 9443 |
| Target | `portainer.backend.pro.home.vanauken.tech` |
| TTL | 300 |

#### Step 4: Test Access

Open browser to:
```
https://portainer.pro.home.vanauken.tech
```

**Result:** Valid HTTPS connection to Portainer with no certificate warnings.

### Quick Reference: DNS Records Per Server

```
PUBLIC A RECORD:
<hostname>.<vlan>.<domain> → <proxy-ip>

BACKEND A RECORD:
<hostname>.backend.<vlan>.<domain> → <real-server-ip>

SRV RECORD:
_https._tcp.<hostname>.<vlan>.<domain> → 0 0 <port> <hostname>.backend.<vlan>.<domain>
```

---

## Certificate Management

### Viewing Certificates

1. Open NPM web UI
2. Navigate to **SSL Certificates**
3. View certificate details, expiration, and status

### Certificate Renewal

Let's Encrypt certificates are valid for 90 days. NPM automatically renews certificates 30 days before expiration.

**Verify auto-renewal is working:**
```bash
docker logs nginx-proxy-manager 2>&1 | grep -i renew
```

### Manual Certificate Renewal

If needed, force renewal via the web UI:
1. Go to **SSL Certificates**
2. Click the three dots next to your certificate
3. Select **Renew Now**

### Adding Additional Certificates

For domains outside your wildcard:
1. Go to **SSL Certificates** → **Add SSL Certificate**
2. Select **Let's Encrypt**
3. Enter domain names
4. Choose DNS challenge and provider
5. Enter API credentials
6. Click **Save**

---

## Maintenance & Administration

### Container Management

```bash
# View container status
docker ps | grep nginx-proxy-manager

# View logs
docker logs nginx-proxy-manager

# Follow logs in real-time
docker logs -f nginx-proxy-manager

# Restart container
docker restart nginx-proxy-manager

# Stop container
docker stop nginx-proxy-manager

# Start container
docker start nginx-proxy-manager
```

### Updating NPM

```bash
cd /opt/npm

# Pull latest image
docker compose pull

# Recreate container with new image
docker compose up -d
```

### Backup & Restore

#### Backup

```bash
# Stop container (optional but recommended)
docker stop nginx-proxy-manager

# Backup data directories
tar -czvf npm-backup-$(date +%Y%m%d).tar.gz /data/nginx /data/letsencrypt /opt/npm

# Start container
docker start nginx-proxy-manager
```

#### Restore

```bash
# Stop container
docker stop nginx-proxy-manager

# Restore data
tar -xzvf npm-backup-YYYYMMDD.tar.gz -C /

# Start container
docker start nginx-proxy-manager
```

### Viewing Access Logs

In the web UI:
1. Go to **Audit Log** for administrative actions
2. Go to individual proxy hosts → **Access List** for traffic logs

Or via command line:
```bash
docker exec nginx-proxy-manager cat /data/logs/fallback_access.log
```

---

## Troubleshooting

### Common Issues

#### 502 Bad Gateway

**Cause:** Backend server unreachable or SRV record misconfigured.

**Diagnosis:**
```bash
# Check SRV record exists
dig @172.16.250.8 _https._tcp.server.vlan.home.vanauken.tech SRV +short

# Check backend A record exists
dig @172.16.250.8 server.backend.vlan.home.vanauken.tech A +short

# Check backend is reachable
curl -k https://<backend-ip>:<port>
```

**Solutions:**
- Verify SRV record target matches backend A record name
- Verify backend server is running and accessible
- Check port number in SRV record matches actual service port

#### Certificate Not Valid

**Cause:** Certificate issuance failed or expired.

**Diagnosis:**
```bash
# Check certificate files exist
ls -la /etc/ssl/home.vanauken.tech/

# Check certificate expiration
openssl x509 -in /etc/ssl/home.vanauken.tech/fullchain.pem -noout -dates
```

**Solutions:**
- Verify Cloudflare API token has correct permissions
- Check DNS propagation for challenge records
- Manually request certificate via NPM web UI

#### Container Won't Start

**Diagnosis:**
```bash
# Check container logs
docker logs nginx-proxy-manager

# Check if ports are in use
ss -tlnp | grep -E '80|443|81'
```

**Solutions:**
- Stop conflicting services using ports 80, 443, or 81
- Check for Docker daemon issues: `systemctl status docker`

#### Dynamic Proxy Not Working

**Diagnosis:**
```bash
# Check custom config exists
cat /data/nginx/custom/http.conf

# Check Lua script exists
cat /data/nginx/custom/srv_resolver.lua

# Test DNS resolver connectivity
docker exec nginx-proxy-manager nslookup google.com 172.16.250.8
```

**Solutions:**
- Verify internal DNS server IP is correct
- Check firewall allows DNS queries to internal DNS
- Restart container: `docker restart nginx-proxy-manager`

### Log Files

| Log | Location |
|-----|----------|
| Installation log | `/var/log/npm-install-YYYYMMDD-HHMMSS.log` |
| Container logs | `docker logs nginx-proxy-manager` |
| Nginx error log | `/data/logs/fallback_error.log` (inside container) |
| Nginx access log | `/data/logs/fallback_access.log` (inside container) |

### Debugging Lua Script

Enable debug logging in the Lua script:
```bash
# View Lua-related logs
docker logs nginx-proxy-manager 2>&1 | grep -i lua
```

---

## Security Considerations

### Recommended Security Practices

1. **Restrict Admin UI Access**: Limit port 81 to management network only
2. **Use Strong Passwords**: Minimum 16 characters for admin account
3. **Enable Access Lists**: Restrict which IPs can access proxied services
4. **Monitor Logs**: Watch for suspicious access patterns
5. **Regular Updates**: Keep NPM container updated
6. **Firewall Rules**: Only expose necessary ports

### Firewall Configuration

```bash
# Allow HTTP/HTTPS from anywhere (public traffic)
ufw allow 80/tcp
ufw allow 443/tcp

# Allow admin UI only from management VLAN
ufw allow from 172.16.250.0/24 to any port 81

# Enable firewall
ufw enable
```

### Securing the Admin UI

1. **Use a proxy host** to access the admin UI via HTTPS:
   - Create proxy host for `npm.mgmt.home.vanauken.tech`
   - Point to `127.0.0.1:81`
   - Enable Force SSL

2. **Block direct port 81 access** after setting up the proxy host.

---

## Appendix

### File Locations

| Component | Path |
|-----------|------|
| Docker Compose | `/opt/npm/docker-compose.yml` |
| NPM data | `/data/nginx/` |
| Let's Encrypt certs | `/data/letsencrypt/` |
| Wildcard cert copy | `/etc/ssl/<domain>/` |
| Custom Nginx config | `/data/nginx/custom/http.conf` |
| Lua SRV resolver | `/data/nginx/custom/srv_resolver.lua` |

### Related Documentation

- [Technitium DNS Server User Manual](technitium-dns-user-manual.md)
- [NPM Official Documentation](https://nginxproxymanager.com/guide/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)

### Script Source Code

- [GitHub Repository](https://github.com/tvanauken/install-scripts)
- [Script: nginx-proxy-manager-install.sh](https://github.com/tvanauken/install-scripts/blob/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)

### Support

For issues with this script, open an issue on the [GitHub repository](https://github.com/tvanauken/install-scripts/issues).

---

*Document created by Thomas Van Auken — Van Auken Tech*  
*Part of the Van Auken Tech Install Scripts Collection*