# PVE VM & CT Cleanup

> Created by: Thomas Van Auken — Van Auken Tech

**Complete removal of VMs and containers from Proxmox VE**, including all associated storage volumes, snapshots, backups, HA configuration, and replication jobs.

---

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
```

---

## Features

- **Interactive Selection** — Lists all VMs and CTs with VMID, name, status, memory, and CPUs
- **Complete Cleanup** — Removes storage, snapshots, backups, HA, and replication
- **Multi-Layer Confirmation** — Requires VMID entry + "DESTROY" confirmation
- **Detailed Logging** — Full operation log saved to `/var/log/`
- **Verification** — Confirms complete removal after destruction

---

## ⚠️ WARNING

**THIS OPERATION IS IRREVERSIBLE.** All data will be permanently destroyed:
- Virtual disks and storage volumes
- All snapshots
- All backups (vzdump files)
- Configuration files
- HA and replication settings

**THERE IS NO UNDO. DATA CANNOT BE RECOVERED.**

---

## Requirements

- Proxmox VE 8.x (Debian 12 Bookworm) or 9.x (Debian 13 Trixie)
- Root access
- Internet connectivity (for curl deployment)

---

## Documentation

- [User Manual](docs/user-manual.md) — Comprehensive usage guide
- [Build Log](docs/build-log.md) — Development and testing log

---

*Van Auken Tech · Thomas Van Auken*
