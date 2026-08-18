# Technitium Corrupted SQLite Database Repair

> Created by: Thomas Van Auken — Van Auken Tech

**Automatically repairs "SQLite Error 11: database disk image is malformed" errors** on a Technitium DNS Server by gracefully stopping the service, purging the corrupted database file, and restarting the service to generate a clean slate.

---

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/technitium-sqlite-repair/technitium_sqlite_repair.sh)
```

---

## Features

- **Automated Service Management** — Safely stops the `dns.service` prior to any database file manipulation to ensure system stability
- **Targeted Removal** — Automatically identifies and removes the corrupted `.db` file within `/etc/dns/apps/Query Logs (Sqlite)/`
- **System Verification** — Verifies the `dns.service` restarts and is running cleanly post-operation
- **Detailed Logging** — Full operation log saved to `/var/log/`

---

## Safety

**PROTECTED:** Your main DNS configuration (`dns.config`, block lists, zones) will not be touched.

**TARGET:** Only the SQLite `.db` files under `/etc/dns/apps/Query Logs (Sqlite)/` will be removed.

---

## Requirements

- Technitium DNS Server running on Debian/Ubuntu with systemd
- Root access
- Internet connectivity (for curl deployment)

---

## Documentation

- [User Manual](docs/user-manual.md) — Comprehensive usage guide
- [Build Log](docs/build-log.md) — Development and testing log

---

*Van Auken Tech · Thomas Van Auken*