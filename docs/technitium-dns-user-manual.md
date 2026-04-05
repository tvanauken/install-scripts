# Technitium DNS Server — User Manual

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
7. [DNS Zone Architecture](#dns-zone-architecture)
8. [Adding DNS Records](#adding-dns-records)
9. [Integration with Nginx Proxy Manager](#integration-with-nginx-proxy-manager)
10. [Maintenance & Administration](#maintenance--administration)
11. [Troubleshooting](#troubleshooting)
12. [Security Considerations](#security-considerations)
13. [Appendix](#appendix)

---

## Overview

### What This Script Does

The Technitium DNS Server installer is an enterprise-grade automation script that deploys a fully configured DNS server from scratch. It is designed for UniFi network environments with split-horizon DNS requirements, enabling internal name resolution across VLANs while supporting dynamic SSL proxy integration.

### Key Features

- **Zero-Touch Installation**: Downloads and installs Technitium DNS Server from official sources
- **API-Driven Configuration**: All settings applied programmatically—no manual web UI steps required
- **Split-Horizon DNS**: Creates hierarchical zone structure for VLAN segmentation
- **SSL Proxy Integration**: Backend zones for seamless Nginx Proxy Manager integration
- **RFC 2136 Support**: Dynamic DNS updates for automated record management
- **Multi-Distro Support**: Works on Ubuntu, Debian, and derivatives
- **Self-Correcting**: Built-in retry logic and error recovery

### Use Cases

1. **Home Lab DNS**: Centralized name resolution for virtualized infrastructure
2. **UniFi Network Integration**: Per-VLAN DNS zones with consistent naming
3. **SSL Proxy Backend**: Supports dynamic HTTPS routing via SRV records
4. **Development Environments**: Local DNS for testing without public DNS propagation

---

## System Requirements

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 512 MB | 1 GB |
| Disk | 4 GB | 8 GB |
| Network | 1 NIC | 1 NIC |

### Software Requirements

| Component | Requirement |
|-----------|-------------|
| Operating System | Ubuntu 22.04+, Debian 12+, or compatible derivative |
| Architecture | x86_64 (amd64) or ARM64 |
| Package Manager | APT (apt-get) |
| Shell | Bash 4.0+ |
| Privileges | Root access required |

### Network Requirements

| Port | Protocol | Purpose |
|------|----------|--------|
| 53 | TCP/UDP | DNS queries |
| 5380 | TCP | Web administration UI |
| 853 | TCP | DNS-over-TLS (optional) |
| 443 | TCP | DNS-over-HTTPS (optional) |

### Firewall Considerations

The script automatically configures UFW or firewalld if present. If using a different firewall, manually allow:
- Port 53 TCP/UDP from your network
- Port 5380 TCP from admin workstations

---

## Pre-Installation Checklist

Before running the installer, gather the following information:

### Required Information

- [ ] **Server IP Address**: Static IP for the DNS server
- [ ] **Admin Username**: Username for Technitium web UI
- [ ] **Admin Password**: Minimum 8 characters
- [ ] **Primary Domain**: Your internal DNS zone (e.g., `home.vanauken.tech`)
- [ ] **VLAN Names**: List of VLANs needing sub-zones (e.g., `dmz,pro,storage`)
- [ ] **Upstream Forwarders**: External DNS servers (default: `1.1.1.1,9.9.9.9`)

### Optional Information

- [ ] **Reverse DNS Subnets**: For PTR records (e.g., `172.16.250`)
- [ ] **Backend Zones**: Required if using SSL proxy integration

### Pre-Installation Steps

1. **Deploy LXC/VM**: Create a fresh Ubuntu or Debian container/VM
2. **Assign Static IP**: Configure networking with a static IP address
3. **Update System**: Run `apt update && apt upgrade -y`
4. **Verify Connectivity**: Ensure internet access for package downloads

---

## Installation

### Quick Start (One-Liner)

Run this command as root on a fresh system:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
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
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

#### Step 4: Follow the Prompts

The installer will guide you through configuration (see next section).

---

## Configuration Walkthrough

### Stage 1: Preflight Checks

The script automatically verifies:
- Root privileges
- Operating system compatibility
- APT package manager availability
- Internet connectivity
- Current IP address detection

**What You'll See:**
```
  ── Preflight Checks ──────────────────────────────────────────

    ✔  Running as root
    ✔  Compatible OS detected: Ubuntu
    ✔  APT package manager available
    ✔  Internet connectivity confirmed
    ✔  Detected IP address: 172.16.250.8
```

### Stage 2: Server Configuration

#### IP Address Confirmation

```
  DNS Server IP address [172.16.250.8]:
```

- Press **Enter** to accept the detected IP
- Or type a different IP address if needed

#### Admin Account Setup

```
  Admin Account:
  Admin username [admin]: technitium-admin
  Admin password: ********
  Confirm password: ********
```

- **Username**: Any alphanumeric string (default: `admin`)
- **Password**: Minimum 8 characters, no restrictions on complexity

### Stage 3: Domain Configuration

#### Primary Zone

```
  Domain Configuration:
  Example: For 'home.vanauken.tech', enter 'home.vanauken.tech'
  Primary domain (your internal zone): home.vanauken.tech
```

This creates your main DNS zone. All other zones will be subdomains of this zone.

#### VLAN Sub-Zones

```
  VLAN Sub-zones:
  Enter VLAN names separated by commas (e.g., dmz,pro,storage,mgmt)
  These become: dmz.home.vanauken.tech, pro.home.vanauken.tech, etc.
  VLAN names (comma-separated): dmz,pro,storage,mgmt,guest,iot
```

This creates a zone for each VLAN:
- `dmz.home.vanauken.tech`
- `pro.home.vanauken.tech`
- `storage.home.vanauken.tech`
- etc.

#### Backend Zones for SSL Proxy

```
  Backend Zones (for SSL Proxy Integration):
  Create backend.* zones for SSL proxy? [Y/n]: y
```

Backend zones store the real IP addresses of servers, while public zones point to your proxy server. This enables the dynamic SSL proxy to function.

**Zones Created:**
- `backend.home.vanauken.tech`
- `backend.dmz.home.vanauken.tech`
- `backend.pro.home.vanauken.tech`
- etc.

### Stage 4: DNS Settings

#### Upstream Forwarders

```
  Upstream DNS Forwarders:
  Forwarders (comma-separated) [1.1.1.1,9.9.9.9]: 1.1.1.1,8.8.8.8
```

These servers handle queries for domains outside your zones.

#### RFC 2136 Dynamic Updates

```
  Enable RFC 2136 dynamic updates? [Y/n]: y
```

- **Yes**: Allows programmatic DNS record updates (recommended for automation)
- **No**: Records can only be added via web UI

### Stage 5: Reverse DNS (Optional)

```
  Creating Reverse DNS Zones

  Enter the subnets you want reverse DNS for.
  Example: 172.16.250,192.168.200,10.1.1
  These become: 250.16.172.in-addr.arpa, etc.
  Subnets (comma-separated, or Enter to skip): 172.16.250,172.16.251
```

Reverse DNS enables IP-to-hostname lookups (PTR records).

### Configuration Summary

Before installation proceeds, you'll see a summary:

```
  Configuration Summary:
    Server IP     : 172.16.250.8
    Admin user    : admin
    Primary zone  : home.vanauken.tech
    VLAN zones    : dmz.home.vanauken.tech pro.home.vanauken.tech ...
    Backend zones : 7 zones
    Forwarders    : 1.1.1.1,9.9.9.9
    RFC 2136      : y

  Proceed with installation? [Y/n]:
```

Type **Y** or press **Enter** to proceed.

---

## Post-Installation Verification

### Automatic Verification

The script performs these checks automatically:

```
  ── Verification ──────────────────────────────────────────

    ✔  DNS service is running
    ✔  API is accessible on port 5380
    ✔  DNS resolution working (forwarding)
    ✔  Total zones configured: 15
```

### Manual Verification Steps

#### 1. Access the Web UI

Open a browser and navigate to:
```
http://<server-ip>:5380
```

Log in with your configured credentials.

#### 2. Test DNS Resolution

From any machine on your network:

```bash
# Test forwarding (external domains)
dig @172.16.250.8 google.com +short

# Test local zone
dig @172.16.250.8 home.vanauken.tech +short
```

#### 3. Verify Zone List

In the web UI, navigate to **Zones** to see all created zones.

---

## DNS Zone Architecture

### Zone Hierarchy

The installer creates a hierarchical zone structure:

```
home.vanauken.tech              ← Primary zone
├── dmz.home.vanauken.tech      ← VLAN zone (DMZ network)
├── pro.home.vanauken.tech      ← VLAN zone (Production)
├── storage.home.vanauken.tech  ← VLAN zone (Storage network)
├── mgmt.home.vanauken.tech     ← VLAN zone (Management)
│
├── backend.home.vanauken.tech  ← Backend zone (real IPs)
├── backend.dmz.home.vanauken.tech
├── backend.pro.home.vanauken.tech
└── backend.storage.home.vanauken.tech
```

### Zone Purpose

| Zone Type | Purpose | Example |
|-----------|---------|--------|
| Primary | Root zone for all internal DNS | `home.vanauken.tech` |
| VLAN | Per-network segmentation | `dmz.home.vanauken.tech` |
| Backend | Real server IPs (for proxy) | `backend.dmz.home.vanauken.tech` |
| Reverse | IP-to-hostname lookups | `250.16.172.in-addr.arpa` |

### Split-Horizon DNS Explained

With split-horizon DNS, the same hostname can resolve differently based on context:

**Public Zone (for SSL proxy):**
```
npm.dmz.home.vanauken.tech → 172.16.250.9 (proxy IP)
```

**Backend Zone (real IP):**
```
npm.backend.dmz.home.vanauken.tech → 172.16.200.5 (actual server)
```

---

## Adding DNS Records

### Using the Web UI

1. Navigate to **Zones** → Select your zone
2. Click **Add Record**
3. Fill in the record details
4. Click **Save**

### Common Record Types

#### A Record (IPv4 Address)

| Field | Value |
|-------|-------|
| Name | `server1` |
| Type | A |
| IPv4 Address | `172.16.250.10` |
| TTL | 3600 |

**Result:** `server1.home.vanauken.tech → 172.16.250.10`

#### CNAME Record (Alias)

| Field | Value |
|-------|-------|
| Name | `www` |
| Type | CNAME |
| Domain | `server1.home.vanauken.tech` |
| TTL | 3600 |

**Result:** `www.home.vanauken.tech → server1.home.vanauken.tech`

#### SRV Record (for SSL Proxy)

| Field | Value |
|-------|-------|
| Name | `_https._tcp.server1` |
| Type | SRV |
| Priority | 0 |
| Weight | 0 |
| Port | 443 |
| Target | `server1.backend.home.vanauken.tech` |

**Purpose:** Tells the SSL proxy where to route requests.

#### PTR Record (Reverse DNS)

In the reverse zone (e.g., `250.16.172.in-addr.arpa`):

| Field | Value |
|-------|-------|
| Name | `10` |
| Type | PTR |
| Domain | `server1.home.vanauken.tech` |

**Result:** `172.16.250.10 → server1.home.vanauken.tech`

### Using RFC 2136 Dynamic Updates

```bash
# Install nsupdate if not present
apt install dnsutils

# Update a record
nsupdate << EOF
server 172.16.250.8
zone home.vanauken.tech
update delete server1.home.vanauken.tech A
update add server1.home.vanauken.tech 3600 A 172.16.250.10
send
EOF
```

---

## Integration with Nginx Proxy Manager

### Architecture Overview

The DNS server works with Nginx Proxy Manager to provide valid HTTPS for all internal services:

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser Request                       │
│                https://npm.dmz.home.vanauken.tech           │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Technitium DNS                          │
│           npm.dmz.home.vanauken.tech → Proxy IP             │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Nginx Proxy Manager                       │
│              Wildcard cert: *.home.vanauken.tech            │
│                              │                              │
│     Lua script queries SRV record for backend target        │
│         _https._tcp.npm.dmz.home.vanauken.tech              │
│                      ↓                                      │
│            Target: npm.backend.dmz.home.vanauken.tech       │
│            Port: 81                                         │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Actual NPM Server                         │
│    npm.backend.dmz.home.vanauken.tech (172.16.200.5:81)    │
└─────────────────────────────────────────────────────────────┘
```

### Required DNS Records (Per Server)

For each server you want accessible via HTTPS:

1. **Public A Record** (points to proxy):
   ```
   server.vlan.home.vanauken.tech → <proxy-ip>
   ```

2. **Backend A Record** (real IP):
   ```
   server.backend.vlan.home.vanauken.tech → <real-server-ip>
   ```

3. **SRV Record** (routing info):
   ```
   _https._tcp.server.vlan.home.vanauken.tech → 0 0 <port> server.backend.vlan.home.vanauken.tech
   ```

---

## Maintenance & Administration

### Service Management

```bash
# Check status
systemctl status dns

# Restart service
systemctl restart dns

# View logs
journalctl -u dns -f
```

### Backup & Restore

#### Backup

```bash
# Backup all Technitium data
tar -czvf technitium-backup-$(date +%Y%m%d).tar.gz /etc/dns /var/lib/technitium
```

#### Restore

```bash
# Stop service
systemctl stop dns

# Restore data
tar -xzvf technitium-backup-YYYYMMDD.tar.gz -C /

# Start service
systemctl start dns
```

### Updating Technitium

Technitium updates automatically via the web UI. To check manually:

1. Open web UI → **Settings** → **General**
2. Click **Check for Update**
3. If available, click **Update Now**

---

## Troubleshooting

### Common Issues

#### DNS Service Won't Start

**Symptoms:** `systemctl status dns` shows failed

**Check logs:**
```bash
journalctl -u dns --no-pager -n 50
```

**Common causes:**
- Port 53 already in use (systemd-resolved)
- Insufficient permissions
- Corrupted configuration

**Fix for systemd-resolved conflict:**
```bash
# Disable systemd-resolved
systemctl disable systemd-resolved
systemctl stop systemd-resolved

# Update resolv.conf
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# Restart Technitium
systemctl restart dns
```

#### Web UI Not Accessible

**Check if port is listening:**
```bash
ss -tlnp | grep 5380
```

**Check firewall:**
```bash
ufw status
# or
firewall-cmd --list-all
```

#### DNS Queries Not Resolving

**Test local resolution:**
```bash
dig @127.0.0.1 google.com +short
```

**Test from another machine:**
```bash
dig @<dns-server-ip> google.com +short
```

**Check forwarder configuration** in web UI under **Settings** → **DNS Settings**.

### Log Files

| Log | Location |
|-----|----------|
| Installation log | `/var/log/technitium-dns-install-YYYYMMDD-HHMMSS.log` |
| Service logs | `journalctl -u dns` |
| Query logs | Web UI → **Logs** |

---

## Security Considerations

### Recommended Security Practices

1. **Restrict Web UI Access**: Limit port 5380 to management VLAN only
2. **Use Strong Passwords**: Minimum 12 characters with complexity
3. **Enable HTTPS for Admin**: Configure SSL certificate in Settings
4. **Limit Recursion**: Only allow recursion from trusted networks
5. **Monitor Query Logs**: Watch for suspicious query patterns
6. **Regular Backups**: Automate backup to off-server storage

### Firewall Configuration

```bash
# Allow DNS only from internal networks
ufw allow from 172.16.0.0/16 to any port 53

# Allow admin UI only from management VLAN
ufw allow from 172.16.250.0/24 to any port 5380

# Deny all other access
ufw default deny incoming
ufw enable
```

---

## Appendix

### Related Documentation

- [Nginx Proxy Manager User Manual](nginx-proxy-manager-user-manual.md)
- [Technitium Official Documentation](https://technitium.com/dns/)
- [RFC 2136 - Dynamic Updates](https://tools.ietf.org/html/rfc2136)

### Script Source Code

- [GitHub Repository](https://github.com/tvanauken/install-scripts)
- [Script: technitium-dns-install.sh](https://github.com/tvanauken/install-scripts/blob/main/dns-server/technitium-dns-install.sh)

### Support

For issues with this script, open an issue on the [GitHub repository](https://github.com/tvanauken/install-scripts/issues).

---

*Document created by Thomas Van Auken — Van Auken Tech*  
*Part of the Van Auken Tech Install Scripts Collection*