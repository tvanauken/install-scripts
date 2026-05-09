# PVE Cluster Removal

> Created by: Thomas Van Auken — Van Auken Tech

**Universal cluster removal script** that works on ANY Proxmox VE node regardless of cluster state. Automatically detects and adapts to healthy, broken, or standalone configurations.

## Use Cases

- **Last surviving node** of a failed cluster
- **Node in a broken/unhealthy cluster** (not quorate)
- **Node with all other nodes offline**
- **Node you want to remove** from a healthy cluster  
- **Already standalone node** (will clean any remnants)

## Key Features

✓ **Works on ANY cluster state** - healthy, degraded, broken, or standalone
✓ **Automatic state detection** - adapts to your specific situation
✓ **Safe operation** - VMs, containers, and storage never touched
✓ **Complete backup** before any changes
✓ **Idempotent** - safe to run multiple times
✓ **Enterprise-grade** error handling

## Quick Start

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-removal/pve_cluster_removal.sh)
```

## What It Does

1. **Detects current state** (clustered, standalone, broken)
2. Creates comprehensive backup at `/root/cluster-removal-backup-TIMESTAMP/`
3. Stops cluster services (with fallback if already stopped)
4. Starts pmxcfs in local mode
5. Removes cluster configuration files
6. Removes local corosync data
7. Restarts services normally
8. Verifies VMs/containers still accessible
9. Removes offline node directories
10. Cleans `/etc/hosts` of cluster entries
11. Disables HA and corosync services
12. Verifies standalone status
13. Final verification and summary

## State Detection

The script automatically detects:
- **Clustered** - Node is part of a working cluster (quorate)
- **Broken** - Cluster config exists but not quorate or pvecm fails
- **Standalone** - No cluster configuration found
- **Unknown** - Indeterminate state (script will attempt cleanup)

## Safety

- VMs, containers, and storage are **NEVER** touched
- Complete backup created before ANY changes
- All operations are idempotent (safe to run multiple times)
- Works even if cluster is already partially removed
- Comprehensive logging to `/var/log/`

## Compatibility

- **Proxmox VE 8.x** (Debian 12 Bookworm)
- **Proxmox VE 9.x** (Debian 13 Trixie)

## Post-Operation

After completion:
1. Access Web UI to verify standalone status
2. Verify all VMs and containers operational
3. Verify storage pools accessible
4. **REBOOT** to ensure configuration survives restart
5. Node is ready to join a new cluster if needed

---

*Van Auken Tech · Thomas Van Auken*
