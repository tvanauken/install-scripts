# Van Auken Tech — Install Scripts Collection

> Created by: Thomas Van Auken — Van Auken Tech

A collection of Proxmox VE helper and utility scripts for `atlas.mgmt.home.vanauken.tech` and any Proxmox VE host. All scripts share a unified visual identity modelled after the [Proxmox VE Community Scripts](https://community-scripts.org/scripts).

---

## Scripts

### 1. CLI Tools Installer
**Directory:** [`cli-tools/`](cli-tools/)
**Script:** [`cli-tools-install.sh`](cli-tools/cli-tools-install.sh)

Installs and verifies **46 CLI tools** on a Proxmox VE host across five categories: system monitoring, storage, networking, shell/dev tools, and X11 display dependencies.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

---

### 2. PVE Drive Cleanup & Initialization
**Directory:** [`pve-drive-init/`](pve-drive-init/)
**Script:** [`drive_init.sh`](pve-drive-init/drive_init.sh)

Scans all drives, identifies remnant data from previous systems (ZFS, LVM, Ceph, mdadm, old partition tables), and performs a thorough 7-step multi-pass wipe. System drives are always protected. Requires a single `YES` confirmation before any data is touched.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

---

### 3. Drive Inventory Report Generator
**Directory:** [`drive-inventory/`](drive-inventory/)
**Script:** [`generate_drive_inventory.sh`](drive-inventory/generate_drive_inventory.sh)

Scans all storage devices and generates a comprehensive markdown inventory report — drive count, capacity totals, media classification, serial numbers, storage topology, LVM, and ZFS pool status. Live per-drive progress shown in terminal.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

---

## Visual Standard

All scripts share the same Van Auken Tech visual identity:

| Element | Style |
|---------|-------|
| Header | figlet "small" font — VANAUKEN TECH |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` |
| Section dividers | `── Section Name ──────────...` (cyan/bold) |
| Status symbols | ✔ green · ✘ red · ⚠ yellow · ◆ cyan · ▸ cyan |
| Summary block | `════════` style (cyan/bold) |
| Footer | `────────` with host + timestamp |

## Requirements

- Proxmox VE 8.x (Debian Bookworm) or 9.x (Debian Trixie)
- Root access
- Internet connectivity
- Missing dependencies are auto-installed by each script

---

*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
