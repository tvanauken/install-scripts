# Drive Inventory Report Generator — User Manual
### Van Auken Tech · Thomas Van Auken
**Script:** `generate_drive_inventory.sh`
**Version:** 3.0
**Compatibility:** Proxmox VE 8.x / 9.x · Debian Bookworm / Trixie

---

## Purpose

This script scans all storage devices on a Proxmox VE server and generates a comprehensive markdown inventory report. It is designed to be run at any time to capture the current state of all drives — useful for documentation, auditing, pre-deployment checks, and post-maintenance verification.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Operating System | Proxmox VE 8.x or 9.x |
| User | Must be run as **root** (required by `smartctl`) |
| Internet | Required for auto-installing missing tools |
| Working directory | The report is saved to the directory where the script is run |

---

## Running the Script

### One-liner
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

### Download and run
```bash
wget -O generate_drive_inventory.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh
chmod +x generate_drive_inventory.sh
./generate_drive_inventory.sh
```

The script requires no arguments and runs fully automatically. It takes approximately 30–90 seconds depending on the number of drives (smartctl queries each one).

---

## What You Will See

### 1. Header
The VANAUKEN TECH ASCII banner with host IP, date, PVE version, and the report file path.

### 2. Preflight Checks
- Root verification
- Auto-installs any missing tools: `smartmontools`, `bc`, `pciutils`, `lsscsi`
- Hard-verifies all required binaries

### 3. System Information
Displays detected OS, PVE version, kernel, and storage controller counts:
```
    ◆  OS       : Debian GNU/Linux 13 (trixie)
    ◆  PVE      : pve-manager/9.1.6/...
    ◆  Kernel   : 6.17.13-2-pve
    ✔  Controllers — SATA/AHCI: 0  SAS/HBA: 4  NVMe: 2
```

### 4. Scanning Drives
A live table is printed as each drive is scanned:
```
  Device          Model                             Size      Type    Media       Serial
  ──────────────  ────────────────────────────────  ────────  ──────  ──────────  ──────────────────────
  ✔  /dev/nvme0n1    Samsung SSD 970 EVO Plus 2TB      1.8T      nvme    NVMe SSD    S59CNM0W716911V
  ✔  /dev/sdb        ST1200MM0088                      1.1T      ??      HDD         Z4018YXT0000C733V0D2
```

Transport type is colour-coded: **NVMe** = cyan, **SAS** = yellow, **SATA** = dark green, **USB** = green.

Transport type `??` means the drive is connected via an HBA card — this is normal for SAS drives.

### 5. Generating Report
The markdown report file is written to the current directory.

### 6. Completion Summary
```
  ════════════════════════════════════════════════════════════════
       INVENTORY COMPLETE — Van Auken Tech
  ════════════════════════════════════════════════════════════════

  Total Drives    :  11
  Total Capacity  :  11.45 TB

  NVMe        2 drives  3.63 TB
  SAS         0 drives  0.00 TB
  SATA        0 drives  0.00 TB
  Other       8 drives  7.78 TB

  Report File     :  ./drive_inventory_atlas_20260323_104840.md  (8.0K)

  To download to your local machine:
  scp root@192.168.200.80:/root/drive_inventory_atlas_20260323_104840.md ~/Downloads/
```

Copy and run the `scp` command on your Mac to download the report.

---

## The Markdown Report

The generated `.md` file contains:

| Section | Contents |
|---------|----------|
| Executive Summary | OS, PVE version, kernel, total drives, total capacity |
| Drive Count by Type | Table: NVMe / SAS / SATA / USB / Other with counts and TB |
| Storage Controllers | SATA/AHCI, SAS/HBA, NVMe controller counts |
| Controller Details | Full `lspci` listing of storage controllers |
| Visual Topology | ASCII diagram per transport type showing controller → device |
| Detailed Drive Inventory | Full table: device, size, transport, model, serial, media type, RPM |
| Block Device Overview | `lsblk` output showing partitions, filesystems, mount points |
| LVM Physical Volumes | `pvs` output |
| LVM Volume Groups | `vgs` output |
| ZFS Pools | `zpool list` output |
| Report Information | Script version, host, timestamp |

---

## Downloading the Report to Your Mac

The script prints a ready-made `scp` command at the end. Example:
```bash
scp root@192.168.200.80:/root/drive_inventory_atlas_20260323_104840.md ~/Downloads/
```
Run this on your Mac to download the report to `~/Downloads/`.

---

## Log File

```
/var/log/drive_inventory_YYYYMMDD_HHMMSS.log
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Must be run as root` | Not running as root | Run as root or with `sudo` |
| Drive shows `??` transport | HBA-connected drive | Normal — no fix needed |
| Drive shows `Unknown` media | smartctl cannot access drive | Check if drive responds to `smartctl -i /dev/sdX` |
| Report not generated | Disk space or permissions | Check current directory is writable |
| Capacity shows 0 TB for SAS/SATA | All HBA drives fall under "Other" | Expected — HBA drives show `??` transport |

---

## Notes

- Drives on HBA cards report transport `??` via `lsblk` — this is a kernel/driver limitation. `smartctl` still correctly identifies media type (SSD vs HDD) and RPM regardless.
- The script can be run repeatedly — each run generates a new timestamped report file
- Running the script with fewer drives (e.g. after removing drives) generates a new accurate report

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
