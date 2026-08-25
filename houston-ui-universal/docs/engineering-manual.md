# Van Auken Tech - Houston / 45Drives - Universal Installer - Engineering Manual

## Installer Architecture (V1.0.0 Universal)
This engineering manual outlines the critical infrastructure logic implemented in the `houston-universal-v1.0.0.sh` script.

### 1. Dynamic Hardware Spoofing
The Houston UI Disk management tab relies on a Python backend (`/opt/45drives/tools/server_identifier`) to cross-reference `lspci` outputs against a known database of 45Drives physical chassis layouts.
* Because the QEMU motherboard lacks the IPMI/FRU identifiers of physical Storinators, the script would normally overwrite `server_info.json` with a generic fallback that crashes the GUI grid.
* Instead of permanently locking the JSON file (which breaks future PCI scanning), the installer dynamically injects `sed` patches directly into the Python execution flow. It allows the script to scan the bus, but intercepts the write function to hardcode the requested chassis variables.

### 2. NetworkManager Elimination
NetworkManager creates race conditions when managing virtualized storage bridges or virtual NICs under Proxmox. The script purges all NetworkManager packages. This guarantees that `systemd-networkd` remains the sole routing authority, ensuring deterministic boots.

### 3. ZFS systemd-udev-settle Bypass
OpenZFS unit files in some distributions depend on `systemd-udev-settle.service`, which is deprecated and waits indefinitely for hardware queues to flush. When passing through physical HBAs, this causes 120+ second boot delays or maintenance mode drops. The installer surgically removes this dependency from all ZFS unit files.
