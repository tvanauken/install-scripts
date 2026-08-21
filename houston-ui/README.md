# 45Drives Houston UI & Cockpit Installer
**Created by:** Thomas Van Auken — Van Auken Tech

## Overview
This script provides an interactive, bulletproof installation of the 45Drives Houston UI and its associated Cockpit plugins. It natively supports both bare-metal 45Drives hardware and Virtual Machine (Proxmox/ESXi) deployments utilizing HBA passthrough.

### Features
*   **Automatic OS Detection:** Supports Ubuntu/Debian (`apt`) and RHEL/Rocky Linux (`dnf`).
*   **VM Hardware Spoofing:** Interactively prompts for the chassis size (e.g., S45, Q30, HL15) and generates a locked `server_info.json` configuration, bypassing the standard IPMI/SMBIOS hardware detection failures in virtualized environments.
*   **Service Optimization:** Automatically masks and disables `openipmi` on virtual machines to prevent boot delays and systemd service failures.
*   **Visual Interface:** Utilizes `whiptail` for a clean, professional CLI configuration wizard.

## Quick Start
Run the following one-liner on the target machine as root:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/houston-ui/install.sh)"
```

## Documentation
*   [User Manual](docs/user-manual.md)
*   [Build Log](docs/build-log.md)