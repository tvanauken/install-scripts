# Van Auken Tech - Houston / 45Drives - Universal Installer - Build & Validation Log

## Engineering Summary
This document logs the development, refinement, and final validation of the `houston-universal-v1.0.0.sh` script (v1.0.0) used to deploy the Van Auken Tech - Houston / 45Drives - Universal Installer onto Ubuntu systems.

### The Challenge
1. **OS Compatibility:** 45Drives officially supports Ubuntu 20.04 and 22.04. Ubuntu 24.04 (Noble Numbat) introduces newer native libraries (such as `samba` and `libldb2`) that conflict with the 45Drives `jammy` repositories.
2. **Network Protocol Stability:** Ubuntu 24.04 Server utilizes `systemd-networkd` by default. Previous iterations attempted to force `NetworkManager` for GUI compatibility, which caused catastrophic timeouts during `systemd` boot sequences when waiting for storage arrays to spin up.
3. **PackageKit Race Condition:** In environments without `NetworkManager`, the PackageKit daemon defaults to reporting "offline", causing Cockpit Software Updates to fail (Cockpit Bug #16963).
4. **VM Hardware Spoofing & IOMMU Passthrough:** When deploying inside a Proxmox VM with an HBA passed through, the `45drives-disks` module's Python backend (`lsdev`) would crash or crop the 2D chassis graphic because the virtual QEMU motherboard lacks IPMI sensors and physical DMI data. Hardcoding the JSON file broke dynamic PCI bus scanning, preventing future HBA upgrades from being detected automatically.

### The Solution (Universal Implementation)
1. **Dynamic APT Pinning:** The script dynamically detects the OS version. If Ubuntu 24.04+, it injects `/etc/apt/preferences.d/45drives.pref` with a priority of `1000` for `cockpit-*` packages, forcing the UI to pull from 45Drives, while explicitly dropping priority for all other packages to `-1`. This allows modern Ubuntu to use its native, stable backend dependencies (`samba`, `zfsutils-linux`).
2. **Native Networkd Enforcement & PackageKit Fix:** The installer permanently abolishes `NetworkManager` manipulation. By completely purging `network-manager`, `network-manager-gnome`, `modemmanager`, `wpasupplicant`, and `cockpit-networkmanager`, PackageKit is forced to gracefully fallback to native systemd-networkd routing checks. This inherently solves the 'offline' bug without DBus timeouts or boot hangs.
3. **Dynamic VM Hardware Spoofing (Python Patching):** The script dynamically patches the core `/opt/45drives/tools/server_identifier` script. It permanently leaves `/etc/45drives/server_info/server_info.json` in `"Edit Mode": false`. When the system boots, the script naturally scans the isolated IOMMU PCI bus to detect LSI HBAs and connected drives. Right before writing the JSON file, the Python injection forcefully overwrites the QEMU motherboard generic fallback with the exact requested 45Drives chassis model (e.g., `Storinator-S45`). This guarantees future HBA expansions are discovered natively without breaking the 2D chassis UI.
4. **Libvirt Bridge Destruction:** When installed as a VM, the script automatically destroys and disables the `virbr0` default network bridge spawned by virtualization dependencies (by intentionally purging `cockpit-machines`, `cockpit-podman`, and `libvirt`).
5. **ZFS Boot Race Condition:** Surgically stripped deprecated `systemd-udev-settle.service` dependencies from OpenZFS unit files dynamically, preventing 120-second timeouts.
6. **Blue-Gray Aesthetic Theme:** Replaced default installer colors with a professional, highly visible Blue-Gray palette. Custom SVG branding applies the Van Auken Tech logo and background to the Cockpit login screen.

---
*Created and maintained by Thomas Van Auken - Van Auken Tech.*
