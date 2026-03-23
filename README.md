# Van Auken Tech — Install Scripts

> Created by: Thomas Van Auken — Van Auken Tech

A collection of Proxmox VE helper/installer scripts styled after the [Proxmox VE Community Scripts](https://community-scripts.org/scripts). Each script features a colourised terminal UI, section-by-section progress output, post-install tasks, verification, and a full colour summary.

## Scripts

| Script | Description |
|--------|-------------|
| [cli-tools/cli-tools-install.sh](cli-tools/cli-tools-install.sh) | Installs 46 CLI tools + X11 dependencies on a Proxmox VE host |

## Usage

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/tvanauken/install-scripts.git
bash install-scripts/cli-tools/cli-tools-install.sh
```

## Requirements

- Proxmox VE 8.x / 9.x (Debian Bookworm or Trixie)
- Root access
- Internet connectivity

---
*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
