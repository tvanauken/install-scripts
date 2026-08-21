# Build Log: 45Drives Houston UI & Cockpit Installer
**Created by:** Thomas Van Auken — Van Auken Tech
**Date:** 2026-08-21

## 1. Objective
To construct a bulletproof, interactive, standalone bash installation script for the 45Drives Houston UI suite. The script must conform exactly to the visual identity and structural standards of the Van Auken Tech Install Scripts Collection (inspired by Proxmox VE Community Scripts) and address critical deployment bugs discovered during previous 45Drives virtualization engineering.

## 2. Research & Discovery
Prior engineering on the `VanAukenHome` cluster (specifically the `houston` VM running inside Proxmox with an HBA pass-through) revealed significant flaws in the official 45Drives `dmap` and `cockpit-45drives-hardware` modules when run in a virtualized context.

*   **The IPMI Failure:** Because the OS runs as a VM, it cannot communicate with the Supermicro or AsRock motherboard via `/dev/ipmi0`. The 45Drives `server_identifier` script defaults to `Storinator-AV15-VM`, which breaks the UI rendering.
*   **The Workaround:** The JSON definition file located at `/etc/45drives/server_info/server_info.json` must be manually modified to force the correct `Model` and `Chassis Size`. Crucially, the flag `"Edit Mode": true` must be set, or the background scanner will overwrite the fix on the next cron cycle.
*   **The Systemd Failure:** The `openipmi.service` attempts to load drivers on boot, crashing the service and polluting the system logs because the VM lacks IPMI hardware.

## 3. Script Development
The script was constructed in `~/install-scripts/houston-ui/install.sh` utilizing the standard Van Auken Tech UI helpers (`msg_info`, `msg_ok`, `msg_error`, `section`, etc.).

### Key Logic Implementations:
1.  **Whiptail Integration:** Added `whiptail` menus to prompt the user if the deployment is `BAREMETAL` or `VM`.
2.  **OS Agnostic Package Management:** Added dynamic OS detection to support both `apt` (Ubuntu/Debian) and `dnf` (Rocky/RHEL) as 45Drives supports both ecosystems.
3.  **Hardware Spoofing Payload:** If the user selects `VM`, they are prompted for their chassis size (S45, Q30, HL15, etc.). The script dynamically builds a JSON payload:
    ```json
    {
        "Motherboard": {"Manufacturer": "VIRTUAL_MACHINE", "Product Name": "VM_MOTHERBOARD", "Serial Number": "VIRTUAL_MACHINE"},
        "HBA": [],
        "Hybrid": false,
        "Serial": "VIRTUAL_MACHINE",
        "Model": "Storinator-${HW_CHASSIS}",
        "Alias Style": "STORINATOR",
        "Chassis Size": "${HW_CHASSIS}",
        "VM": true,
        "Edit Mode": true,
        "OS NAME": "Linux",
        "OS VERSION_ID": "",
        "Auto Alias": false,
        "HWRAID": false
    }
    ```
4.  **Service Hardening:** Added explicit commands to `disable` and `mask` the `openipmi` systemd service when in VM mode.

## 4. Documentation & Git Deployment
1.  Created `README.md` (root overview).
2.  Created `docs/user-manual.md` (comprehensive instructions).
3.  Created this `docs/build-log.md` (action log).
4.  All documentation attributes authorship to Thomas Van Auken - Van Auken Tech in accordance with the user rules.
5.  Added the new script into the master `~/install-scripts/README.md` index.
6.  Committed all changes and pushed directly to the `tvanauken/install-scripts` GitHub repository.