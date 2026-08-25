# Van Auken Tech - Houston / 45Drives - Ubuntu 24.04 LTS - Jammy Installer - Build & Validation Log

## Engineering Summary
This document logs the development, refinement, and final validation of the `houston-jammy-v6.0.0.sh` script (v6.0.0) used to deploy the Van Auken Tech - Houston / 45Drives - Ubuntu 24.04 LTS - Jammy Installer onto Ubuntu 24.04 LTS - (Jammy) systems.

### The Challenge
1. **OS Compatibility:** 45Drives officially supports Ubuntu 20.04 and 22.04. Ubuntu 24.04 (Noble Numbat) introduces newer native libraries (such as `samba` and `libldb2`) that conflict with the 45Drives `jammy` repositories.
2. **Network Protocol Stability:** Ubuntu 24.04 Server utilizes `systemd-networkd` by default. Previous iterations attempted to force `NetworkManager` for GUI compatibility, which caused catastrophic timeouts during `systemd` boot sequences when waiting for storage arrays to spin up.
3. **VM Hardware Spoofing & IOMMU Passthrough:** When deploying inside a Proxmox VM with an HBA passed through, the `45drives-disks` module's Python backend (`lsdev`) would crash or crop the 2D chassis graphic because the virtual QEMU motherboard lacks IPMI sensors and physical DMI data. Hardcoding the JSON file broke dynamic PCI bus scanning, preventing future HBA upgrades from being detected automatically.

### The Solution (V6 Implementation)
1. **Strict APT Pinning:** The script injects `/etc/apt/preferences.d/45drives.pref` with a priority of `1000` for `cockpit-*` packages, forcing the UI to pull from 45Drives, while explicitly dropping priority for all other packages to `-1`. This allows Ubuntu 24.04 to use its native, stable backend dependencies (`samba`, `zfsutils-linux`).
2. **Native Networkd Enforcement:** The installer permanently abolishes `NetworkManager` manipulation. The system relies purely on native `systemd-networkd` configurations, ensuring zero boot hangs or race conditions during the initial IP allocation phase.
3. **Dynamic VM Hardware Spoofing (Python Patching):** The script dynamically patches the core `/opt/45drives/tools/server_identifier` script. It permanently leaves `/etc/45drives/server_info/server_info.json` in `"Edit Mode": false`. When the system boots, the script naturally scans the isolated IOMMU PCI bus to detect LSI HBAs and connected drives. Right before writing the JSON file, the Python injection forcefully overwrites the QEMU motherboard generic fallback with the exact requested 45Drives chassis model (e.g., `Storinator-S45`). This guarantees future HBA expansions are discovered natively without breaking the 2D chassis UI.
4. **Libvirt Bridge Destruction:** When installed as a VM, the script automatically destroys and disables the `virbr0` default network bridge spawned by `cockpit-machines` dependencies, removing clutter from the networking tab.
5. **Blue-Gray Aesthetic Theme:** Replaced default installer colors with a professional, highly visible Blue-Gray palette. Custom SVG branding applies the Van Auken Tech logo and background to the Cockpit login screen.

### Validation Audit Results
The script was executed and validated on the `regulus` environment (`192.168.200.140`), an Ubuntu 24.04 VM with an LSI 9305-16i HBA passed through.

*   **[PASS]** `systemctl is-system-running` -> running (No maintenance mode drops).
*   **[PASS]** `systemctl is-active systemd-networkd` -> active.
*   **[PASS]** `findmnt /boot` -> Mounted natively without udev timeouts.
*   **[PASS]** `/usr/share/cockpit/45drives-disks/scripts/disk_info` -> Parsed without Python exceptions; output dynamically built the 15-drive array from the PCIe bus scan and applied the `S45` map.
*   **[PASS]** ZFS Functionality -> `zpool status` showed `testpool` ONLINE across reboots.

---
*Created and maintained by Thomas Van Auken - Van Auken Tech.*
