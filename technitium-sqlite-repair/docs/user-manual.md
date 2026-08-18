# Technitium SQLite Repair — User Manual

> Created by: Thomas Van Auken — Van Auken Tech
> Version: 1.0.0
> Date: 2026-08-18

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation & Execution](#installation--execution)
4. [Understanding the Interface](#understanding-the-interface)
5. [Step-by-Step Usage Guide](#step-by-step-usage-guide)
6. [Operations Performed](#operations-performed)
7. [Log Files](#log-files)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The **Technitium Corrupted SQLite Database Repair** script provides a safe and automated method for resolving `SQLite Error 11: database disk image is malformed` errors within a Technitium DNS Server environment.

This error occurs when the DNS server's `querylogs.db` becomes corrupted, typically due to improper shutdowns, unexpected host reboots, or disk I/O faults. The script performs a **complete reset** of the query logs database while protecting your primary DNS configuration.

---

## Requirements

### System Requirements
- **Technitium DNS Server** installed on a systemd-managed Linux distribution (e.g., Debian, Ubuntu)
- **Query Logs (Sqlite) App** installed within Technitium
- Internet connectivity (for curl deployment)

### Permissions
- Must be run as `root`
- SSH access to the server (if running remotely)

---

## Installation & Execution

### One-Line Installation

Run the following command on your Technitium DNS Server:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/technitium-sqlite-repair/technitium_sqlite_repair.sh)
```

### Local Execution

If you have downloaded the script:

```bash
chmod +x technitium_sqlite_repair.sh
./technitium_sqlite_repair.sh
```

---

## Understanding the Interface

### Header Display

When the script starts, you will see:
- **VANAUKEN TECH** banner in cyan
- Current hostname
- Current date and time
- Log file location

---

## Step-by-Step Usage Guide

### Step 1: Launch the Script

Execute the curl one-liner or run the script locally.

### Step 2: Review Preflight Checks

The script automatically verifies:
- ✔ Running as root
- ✔ `dns.service` is detected and valid
- ✔ Installation path `/etc/dns/apps` exists

### Step 3: Monitor Progress

The script executes each repair step with visible progress indicators:
- ◆ (cyan diamond) — Operation in progress
- ✔ (green checkmark) — Operation completed
- ⚠ (yellow warning) — Non-critical warning
- ✘ (red X) — Error occurred

### Step 4: Verify Result

After completion, a detailed summary shows the success status.
You can verify the fix by logging into the Technitium web console, navigating to **Logs > Query Logs**, and observing that the queries display normally without the previous error message.

---

## Operations Performed

### Step 1: Stop Service
- Gracefully stops the `dns.service` systemd unit

### Step 2: Locate Database
- Searches within `/etc/dns/apps/Query Logs (Sqlite)/` for `.db` files

### Step 3: Purge Database
- Iterates through all found database files
- Deletes each file to clear the corruption

### Step 4: Restart Service
- Starts the `dns.service` systemd unit
- Technitium automatically creates a fresh, clean `querylogs.db` upon startup

### Step 5: Verify Health
- Checks `systemctl is-active dns.service` to ensure it successfully restarted

---

## Log Files

All operations are logged to:

```
/var/log/technitium_sqlite_repair_YYYYMMDD_HHMMSS.log
```

The log includes:
- All commands executed
- Success/failure status
- Timestamps
- Error messages (if any)

---

## Troubleshooting

### "This script must be run as root"
Run with `sudo` or switch to root user:
```bash
sudo bash <(curl -fsSL URL)
```

### "dns.service not found"
This script expects Technitium to be installed as a systemd service named `dns.service`. If you installed it under a different name or via Docker, the script will abort to prevent unintended changes.

### App directory not found
The script looks for `/etc/dns/apps`. If your Technitium configuration is stored elsewhere, the script will skip file removal.

---

*Van Auken Tech · Thomas Van Auken*
