# Van Auken Tech Houston UI - Reference Manual

## Installer Architecture (V6.0.0)
This reference manual outlines the critical infrastructure logic implemented in the `install.sh` V6 script.

### 1. Network Configuration
* **Renderer:** `systemd-networkd`
* **NetworkManager:** Explicitly avoided. NetworkManager creates an unresolvable boot queue lock (`systemd-udev-settle`) when combined with massive ZFS SAS hard drive spin-up delays. 

### 2. 45Drives Package Dependencies
* **APT Pinning:** `/etc/apt/preferences.d/45drives.pref`
  * Forces `cockpit-*` and `45drives-tools` to draw from the Jammy 45Drives repo.
  * Drops priority of everything else from 45Drives to `-1`.
  * **Result:** Ubuntu 24.04 utilizes its native `zfsutils-linux` and `samba` libraries, avoiding catastrophic version mismatches with the older Jammy repo.

### 3. Hardware Identity Spoofing (Proxmox VMs)
* **Target File:** `/etc/45drives/server_info/server_info.json`
* **Edit Mode:** Forcefully set to `false`. This instructs the 45Drives Python backend to dynamically scan the system for HBA controllers and physical disks every time it runs.
* **QEMU Motherboard Bypass:** 
  * Target File: `/opt/45drives/tools/server_identifier`
  * Because the QEMU motherboard lacks the IPMI/FRU identifiers of physical Storinators, the script would normally overwrite `server_info.json` with a generic fallback that crashes the GUI grid.
  * The installer injects three Python variables (`Model`, `Chassis Size`, `Alias Style`) directly above the `update_json_file()` function.
  * **Result:** The system natively discovers new HBAs and drives on the IOMMU bus but forces them into the exact spoofed chassis template.

### 4. Libvirt / Cockpit Machines
* **Virtual Bridge:** `virbr0` is destroyed and its autostart flag disabled when deploying in VM mode. It is left alone for baremetal deployments.

---
*Created and maintained by Thomas Van Auken - Van Auken Tech.*
