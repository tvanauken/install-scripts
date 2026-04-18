# PVE VM & CT Cleanup — User Manual

> Created by: Thomas Van Auken — Van Auken Tech
> Version: 1.0.0
> Date: 2026-04-18

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation & Execution](#installation--execution)
4. [Understanding the Interface](#understanding-the-interface)
5. [Step-by-Step Usage Guide](#step-by-step-usage-guide)
6. [Confirmation Process](#confirmation-process)
7. [Operations Performed](#operations-performed)
8. [Log Files](#log-files)
9. [Troubleshooting](#troubleshooting)
10. [Safety Features](#safety-features)

---

## Overview

The **PVE VM & CT Cleanup** script provides a safe, interactive, and comprehensive method for completely removing virtual machines (VMs) or containers (CTs) from a Proxmox VE environment.

Unlike the standard `qm destroy` or `pct destroy` commands, this script performs a **complete cleanup** including:
- Stopping the guest (if running)
- Removing High Availability (HA) configuration
- Removing replication jobs
- Deleting all snapshots
- Removing all backup files (vzdump)
- Removing all storage volumes
- Deleting the configuration file
- Verifying complete removal

---

## Requirements

### System Requirements
- **Proxmox VE 8.x** (Debian 12 Bookworm) or **9.x** (Debian 13 Trixie)
- Root access to the Proxmox host
- Internet connectivity (for curl deployment)

### Permissions
- Must be run as `root`
- SSH access to the Proxmox host (if running remotely)

---

## Installation & Execution

### One-Line Installation

Run the following command on your Proxmox VE host:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
```

### Local Execution

If you have downloaded the script:

```bash
chmod +x pve_vm_ct_cleanup.sh
./pve_vm_ct_cleanup.sh
```

---

## Understanding the Interface

### Header Display

When the script starts, you will see:
- **VANAUKEN TECH** banner in cyan
- Current hostname
- Current date and time
- Proxmox VE version
- Log file location

### VM/CT List Display

The script displays all discovered VMs and containers in a formatted table:

| Column | Description |
|--------|-------------|
| # | Selection number (enter this to select) |
| VMID | The Proxmox VM or container ID |
| Type | VM (virtual machine) or CT (container) |
| Name | The guest name |
| Status | Running (green) or Stopped (yellow) |
| Memory | Allocated memory in GB |
| CPUs | Number of vCPUs assigned |

---

## Step-by-Step Usage Guide

### Step 1: Launch the Script

Execute the curl one-liner or run the script locally.

### Step 2: Review Preflight Checks

The script automatically verifies:
- ✔ Running as root
- ✔ Proxmox VE is detected
- ✔ Backup storage locations discovered

### Step 3: View Available Guests

All VMs and containers on the current node are displayed in a numbered list.

### Step 4: Select Guest to Remove

Enter the **number** (not VMID) from the list to select the guest you want to destroy.

Example: If "medusa" is listed as `[3]`, enter `3` to select it.

Enter `q` to quit without making changes.

### Step 5: Review Analysis

The script analyzes the selected guest and displays:
- Current status (running/stopped)
- Number of snapshots
- Number of backups found
- Number of storage volumes
- HA configuration status
- Replication configuration status

### Step 6: Confirm Destruction

**Two confirmations are required:**

1. **First Confirmation**: Type the exact VMID number
2. **Second Confirmation**: Type `DESTROY` (all caps)

Both must match exactly. Any other input aborts the operation.

### Step 7: Monitor Progress

The script executes each cleanup step with visible progress indicators:
- ◆ (cyan diamond) — Operation in progress
- ✔ (green checkmark) — Operation completed
- ⚠ (yellow warning) — Non-critical warning
- ✘ (red X) — Error occurred

### Step 8: Review Summary

After completion, a detailed summary shows:
- Guest details (Type, VMID, Name)
- All operations completed
- Log file location

---

## Confirmation Process

The script uses a **multi-layer confirmation** process to prevent accidental destruction:

### Warning Display

Before selection, a prominent red warning box explains:
- This operation is **completely irreversible**
- All data will be **permanently destroyed**
- There is **no undo**

### First Confirmation

After reviewing the removal plan, you must type the exact VMID:

```
Type the VMID (105) to confirm destruction: 105
```

### Second Confirmation

A final confirmation requires typing `DESTROY`:

```
Final confirmation — Type  DESTROY  to proceed: DESTROY
```

**Any typo or incorrect entry aborts the operation with no changes made.**

---

## Operations Performed

### Step 1: Stop Guest
- Gracefully stops the VM/CT if running
- Uses timeout of 60 seconds
- Force stops if graceful shutdown fails

### Step 2: Remove HA Configuration
- Removes the guest from Proxmox High Availability
- Prevents HA from trying to restart the guest

### Step 3: Remove Replication Jobs
- Removes all replication jobs associated with the VMID
- Cleans up replication metadata

### Step 4: Remove Snapshots
- Iterates through all snapshots
- Deletes each snapshot with `--force` flag
- Skips the "current" pseudo-snapshot

### Step 5: Remove Backups
- Searches all discovered backup storage locations
- Removes vzdump files matching the VMID pattern
- Removes associated .log, .notes, .fidx, .didx files

### Step 6: Remove Storage Volumes
For VMs:
- Removes SCSI, SATA, VirtIO, IDE disks
- Removes EFI disk
- Removes TPM state
- Removes unused disks

For Containers:
- Removes rootfs
- Removes all mount points (mp0, mp1, etc.)

### Step 7: Delete Guest
- Executes `qm destroy` (VM) or `pct destroy` (CT)
- Uses `--purge` to remove all resources
- Uses `--skiplock` / `--force` flags
- Removes residual config files if present

### Step 8: Verify Removal
- Confirms guest no longer exists in API
- Verifies config file is removed
- Checks for remaining backups
- Confirms HA removal

---

## Log Files

All operations are logged to:

```
/var/log/pve_vm_ct_cleanup_YYYYMMDD_HHMMSS.log
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

### "pvesh not found"
This script requires Proxmox VE. Ensure you are running on a Proxmox host.

### "No VMs or containers found"
The script only scans the local node. If your guests are on a different cluster node, SSH to that node.

### Guest fails to stop
- Check if the guest has a stuck QEMU process
- Use `ps aux | grep <vmid>` to find processes
- May need manual intervention: `kill -9 <pid>`

### Storage volumes fail to remove
- Check if storage is locked
- Verify storage backend is accessible
- Check `/var/log/pve-storage.log` for errors

### Backups not being removed
- Check backup storage permissions
- Verify backup paths are accessible
- PBS (Proxmox Backup Server) backups require separate cleanup

---

## Safety Features

### No Auto-Approval
Every destruction requires explicit user confirmation.

### Multi-Layer Confirmation
Two separate confirmations required (VMID + "DESTROY").

### Clear Warnings
Large, prominent warning boxes in red clearly explain risks.

### Non-Destructive Abort
Entering `q` or incorrect confirmation text aborts immediately with no changes.

### Comprehensive Logging
Full audit trail of all operations performed.

### Verification Step
Script confirms complete removal after destruction.

---

## Production Use

This script is designed for **enterprise and production use**:

- ✔ Thoroughly tested
- ✔ Handles edge cases
- ✔ Graceful error handling
- ✔ Complete audit logging
- ✔ Multi-layer safety confirmations
- ✔ Supports PVE 8.x and 9.x

---

*Van Auken Tech · Thomas Van Auken*
