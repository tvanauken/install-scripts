# PVE Drive Cleanup & Initialization — User Manual
### Van Auken Tech · Thomas Van Auken
**Script:** `drive_init.sh`
**Version:** 3.0
**Compatibility:** Proxmox VE 8.x / 9.x · Debian Bookworm / Trixie

---

## Purpose

This script prepares drives for fresh deployment on a Proxmox VE host. It scans all drives in the server, identifies those containing remnant data from a previous system (ZFS pools, LVM/Ceph volumes, old partition tables, mdadm RAID superblocks), and performs a thorough 7-step multi-pass wipe on each one.

**System drives are always protected.** The script never touches the Proxmox OS, boot drives, mounted filesystems, the `pve` LVM volume group, active ZFS pools, or USB drives.

> **This operation is irreversible. All data on target drives will be permanently destroyed.**

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Operating System | Proxmox VE 8.x or 9.x |
| User | Must be run as **root** |
| State | Drives to be wiped must not be in use by running VMs/containers |
| Internet | Required for auto-installing missing tools |

---

## Running the Script

### One-liner
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

### Download and run
```bash
wget -O drive_init.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh
chmod +x drive_init.sh
./drive_init.sh
```

---

## What You Will See

### 1. Header
The VANAUKEN TECH ASCII banner with host, date, PVE version, and log file path.

### 2. Preflight Checks
- Root verification
- Proxmox version detection
- Auto-installs any missing tools: `gdisk`, `lvm2`, `parted`, `mdadm`, `lsscsi`
- Hard-verifies all required binaries exist before proceeding

### 3. Scanning Drives
Builds two lists silently:
- **Protected drives** — must never be touched
- **Target drives** — will be wiped

### 4. Execution Plan
Before any action is taken, the full plan is displayed:

```
  ╔══════════════════════════════════════════════════════════════╗
  ║         EXECUTION PLAN — REVIEW BEFORE PROCEEDING           ║
  ╚══════════════════════════════════════════════════════════════╝

  PROTECTED — will NOT be touched:
      ✔  /dev/nvme0n1    1.8T    nvme   Samsung SSD 970 EVO Plus 2TB
      ✔  /dev/sda        894.3G  ??     INTEL SSDSC2KG960G8

  TARGET — ALL DATA WILL BE PERMANENTLY DESTROYED:
      ✘  /dev/sdb        1.1T    ??     ST1200MM0088    SN: Z401...
      ✘  /dev/sdc        1.1T    ??     ST1200MM0088    SN: Z401...
```

Review this carefully. If any drive appears in the wrong list, **do not proceed** — type anything other than `YES` to abort safely.

### 5. Confirmation Gate
```
  Type  YES  to proceed (anything else aborts):
```
Only the exact string `YES` (uppercase) proceeds. Any other input — including `yes`, `y`, Enter alone — aborts with no changes made.

### 6. Execution (Steps 1–7)

| Step | What Happens |
|------|--------------|
| 1 | Stops all running VMs and LXC containers |
| 2 | Exports or destroys ZFS pools on target drives; clears all ZFS labels |
| 3 | Removes all LVM volume groups and PV labels on target drives (never the `pve` VG) |
| 4 | Stops mdadm RAID arrays and zeros superblocks |
| 5 | Unmounts any stray filesystems on target drives |
| 6 | Full 7-sub-step wipe per drive (see Wipe Sequence below) |
| 7 | Verifies each drive is fully clean |

### 7. Wipe Sequence (per drive)
For each target drive, the following operations run in order:

| Sub-step | Command | Removes |
|----------|---------|--------|
| 6a | `wipefs -a -f` on each partition | Partition-level signatures |
| 6b | `wipefs -a -f` on whole disk | Disk-level signatures |
| 6c | `sgdisk --zap-all` | GPT partition table + MBR |
| 6d | `dd` zero — first 200 MB | MBR, GPT header, ZFS labels 0+1, LVM metadata, Ceph OSD, mdadm |
| 6e | `dd` zero — last 200 MB | Backup GPT, ZFS labels 2+3 |
| 6f | `wipefs` second pass | Anything re-surfaced after the zap |
| 6g | `partprobe` / `blockdev --rereadpt` | Flushes kernel partition table cache |

### 8. Verification
Each target drive is checked:
- `blkid` — looks for any remaining filesystem or partition signatures
- Partition count — checks no partitions are still visible to the kernel
- LVM — checks for residual PV labels

Each drive is reported as:
```
    /dev/sdb                                ✔ Clean
    /dev/sdc                                ✔ Clean
```

### 9. Completion Summary
The Van Auken Tech completion block prints with the log file path.

---

## Log File

All output is simultaneously written to the terminal and:
```
/var/log/drive_init_YYYYMMDD_HHMMSS.log
```

---

## Safety Notes

- **Always review the Execution Plan** before typing `YES`
- Transport type `??` for HBA-connected drives is normal — `lsblk` cannot determine transport for drives on LSI/SAS HBAs. The protection logic still works correctly.
- Verification warnings about residual blkid signatures after wiping are typically harmless stale kernel cache entries — the `dd` zero passes have already destroyed the data regardless.
- Do not run this script on a host with production VMs unless you intend to stop them

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| System drive appears as target | Drive detection issue | Abort immediately, do not proceed |
| `YES` prompt not appearing | Script aborted during scan | Check output for error messages |
| Drive shows `✘ Issues found` after wipe | Stale kernel cache | Usually harmless; reboot and verify |
| `Could not stop VM` warning | VM in locked state | Stop VM manually, then re-run |

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
