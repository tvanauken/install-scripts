# Drive Inventory Report Generator — Build Log
### Van Auken Tech · Thomas Van Auken
**Date:** 2026-03-23
**Host:** atlas.mgmt.home.vanauken.tech
**PVE Version:** 9.1.6 (Debian Trixie)
**Script:** `generate_drive_inventory.sh`
**GitHub:** https://github.com/tvanauken/install-scripts/tree/main/drive-inventory

---

## Overview

This document is the action log for the full rewrite and deployment of the Drive Inventory Report Generator on `atlas.mgmt.home.vanauken.tech`.

---

## Actions Taken

### 1. Original Script Retrieved
- User provided `generate_drive_inventory.sh` from `~/Downloads/` on their Mac
- Original script was version 2.1, approximately 390 lines
- Original used RED/GREEN/YELLOW/BLUE/NC colour variables
- Original had a simple single-line header echo
- Original had no root check, no auto-install of dependencies, no per-drive live output
- Original had no structured sections or Van Auken Tech visual identity

### 2. User Requirement
- Full rewrite to Van Auken Tech standard (not just a restyle)
- Live per-drive progress display during scan
- Proper section structure
- Auto-install of missing dependencies
- Root check
- Same markdown report output (preserved and enhanced)

### 3. Full Rewrite
Complete rewrite to Van Auken Tech standard:
- `#!/usr/bin/env bash` shebang
- Unified colour palette (RD/YW/GN/DGN/BL/CL/BLD)
- msg_info / msg_ok / msg_warn / msg_error / section() functions
- cleanup trap on EXIT
- VANAUKEN TECH figlet ASCII header
- `preflight()` — root check + auto-install (smartmontools, bc, pciutils, lsscsi)
- `gather_system_info()` — OS, PVE version, kernel, controller counts
- `scan_drives()` — per-drive live table with model, size, transport, media, serial
- `generate_report()` — full markdown report with topology, tables, LVM, ZFS sections
- `summary()` — Van Auken Tech completion block with SCP download command
- Transport colour-coding in live scan table (nvme=cyan, sas=yellow, sata=dark green, usb=green)
- Added "Other/HBA-Attached" topology section for drives with unknown transport

### 4. Bug Found and Fixed — Controller Count Display
- First test run showed: `Controllers — SATA/AHCI: 0\n0  SAS/HBA: 4  NVMe: 2`
- Root cause: `grep -ci ... || echo 0` — `grep -c` exits with code 1 when 0 matches, triggering `|| echo 0`, which doubles the output (both `0\n` from grep and `0\n` from echo; command substitution strips only the trailing newline, leaving `0\n0`)
- Fix: replaced all `grep -ci ... || echo 0` with `grep -i ... | wc -l | tr -d ' '` — `wc -l` always exits 0 and always outputs a clean count
- Fix verified on atlas using direct commit SHA URL to bypass CDN cache

### 5. Testing on atlas
- Script tested via SSH to atlas from Mac
- `bash -n` syntax check: ✔ Pass
- Full live run: ✔ Pass
- 11 drives detected and correctly classified
- All serials captured
- 8.0K markdown report generated
- SCP command printed correctly

### 6. Published
- Script published to `tvanauken/drive-inventory` (new repo)
- Script also added to `tvanauken/install-scripts` → `drive-inventory/`

---

## Test Results

| Check | Result |
|-------|--------|
| `bash -n` syntax check | ✔ Pass |
| Full live run | ✔ Pass |
| 11 drives detected | ✔ nvme0n1, nvme1n1, sda–sdi |
| Media classification | ✔ NVMe SSD, SSD, HDD correctly detected via smartctl |
| Serials captured | ✔ All 11 drives |
| Controller count (clean single line) | ✔ After wc -l fix |
| Markdown report generated | ✔ 8.0K report file |

**Drives detected on atlas:**

| Device | Model | Size | Media |
|--------|-------|------|-------|
| /dev/nvme0n1 | Samsung SSD 970 EVO Plus 2TB | 1.8T | NVMe SSD |
| /dev/nvme1n1 | Samsung SSD 970 EVO Plus 2TB | 1.8T | NVMe SSD |
| /dev/sda | INTEL SSDSC2KG960G8 | 894.3G | SSD |
| /dev/sdb | ST1200MM0088 | 1.1T | HDD |
| /dev/sdc | ST1200MM0088 | 1.1T | HDD |
| /dev/sdd | ST1200MM0088 | 1.1T | HDD |
| /dev/sde | Samsung SSD 870 EVO 1TB | 931.5G | SSD |
| /dev/sdf | Samsung SSD 870 EVO 1TB | 931.5G | SSD |
| /dev/sdg | Samsung SSD 870 EVO 1TB | 931.5G | SSD |
| /dev/sdh | Samsung SSD 870 EVO 1TB | 931.5G | SSD |
| /dev/sdi | STORE N GO (USB) | 28.9G | Unknown |

**Total: 11 drives · 11.45 TB raw**

---

## Notes

- Drives on HBA cards report transport `??` in `lsblk` — kernel/driver limitation, not a bug
- `wc -l` used for controller counts (not `grep -c`) to avoid the exit-code-1 doubling issue
- All markdown report content preserved and enhanced from original v2.1
- `set -o pipefail` retained (compatible with the report generation heredoc/append pattern)

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
