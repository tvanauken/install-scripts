# PVE Drive Cleanup & Initialization
### Van Auken Tech · Thomas Van Auken

> Part of the [Van Auken Tech Install Scripts Collection](../README.md)

---

## Overview

Scans ALL drives in a Proxmox VE server, identifies those containing remnant data from a previous system, and performs a thorough multi-pass wipe to prepare them for fresh deployment in Proxmox or TrueNAS.

## Safety

**PROTECTED — never touched:** root drive, all mounts, `pve` LVM VG, active ZFS pools, USB

**TARGET — will be wiped:** any SAS/SATA/NVMe drive not in the protected list

## Usage

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

Displays full execution plan with protected (green ✔) and target (red ✘) drives, then requires `YES` to proceed.

---
*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
