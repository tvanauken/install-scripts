# Technitium DNS Server — Repair Corrupted SQLite Database Errors
### Van Auken Tech · Thomas Van Auken

> Part of the [Van Auken Tech Install Scripts Collection](../README.md)

---

## Overview

Automatically repairs "SQLite Error 11: database disk image is malformed" errors on a Technitium DNS Server. This script gracefully stops the Technitium DNS service, removes the corrupted `querylogs.db` file (and any other corrupted `.db` files in the query logs app directory), and restarts the service to generate a fresh, uncorrupted database.

## Safety

**PROTECTED:** Your main DNS configuration (`dns.config`, block lists, zones) will not be touched.
**TARGET:** Only the SQLite `.db` files under `/etc/dns/apps/Query Logs (Sqlite)/` will be removed.

## Usage

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/technitium-sqlite-repair/technitium_sqlite_repair.sh)
```

Requires root privileges.

---
*Van Auken Tech*