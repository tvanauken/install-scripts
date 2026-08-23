# Van Auken Tech Houston UI - Build & Validation Log

## Engineering Summary
This document logs the development, refinement, and final validation of the `install.sh` script (v1.0.0) used to deploy the Van Auken Tech Houston UI onto Ubuntu 24.04 (Noble) systems.

### The Challenge
1. **OS Compatibility:** 45Drives officially supports Ubuntu 20.04 and 22.04. Ubuntu 24.04 (Noble Numbat) introduces newer native libraries (such as `samba` and `libldb2`) that conflict with the 45Drives `jammy` repositories.
2. **NetworkManager Configuration:** Cockpit's `packagekit` module relies on `NetworkManager` for online connectivity checks. Ubuntu Server defaults to an unmanaged state, breaking the Software Updates GUI.
3. **VM Hardware Spoofing:** When deploying inside a Proxmox VM with an HBA passed through, the `45drives-disks` module's Python backend (`lsdev`) would crash or crop the 2D chassis graphic if improperly spoofed.

### The Solution (V5 Implementation)
1. **Strict APT Pinning:** The script injects `/etc/apt/preferences.d/45drives.pref` with a priority of `1000` for `cockpit-*` packages, forcing the UI to pull from 45Drives, while explicitly dropping priority for all other packages to `-1`. This allows Ubuntu 24.04 to use its native, stable backend dependencies (`samba`, `zfsutils-linux`).
2. **NetworkManager Online Fix:** The script injects `/etc/NetworkManager/conf.d/20-connectivity.conf` pointing to `archive.ubuntu.com` and shifts `netplan` to NetworkManager rendering, ensuring the Software Updates tab always registers as "Online".
3. **Hardware Override Validation:** The script bypasses hardware dependencies by spoofing the sensors natively on the Proxmox host.
4. **Python & JSON Hardware Overrides:** The script uses `jq` to explicitly set `"Edit Mode": true` and `"VM": false` in `server_info.json`. It also patches the `server_identifier` Python code to prevent it from overwriting the fake physical chassis. This forces the Vue.js frontend to render a complete, uncropped physical chassis based on the exact chassis string selected during installation.
5. **Custom Branding:** Injected SVG vector graphics and CSS to apply the Van Auken Tech theme to the Cockpit login screen.

### Validation Audit Results
The script was executed and validated on the `regulus` environment (`192.168.200.140`), an Ubuntu 24.04 VM with an LSI 9305-16i HBA passed through.

*   **[PASS]** `systemctl is-active cockpit` -> active
*   **[PASS]** `systemctl is-active NetworkManager` -> active
*   **[PASS]** `pkcon refresh` -> Success (NetworkManager connectivity verified).
*   **[PASS]** `/usr/share/cockpit/45drives-disks/scripts/disk_info` -> Parsed without Python exceptions; output confirmed the `1-4` bay occupancy logic.
*   **[PASS]** ZFS Functionality -> `zpool create testpool /dev/sdb` succeeded.

---
*Created and maintained by Thomas Van Auken - Van Auken Tech.*
