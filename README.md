# Van Auken Tech — Install Scripts Collection

> Created by: Thomas Van Auken — Van Auken Tech

A collection of helper and utility scripts for Van Auken Tech infrastructure. All scripts share a unified visual identity modelled after the [Proxmox VE Community Scripts](https://community-scripts.org/scripts).

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

### 4. Raspberry Pi Setup
**Directory:** [`pi-setup/`](pi-setup/)
**Script:** [`pi-setup.sh`](pi-setup/pi-setup.sh)

> ⚠ **RASPBERRY PI HARDWARE ONLY** (armhf / arm64)
> Supported OS: **Raspberry Pi OS**, **Ubuntu Desktop/Server**, **Kali Linux ARM**, **Debian ARM**
> NOT compatible with Proxmox VE or x86/x86_64 systems.
>
> **IMPORTANT:** Must be run with `sudo bash <(curl -s URL)` — not curl alone.

Complete Raspberry Pi setup: **40+ Kali Linux security tools**, **XFCE remote desktop** (TigerVNC on port 5901), and **full performance tuning** (CPU governor, sysctl, overclock, disabled services). Auto-detects Pi model (Pi 1/2/3B/3B+/4/5/Zero/Zero 2W) AND OS (Raspberry Pi OS / Ubuntu / Kali / Debian) and adapts all settings accordingly. **apt only — snapd explicitly blocked.**

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
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

- Scripts 1–3: Proxmox VE 8.x (Debian Bookworm) or 9.x (Debian Trixie) · Root access
- Script 4: Raspberry Pi hardware (armhf / arm64) · Raspberry Pi OS / Ubuntu / Kali Linux ARM / Debian · **sudo** required
- All scripts require internet connectivity. Missing dependencies are auto-installed.

---

*Van Auken Tech · Thomas Van Auken*
