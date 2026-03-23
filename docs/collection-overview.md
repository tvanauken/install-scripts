# Van Auken Tech — Install Scripts Collection
### Thomas Van Auken — Van Auken Tech
**Repository:** https://github.com/tvanauken/install-scripts
**Host:** atlas.mgmt.home.vanauken.tech · Proxmox VE 9.1.6 · Debian Trixie

---

## What This Repository Is

A collection of custom scripts for Proxmox VE system builds, all adhering to the **Van Auken Tech standard** for script design and visual presentation. Every script in this collection shares a unified look, feel, and behaviour so that any operator familiar with one script is immediately comfortable running any other.

Scripts are modelled after the [Proxmox VE Community Scripts](https://community-scripts.org/scripts) and are designed to be run directly on Proxmox VE hosts as root.

---

## Scripts in This Collection

| Script | Directory | Purpose |
|--------|-----------|--------|
| CLI Tools Installer | [`cli-tools/`](../cli-tools/) | Installs 46 CLI tools + X11 deps on a PVE host |
| PVE Drive Cleanup & Init | [`pve-drive-init/`](../pve-drive-init/) | Wipes drives with remnant data for fresh deployment |
| Drive Inventory Generator | [`drive-inventory/`](../drive-inventory/) | Scans all drives and generates a markdown inventory report |

---

## The Van Auken Tech Standard

Every script in this collection must conform to the following standard. This ensures consistency, readability, and professionalism across all tools.

### Visual Identity

| Element | Specification |
|---------|---------------|
| Header | figlet "small" font — `VANAUKEN TECH` in cyan/bold |
| Subtitle | Script-specific title line below header |
| Host / Date / PVE / Log | Printed below header on every run |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` (no hardcoded ANSI strings) |
| Section dividers | `── Section Name ──────────────────────────...` (cyan/bold) |
| Progress: in-progress | `◆  message...` (cyan) |
| Progress: success | `✔  message` (green) |
| Progress: warning | `⚠  message` (yellow) |
| Progress: error | `✘  message` (red) |
| Progress: item/drive | `[▸] item...` (cyan) |
| Completion block | `════════════...` style (cyan/bold) |
| Footer | `────────────...` with host + timestamp (dark green) |
| Attribution | `Created by: Thomas Van Auken — Van Auken Tech` in every footer |

### Code Standard

| Requirement | Specification |
|-------------|---------------|
| Shebang | `#!/usr/bin/env bash` |
| Shell | bash only (not sh or zsh) |
| Error handling | `set -o pipefail` minimum; add `set -e` only where appropriate |
| Cleanup trap | `trap cleanup EXIT` — resets terminal cursor on exit/interrupt |
| Root check | Every script checks `$EUID -ne 0` and exits with a clear error |
| Dependency install | Missing tools auto-installed via `apt-get` with a hard-verify pass after |
| Log file | Every script writes a timestamped log to `/var/log/` |
| Non-interactive apt | Always use `DEBIAN_FRONTEND=noninteractive apt-get install -y` |
| No `--no-install-recommends` | Full installs — do not strip recommended packages |
| Attribution | Script header comment must include author, version, date, repo URL |

### Documentation Standard

Every script directory must contain:

```
<script-dir>/
├── <script-name>.sh       — the script itself
├── README.md              — short overview + one-liner usage command
└── docs/
    ├── user-manual.md     — comprehensive user guide
    └── build-log.md       — action log from creation and testing
```

---

## Repository Structure

```
install-scripts/
├── README.md                              Collection index
├── docs/
│   └── collection-overview.md             This document
├── cli-tools/
│   ├── cli-tools-install.sh
│   ├── README.md
│   └── docs/
│       ├── user-manual.md
│       └── build-log.md
├── pve-drive-init/
│   ├── drive_init.sh
│   ├── README.md
│   └── docs/
│       ├── user-manual.md
│       └── build-log.md
└── drive-inventory/
    ├── generate_drive_inventory.sh
    ├── README.md
    └── docs/
        ├── user-manual.md
        └── build-log.md
```

---

## Quick Reference — One-Liners

### Install CLI Tools
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

### Wipe Drives for Redeployment
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

### Generate Drive Inventory Report
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

> **Note:** These one-liners require the repository to be set to **Public** in GitHub settings.

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
