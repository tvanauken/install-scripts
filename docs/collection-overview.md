# Van Auken Tech — Install Scripts Collection
### Thomas Van Auken — Van Auken Tech
**Repository:** https://github.com/tvanauken/install-scripts

---

## What This Repository Is

A collection of custom scripts for Van Auken Tech infrastructure, all adhering to the **Van Auken Tech standard** for script design and visual presentation. Every script in this collection shares a unified look, feel, and behaviour.

Scripts 1–3 target Proxmox VE hosts directly. Script 4 targets Raspberry Pi hardware. Scripts 5–6 configure already-deployed LXC containers — install the LXC first from community-scripts.org, then run the script.

---

## Scripts in This Collection

| # | Script | Directory | Target | Purpose |
|---|--------|-----------|--------|---------|
| 1 | CLI Tools Installer | [`cli-tools/`](../cli-tools/) | Proxmox VE | Installs 46 CLI tools + X11 deps |
| 2 | PVE Drive Cleanup & Init | [`pve-drive-init/`](../pve-drive-init/) | Proxmox VE | Wipes drives with remnant data for fresh deployment |
| 3 | Drive Inventory Generator | [`drive-inventory/`](../drive-inventory/) | Proxmox VE | Scans all drives, generates markdown inventory report |
| 4 | **Raspberry Pi Setup** | [`pi-setup/`](../pi-setup/) | **Raspberry Pi** | Kali tools + XFCE desktop + performance tuning |
| 5 | Technitium DNS Server | [`dns-server/`](../dns-server/) | LXC (post-install) | Configures Technitium DNS via API after LXC is deployed |
| 6 | Nginx Proxy Manager | [`npm-reverse-proxy/`](../npm-reverse-proxy/) | LXC (post-install) | Configures NPM via API after LXC is deployed |

> ⚠ Script 4 requires **Raspberry Pi hardware** (armhf/arm64). Supported OS: Raspberry Pi OS, Ubuntu Desktop/Server, Kali Linux ARM, Debian ARM.
> NOT compatible with Proxmox VE or x86/x86_64 systems.
> Must be run with `sudo bash <(curl -s URL)` — not curl alone.

> ℹ Scripts 5–6 are **post-install configuration scripts**. Install the LXC first from [community-scripts.org](https://community-scripts.org), then run the script to configure it.

---

## The Van Auken Tech Standard

Every script must conform to the following:

### Visual Identity

| Element | Specification |
|---------|---------------|
| Header | figlet "small" font — `VANAUKEN TECH` in cyan/bold |
| Subtitle | Script-specific title line below header |
| Host / Date / Log | Printed below header on every run |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` (no hardcoded ANSI strings) |
| Section dividers | `── Section Name ──────────────────────────...` (cyan/bold) |
| Progress: in-progress | `◆  message...` (cyan) |
| Progress: success | `✔  message` (green) |
| Progress: warning | `⚠  message` (yellow) |
| Progress: error | `✘  message` (red) |
| Progress: item | `[▸] item...` (cyan) |
| Completion block | `════════════...` style (cyan/bold) |
| Footer | `────────────...` with host + timestamp (dark green) |
| Attribution | `Created by: Thomas Van Auken — Van Auken Tech` in every footer |

### Code Standard

| Requirement | Specification |
|-------------|---------------|
| Shebang | `#!/usr/bin/env bash` |
| Shell | bash only |
| Error handling | `set -o pipefail` minimum; graceful per-step failures |
| Cleanup trap | `trap cleanup EXIT` — resets terminal cursor |
| Root check | Every script checks `$EUID -ne 0` |
| Dependency install | Missing tools auto-installed via `apt-get` |
| Log file | Every script writes a timestamped log |
| Non-interactive apt | Always `DEBIAN_FRONTEND=noninteractive apt-get install -y` |
| No snap | snapd is never used; blocked at apt layer where applicable |
| Attribution | Script header comment includes author, version, date, repo URL |

### Documentation Standard

Every script directory must contain:

```
<script-dir>/
├── <script-name>.sh       — the script itself
├── README.md              — short overview + one-liner usage command
└── docs/
    ├── user-manual.md     — comprehensive user guide
    └── build-log.md       — full action log from creation, testing, and all changes
```

**Any change to a script requires immediate updates to ALL documentation files.**

---

## Repository Structure

```
install-scripts/
├── README.md
├── docs/
│   └── collection-overview.md
├── cli-tools/
│   ├── cli-tools-install.sh
│   ├── README.md
│   └── docs/
├── pve-drive-init/
│   ├── drive_init.sh
│   ├── README.md
│   └── docs/
├── drive-inventory/
│   ├── generate_drive_inventory.sh
│   ├── README.md
│   └── docs/
├── pi-setup/              ⚠ RASPBERRY PI HARDWARE — armhf/arm64 only
│   ├── pi-setup.sh
│   ├── README.md
│   └── docs/
├── dns-server/
│   ├── dns-server-install.sh
│   ├── README.md
│   └── docs/
└── npm-reverse-proxy/
    ├── npm-reverse-proxy-install.sh
    ├── README.md
    └── docs/
```

---

## Quick Reference — One-Liners

### Install CLI Tools (Proxmox VE)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

### Wipe Drives for Redeployment (Proxmox VE)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

### Generate Drive Inventory Report (Proxmox VE)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

### Raspberry Pi Setup — Kali Tools + XFCE + Performance
```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

### Configure Technitium DNS Server (post-install)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

### Configure Nginx Proxy Manager (post-install)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

> **Note:** The pi-setup one-liner requires `sudo bash <(...)` — not bare curl.
> Scripts 5–6 require the LXC to already be running. Install first from community-scripts.org.
> All one-liners require the repository to be set to **Public** in GitHub settings.

---

*Created by: Thomas Van Auken — Van Auken Tech*
