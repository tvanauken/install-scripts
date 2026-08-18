# User Manual: Repair Technitium Corrupted SQLite Database Errors
### Van Auken Tech · Thomas Van Auken

## Introduction

The **Repair Technitium Corrupted SQLite Database Errors** script is an automated utility for Technitium DNS Server environments. Its sole purpose is to resolve the common error: `SQLite Error 11: database disk image is malformed`. This error occurs when the DNS server's `querylogs.db` becomes corrupted, typically due to improper shutdowns, unexpected host reboots, or disk I/O faults.

## Features

- **Automated Service Management:** Safely stops the `dns.service` prior to any database file manipulation to ensure system stability.
- **Targeted Removal:** Automatically identifies and removes the corrupted `.db` file within `/etc/dns/apps/Query Logs (Sqlite)/`.
- **System Verification:** Verifies the `dns.service` restarts and is running cleanly post-operation.
- **Logging:** A full execution log is saved under `/var/log/technitium_sqlite_repair_YYYYMMDD_HHMMSS.log`.

## Prerequisites

- **Technitium DNS Server:** Must be installed on a systemd-managed Linux distribution (e.g., Debian, Ubuntu).
- **Query Logs (Sqlite) App:** Must be installed within Technitium.
- **Root Privileges:** The script requires `root` execution to interact with systemd and `/etc/dns/` files.

## Step-by-Step Instructions

1. **Access the Terminal**
   Connect to your Technitium DNS Server via SSH or local terminal interface using the `root` user account.

2. **Execute the Script**
   Run the following command in the terminal:
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/technitium-sqlite-repair/technitium_sqlite_repair.sh)
   ```

3. **Monitor Execution**
   - The script performs pre-flight checks, verifying you are `root` and `dns.service` exists.
   - It stops the DNS service cleanly.
   - The corrupted database file is safely deleted.
   - The DNS service is restarted, automatically generating a fresh, clean `querylogs.db`.

4. **Verify Result**
   You can verify the fix by logging into the Technitium web console, navigating to **Logs > Query Logs**, and observing that the queries display normally without the previous `SQLite Error 11` message.

---
*Created by Thomas Van Auken — Van Auken Tech*
