# PVE VM & CT Cleanup — Build Log

> Created by: Thomas Van Auken — Van Auken Tech
> Version: 1.0.0
> Date: 2026-04-18

---

## Build Summary

| Item | Details |
|------|---------|
| Script Name | `pve_vm_ct_cleanup.sh` |
| Version | 1.0.0 |
| Build Date | 2026-04-18 |
| Target Platform | Proxmox VE 8.x / 9.x |
| Lines of Code | ~750 |
| Author | Thomas Van Auken |

---

## Development Timeline

### 2026-04-18 — Initial Development

#### Phase 1: Requirements Analysis
- Analyzed existing Van Auken Tech script standards from `pve_node_remove.sh`
- Identified visual standards: figlet banner, color palette, section dividers, status symbols
- Defined complete cleanup operations based on Proxmox VE best practices:
  - Stop guest
  - Remove HA configuration
  - Remove replication jobs
  - Delete snapshots
  - Delete backups (vzdump)
  - Remove storage volumes
  - Delete configuration
  - Verify removal

#### Phase 2: Script Development
- Created directory structure: `pve-vm-ct-cleanup/` with `docs/` subdirectory
- Implemented color palette matching existing scripts:
  - `RD` (red) — Errors, warnings, destruction confirmations
  - `YW` (yellow) — Warnings
  - `GN` (green) — Success messages
  - `DGN` (dark green) — Metadata
  - `BL` (cyan/blue) — Info, headers, boxes
  - `CL` (clear) — Reset
  - `BLD` (bold) — Emphasis
- Created VANAUKEN TECH ASCII banner header
- Implemented helper functions: `msg_info`, `msg_ok`, `msg_warn`, `msg_error`, `section`

#### Phase 3: Core Functionality
- Implemented VM discovery via `pvesh get /nodes/<node>/qemu`
- Implemented CT discovery via `pvesh get /nodes/<node>/lxc`
- Created formatted table display with columns: #, VMID, Type, Name, Status, Memory, CPUs
- Implemented sorting by VMID
- Created backup storage discovery function scanning:
  - Configured storage via `pvesh get /storage`
  - Common paths: `/var/lib/vz/dump`, `/mnt/pve/*/dump`

#### Phase 4: Selection Interface
- Built interactive selection menu
- Implemented input validation (numeric, range check)
- Added quit option (`q`)
- Created prominent warning display with ASCII box art

#### Phase 5: Guest Analysis
- Implemented status retrieval
- Snapshot counting (excluding "current" pseudo-snapshot)
- Backup file counting across all storage locations
- Storage volume counting (VM: scsi, sata, virtio, ide, efidisk, tpmstate; CT: rootfs, mp*)
- HA configuration detection
- Replication configuration detection

#### Phase 6: Confirmation System
- Implemented two-layer confirmation:
  1. Exact VMID entry
  2. `DESTROY` keyword
- Created large ASCII "DANGER" banner
- Detailed removal plan display

#### Phase 7: Cleanup Operations
- **Step 1: Stop Guest**
  - Graceful stop with 60-second timeout
  - Force stop fallback
  - Status verification loop
- **Step 2: Remove HA**
  - Detection via `/cluster/ha/resources`
  - Removal via `ha-manager remove`
- **Step 3: Remove Replication**
  - Detection via `/cluster/replication`
  - Removal via `pvesr delete`
- **Step 4: Remove Snapshots**
  - Iteration via snapshot API
  - Forced deletion
- **Step 5: Remove Backups**
  - File pattern matching: `*-<VMID>-*`
  - Removal of associated files (.log, .notes, .fidx, .didx)
- **Step 6: Remove Storage**
  - VM: Delete all disk types via `qm set --delete`
  - CT: Delete all mount points via `pct set --delete`
- **Step 7: Delete Guest**
  - `qm destroy --purge --skiplock` (VM)
  - `pct destroy --purge --force` (CT)
  - Residual config file cleanup
- **Step 8: Verify Removal**
  - API existence check
  - Config file check
  - Remaining backup check
  - HA configuration check

#### Phase 8: Summary Display
- Created formatted summary boxes
- Listed all completed operations
- Displayed log file location
- Added footer with credits

#### Phase 9: Documentation
- Created `README.md` with quick start guide
- Created comprehensive `user-manual.md` with:
  - Table of contents
  - Step-by-step usage guide
  - Confirmation process explanation
  - Operations breakdown
  - Troubleshooting section
  - Safety features description
- Created `build-log.md` (this document)

---

## Technical Decisions

### Why Multi-Layer Confirmation?
Production environments require protection against accidental destruction. The two-layer confirmation (VMID + "DESTROY") ensures:
1. User has identified the correct target
2. User explicitly acknowledges the destructive action

### Why Not Use `qm destroy --purge` Alone?
The `--purge` flag removes storage but does not:
- Remove backups (vzdump files)
- Remove HA configuration
- Remove replication jobs
- Provide verification of removal

### Why Scan Backup Paths?
Proxmox does not provide a single API to list all backups for a VMID. Scanning configured storage paths ensures complete cleanup.

### Why Force Flags?
Locked guests or stuck processes can prevent normal destruction. Force flags ensure the script can complete even with abnormal guest states.

---

## Testing Performed

### Environment
- Proxmox VE 8.x (Debian 12 Bookworm)
- Single-node and cluster configurations

### Test Cases
1. ✔ Running VM destruction
2. ✔ Stopped VM destruction
3. ✔ Running CT destruction
4. ✔ Stopped CT destruction
5. ✔ VM with snapshots
6. ✔ VM with backups
7. ✔ VM with multiple disks (SCSI, SATA, EFI)
8. ✔ CT with mount points
9. ✔ Abort on incorrect VMID entry
10. ✔ Abort on missing "DESTROY" confirmation
11. ✔ Quit via 'q' option
12. ✔ Non-root execution (correctly rejected)
13. ✔ Non-Proxmox system (correctly rejected)
14. ✔ Empty node (no VMs/CTs)

---

## Files Created

| File | Purpose |
|------|---------|
| `pve_vm_ct_cleanup.sh` | Main script |
| `README.md` | Quick start guide |
| `docs/user-manual.md` | Comprehensive user documentation |
| `docs/build-log.md` | Development and testing log |

---

## Integration with Repository

### Repository Updates Required
1. Update `README.md` (root) — Add script to collection index
2. Update `docs/collection-overview.md` — Add to Scripts table and Quick Reference

### Curl One-Liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04-18 | Initial release |

---

*Van Auken Tech · Thomas Van Auken*
