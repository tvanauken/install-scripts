# PVE Cluster Node Removal — Build Log
### Van Auken Tech · Thomas Van Auken
**Date:** 2026-04-18
**Host:** atlas.mgmt.home.vanauken.tech
**PVE Version:** 9.1.6 (Debian Trixie)
**Script:** `pve_node_remove.sh`
**GitHub:** https://github.com/tvanauken/install-scripts/tree/main/pve-node-remove

---

## Overview

This document is the action log for the creation and deployment of the PVE Cluster Node Removal script. The script was developed based on a real-world node removal operation performed on the VanAukenHome cluster.

---

## Actions Taken

### 1. Real-World Node Removal Performed
Prior to script creation, a manual node removal was performed on the VanAukenHome cluster:
- **Cluster:** VanAukenHome (4 nodes: atlas, titan, photon, pm03)
- **Target Node:** pm03 (192.168.200.193, Node ID 4)
- **Operation:** Complete removal of pm03 from cluster

Manual steps performed:
1. Verified no VMs or containers on pm03
2. Stopped cluster services on pm03
3. Ran `pvecm delnode pm03` from atlas
4. Removed `/etc/pve/nodes/pm03/` directory
5. Removed pm03's SSH key from cluster authorized_keys
6. Updated `/etc/hosts` on all remaining nodes (fixed DNS resolution issue)
7. Cleaned SSH known_hosts on all nodes
8. Cleaned cluster configuration on pm03 (made standalone)
9. Verified cluster health and SSH connectivity

### 2. Issues Discovered During Manual Operation
- **DNS Resolution Issue:** Titan was resolving "atlas" to an external IP (172.90.46.180) instead of internal IP (192.168.200.80)
- **Fix Applied:** Added all cluster node entries to `/etc/hosts` on all nodes
- **SSH Known Hosts:** Titan had stale entries that needed cleanup

### 3. Script Development
Based on the manual operation, a fully automated script was developed:
- Following Van Auken Tech visual standards
- Using colour palette: RD/YW/GN/DGN/BL/CL/BLD
- Using msg_info/ok/warn/error and section() functions
- VANAUKEN TECH figlet ASCII art header
- Beautiful final summary with box-drawing characters
- Comprehensive logging to `/var/log/`

### 4. Script Features
- **Interactive node selection** — numbered list of all cluster nodes
- **Root password prompt** — with SSH connectivity test
- **Preflight verification** — checks for VMs, containers, HA resources
- **Full removal plan display** — before confirmation
- **Single YES confirmation** — prevents accidental execution
- **8-step automated removal process**
- **/etc/hosts management** — ensures reliable SSH connectivity
- **SSH known_hosts cleanup** — removes stale entries
- **Target node cleanup** — makes it standalone
- **Final verification** — cluster health and SSH mesh test
- **Beautiful summary** — box-drawing character tables

### 5. Testing
- `bash -n` syntax check: ✔ Pass
- Script structure validated against existing Van Auken Tech scripts
- Based on successfully executed manual removal of pm03

---

## Test Results

| Check | Result |
|-------|--------|
| `bash -n` syntax check | ✔ Pass |
| Van Auken Tech visual standards | ✔ Compliant |
| Based on real-world operation | ✔ pm03 successfully removed |

**Manual Operation Results (VanAukenHome Cluster):**
- Initial State: 4 nodes (atlas, titan, photon, pm03)
- Final State: 3 nodes (atlas, titan, photon)
- pm03 Status: Standalone Proxmox node
- Cluster Health: Quorate, all nodes online
- SSH Mesh: 6/6 connections verified

---

## Script Structure

```
pve-node-remove/
├── pve_node_remove.sh      # Main script
├── README.md               # Short overview
└── docs/
    ├── user-manual.md      # Comprehensive user manual
    └── build-log.md        # This file
```

---

## Notes

- Script uses `sshpass` for non-interactive SSH authentication (auto-installed if missing)
- Password is stored only in memory during execution
- `/etc/hosts` entries use format: `IP FQDN SHORTNAME`
- Removed node's SSH key is identified by `root@<nodename>` comment
- Corosync is disabled (not just stopped) on the removed node
- pmxcfs is started in local mode during cleanup to access cluster filesystem

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
