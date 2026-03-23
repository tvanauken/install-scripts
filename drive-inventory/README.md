# Drive Inventory Report Generator
### Van Auken Tech · Thomas Van Auken

> Part of the [Van Auken Tech Install Scripts Collection](../README.md)

---

## Overview

Scans all storage devices on a Proxmox VE server and generates a comprehensive markdown inventory report with live per-drive terminal progress.

## Usage

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

Report saved to `./drive_inventory_<hostname>_<timestamp>.md` in the current directory. An SCP download command is printed at the end.

---
*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
