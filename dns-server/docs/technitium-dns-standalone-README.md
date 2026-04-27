# Technitium DNS Server — Standalone LXC Installation

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0

---

## Overview

One-command installation of Technitium DNS Server in a new Debian 13 LXC container on Proxmox VE. This script creates the container, installs Technitium DNS Server, and configures it with enterprise-ready defaults.

## Usage

Run from any Proxmox VE node command prompt:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
```

## What It Does

1. **Creates Debian 13 LXC** — 2 CPU, 2GB RAM, 8GB disk
2. **Installs Technitium DNS** — uses official installer with .NET runtime
3. **Installs 5 apps:**
   - Advanced Blocking v10
   - Auto PTR v4
   - Drop Requests v7
   - Log Exporter v2.1
   - Query Logs (Sqlite) v8
4. **Configures blocklists** — 4 Hagezi lists (multi, popupads, tif, fake)
5. **Sets recursion** — root hints only, QNAME minimization enabled

## Post-Installation

- **Web Interface:** `http://<container-ip>:5380`
- **Default Credentials:** admin / admin
- **⚠ Change password immediately!**

Container root password and API token are saved to `~/technitium-dns-<CTID>.creds`

## Documentation

- [Comprehensive User Manual](technitium-dns-standalone-manual.md)
- [Build Log](technitium-dns-standalone-build-log.md)
- [Repository README](../../README.md)

---

*Van Auken Tech · Thomas Van Auken*
