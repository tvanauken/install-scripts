# PVE Cluster Deconfiguration to Standalone

> Created by: Thomas Van Auken — Van Auken Tech

Safely removes all cluster configuration from a Proxmox VE node and converts it to a fully functional standalone node. All VMs, containers, and storage remain intact and operational.

## Use Case

- **Last surviving node** of a failed cluster
- **Cluster with all other nodes offline/rebuilt**
- Converting clustered node to standalone for testing
- Removing cluster remnants after cluster failure

## Preflight Requirements

1. This node must be the ONLY surviving node, OR
2. This node must already have `expected_votes=1` and be quorate, OR
3. All other cluster nodes are permanently offline/rebuilt
4. All VMs and containers on this node are operational
5. Root access to the local node

## Features

- **19-step automated process** with comprehensive verification
- **Complete backup** of all configuration files before any changes
- **Safe operation** — VMs, containers, and storage completely unaffected
- **Visual progress** with Van Auken Tech branded output
- **Comprehensive logging** to `/var/log/`
- **Final verification** ensures standalone status

## Quick Start

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-deconfig/pve_cluster_deconfig.sh)
```

## What It Does

1. Verifies current cluster state and node configuration
2. Creates comprehensive backup at `/root/cluster-removal-backup-TIMESTAMP/`
3. Documents all VM and container configurations
4. Stops cluster services (pve-cluster, corosync)
5. Starts pmxcfs in local mode
6. Removes `/etc/pve/corosync.conf`
7. Removes all local corosync data
8. Restarts services normally
9. Verifies VMs and containers still accessible
10. Removes offline node directories
11. Cleans `/etc/hosts` of cluster entries
12. Disables HA services
13. Disables corosync service
14. Verifies standalone status
15. Verifies web UI services
16. Verifies storage accessibility
17. Confirms no corosync processes running
18. Checks system logs for errors
19. Performs final verification

## Compatibility

- **Proxmox VE 8.x** (Debian 12 Bookworm)
- **Proxmox VE 9.x** (Debian 13 Trixie)

## Documentation

- **[User Manual](docs/user-manual.md)** — Comprehensive usage guide
- **[Build Log](docs/build-log.md)** — Complete development and testing log

## Post-Operation

After completion:
1. Access Web UI to verify standalone status
2. Verify all VMs and containers operational
3. Verify storage pools accessible
4. **Reboot to ensure configuration survives restart**
5. Node is ready to join a new cluster if needed

---

*Van Auken Tech · Thomas Van Auken*
