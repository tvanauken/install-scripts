# Technitium DNS Generic Installer
### Thomas Van Auken — Van Auken Tech

**Script:** [`technitiumdnsgeneric-install.sh`](technitiumdnsgeneric-install.sh)

---

## Overview

Generic Technitium DNS Server installer for Debian 13 (Trixie) systems. Installs Technitium DNS Server with a **hardcoded configuration** suitable for testing and generic deployments.

**⚠ Important:** This is **NOT** a replication script. This installer uses a pre-defined set of apps and settings. For production deployments that require replicating specific configurations from existing servers, use a dedicated replication installer instead.

---

## What It Installs

- **.NET ASP.NET Core 10.0** runtime (via official Microsoft install script)
- **Technitium DNS Server** (latest portable version)
- **5 Hardcoded Apps:**
  - Advanced Blocking
  - DNS Block List (DNSBL)
  - Failover
  - Geo Country
  - What Is My Dns

---

## Configuration

- **Recursion:** Allowed for all networks (ACLs cleared)
- **Logging:** Enabled with query logging in **UTC time**
- **Port 53:** systemd-resolved disabled to free the port
- **Service:** Auto-starts on boot

---

## Requirements

- **OS:** Debian 13 (Trixie) or compatible
- **Architecture:** amd64
- **Network:** Internet connectivity required
- **Privileges:** Must run as root

---

## Usage

### Direct Execution (Existing System)
```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/install/technitiumdnsgeneric-install.sh | bash
```

### Download and Inspect
```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/install/technitiumdnsgeneric-install.sh -o technitium-install.sh
bash technitium-install.sh
```

---

## Technical Details

### Packages Installed
- `curl` — HTTP client
- `libicu76` — International Components for Unicode (Debian 13)
- `python3` — For API configuration

### SSL Workaround
Uses `curl` with HTTP/1.1 flags and retry logic to handle OpenSSL 3.x `SSL_read` EOF issues in container environments:
```bash
curl --http1.1 --no-keepalive --retry 3 --retry-delay 2 --retry-max-time 60 -fsSL
```

### Service Details
- **Service Name:** `dns.service`
- **Config Directory:** `/etc/dns`
- **Install Directory:** `/opt/technitium/dns`
- **API Port:** 5380 (HTTP)
- **DNS Port:** 53 (TCP/UDP)

### API Configuration
Uses Python `urllib` to:
1. Login with default credentials (`admin`/`admin`)
2. Retrieve store app list
3. Install apps by name + URL
4. Configure recursion ACLs
5. Enable logging with UTC timestamps

---

## Post-Installation

Access the web interface at:
```
http://<server-ip>:5380
```

Default credentials:
- **Username:** admin
- **Password:** admin

**⚠ Change the default password immediately after first login.**

---

## Limitations

- **Hardcoded app list** — installs 5 specific apps only
- **Generic configuration** — not customized for specific environments
- **No replication capability** — cannot mirror existing server configurations
- **Single OS support** — Debian 13 Trixie (libicu76 dependency)

---

## For Production Replication

If you need to replicate an existing Technitium DNS server configuration (apps, settings, zones, etc.), this script is **not appropriate**. A replication script should:

1. Query the source server's API for installed apps
2. Query the source server's API for settings
3. Replicate the exact configuration on new instances

This generic installer does none of those things. It installs a fixed configuration regardless of any existing servers.

---

**Copyright © 2025 Thomas Van Auken — Van Auken Tech**  
**License:** MIT  
**Repository:** https://github.com/tvanauken/install-scripts