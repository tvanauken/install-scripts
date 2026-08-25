# Van Auken Tech - Houston / 45Drives - Universal Installer

This directory contains the universal, forward-compatible installer for the Van Auken Tech branded Houston UI and Cockpit management system. It dynamically adapts to Ubuntu 20.04, 22.04, and 24.04+ environments.

## Features
- **Dynamic APT Pinning:** Automatically detects modern Ubuntu releases to resolve package conflicts between 45Drives repos and native OS libraries.
- **Environment Targeting:** Automatically adjusts installed packages for Baremetal vs. VM environments.
- **Hardware Spoofing:** Dynamically patches the backend Python identification scripts to render perfect 2D chassis layouts for VMs with passed-through HBAs.
- **Deterministic Booting:** Eradicates NetworkManager and surgically removes deprecated ZFS udev-settle dependencies to prevent boot hangs and maintenance mode drops.
- **Custom Branding:** High-resolution SVG logos and CSS themes for a professional Van Auken Tech login experience.

## Usage

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/houston-ui-universal/houston-universal-v1.0.0.sh)"
```

## Documentation
- [Build & Validation Log](docs/build-log.md)
- [Engineering Manual](docs/engineering-manual.md)
- [User Manual](docs/user-manual.md)
