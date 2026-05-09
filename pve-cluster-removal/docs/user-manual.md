# PVE Cluster Removal — User Manual

> Created by: Thomas Van Auken — Van Auken Tech

## Overview

The **PVE Cluster Removal** script is a universal cluster deconfiguration tool that works on ANY Proxmox VE node regardless of cluster health. It automatically detects the current state and safely converts any node to standalone operation.

## Purpose

This script solves the common problem of removing cluster configuration when:
- You are the last surviving node of a failed cluster
- Your cluster is broken or not quorate
- All other nodes are offline or have been rebuilt
- You want to remove a node from any cluster state
- You need to clean cluster remnants from a supposedly standalone node

## Key Features

### Universal Compatibility
- Works on **healthy clusters** (quorate nodes)
- Works on **broken clusters** (non-quorate, failed communication)
- Works on **standalone nodes** (cleans any remnants)
- Detects current state automatically
- Adapts operations based on detected state

### Safety First
- **VMs and containers are NEVER touched**
- **Storage configurations remain intact**
- **User data is never deleted**
- Complete backup before any changes
- Idempotent - safe to run multiple times
- Comprehensive logging

### Intelligent Operation
- Automatic state detection
- Graceful error handling
- Fallback mechanisms for failed operations
- Works even when pvecm commands fail
- Safe to interrupt (no partial states)

## Installation

### One-Line Install
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-removal/pve_cluster_removal.sh)
```

### Manual Download
```bash
cd /root
wget https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-removal/pve_cluster_removal.sh
chmod +x pve_cluster_removal.sh
./pve_cluster_removal.sh
```

## Requirements

- **Proxmox VE 8.x** (Debian 12 Bookworm) or **9.x** (Debian 13 Trixie)
- **Root access** to the local node
- **VMs/containers operational** (they will remain untouched)
- **Sufficient disk space** for backup (~100MB typically)
- **Internet connectivity** (for curl download only)

## Pre-Operation Checklist

### Critical Requirements
1. ✓ You have root access to this node
2. ✓ VMs and containers are running normally
3. ✓ You understand this will remove ALL cluster configuration
4. ✓ You have verified storage is accessible

### Recommended (but not required)
1. ✓ Take VM/container backups (optional - script doesn't touch them)
2. ✓ Document current cluster state
3. ✓ Note down any custom cluster configurations

## Operation

### Step-by-Step Process

#### 1. State Detection
The script automatically detects:
- **Clustered** - Node is part of a working cluster (quorate)
- **Broken** - Cluster exists but not quorate or pvecm fails
- **Standalone** - No cluster configuration found
- **Unknown** - Indeterminate state (will attempt cleanup)

#### 2. Backup Creation
Before ANY changes:
- Creates `/root/cluster-removal-backup-TIMESTAMP/`
- Backs up all cluster configuration files
- Documents VM and container state
- Creates manifest with node information

#### 3. Service Management
- Stops pve-cluster service (or notes if already stopped)
- Stops corosync service (or notes if already stopped)
- Starts pmxcfs in local mode

#### 4. Configuration Removal
- Removes `/etc/pve/corosync.conf`
- Removes `/etc/corosync/corosync.conf`
- Cleans `/etc/corosync/*` directory
- Cleans `/var/lib/corosync/*` directory

#### 5. Service Restart
- Kills pmxcfs (systemd will restart it)
- Starts pve-cluster service
- Verifies service status

#### 6. Cleanup
- Removes offline node directories from `/etc/pve/nodes/`
- Cleans cluster entries from `/etc/hosts`
- Disables HA services (pve-ha-crm, pve-ha-lrm)
- Disables corosync service

#### 7. Verification
- Verifies VMs and containers accessible
- Checks standalone status
- Restarts web UI services
- Verifies storage pools
- Displays comprehensive summary

### Confirmation Required

The script will display:
- Current detected state
- What will be changed
- What will NOT be changed
- Backup location

You must type **YES** (all caps) to proceed. Any other input aborts with no changes.

## Output Files

### Backup Directory
Location: `/root/cluster-removal-backup-TIMESTAMP/`

Contents:
- `pvecm-status-before.txt` - Cluster status before changes
- `vm-list-before.txt` - VM list before changes  
- `ct-list-before.txt` - Container list before changes
- `mount-before.txt` - Mount points before changes
- `config.db.backup` - pmxcfs database backup
- `corosync.conf.backup` - Cluster configuration
- `corosync.backup/` - Full /etc/corosync backup
- `members.backup` - Cluster members file
- `qemu-server.backup/` - VM configurations
- `lxc.backup/` - Container configurations
- `interfaces.backup` - Network configuration
- `hosts.backup` - /etc/hosts backup
- `hostname.backup` - Hostname backup
- `backup-manifest.txt` - Backup metadata

### Log File
Location: `/var/log/pve_cluster_removal_TIMESTAMP.log`

Contains:
- Complete operation log
- All commands executed
- All output and errors
- Timestamps for all operations

## Post-Operation Tasks

### Immediate Verification

1. **Access Web UI**
   ```
   https://YOUR-NODE-IP:8006
   ```
   - Should show "Standalone node - no cluster defined"
   - Should NOT show offline nodes

2. **Verify VMs**
   ```bash
   qm list
   ```
   - All VMs should be visible
   - Running VMs should still be running

3. **Verify Containers**
   ```bash
   pct list
   ```
   - All containers should be visible
   - Running containers should still be running

4. **Verify Storage**
   ```bash
   pvesm status
   ```
   - All storage pools should be active

5. **Verify Cluster Status**
   ```bash
   pvecm status
   ```
   - Should return error: "Corosync config does not exist"
   - This is EXPECTED and indicates success

### Critical: Reboot Test

**IMPORTANT:** You MUST reboot the node to ensure configuration survives restart:

```bash
reboot
```

After reboot:
- Web UI should still show standalone
- VMs/containers should auto-start if configured
- Storage should be accessible
- No cluster-related errors in logs

### Cleanup (Optional)

After successful reboot and verification:

1. **Remove backup** (only if confident)
   ```bash
   rm -rf /root/cluster-removal-backup-*
   ```

2. **Remove log** (only if confident)
   ```bash
   rm -f /var/log/pve_cluster_removal_*.log
   ```

## Troubleshooting

### Web UI Shows Cluster

**Symptom:** Web UI still shows cluster name or offline nodes

**Solution:**
```bash
# Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)
# OR clear browser cache
# OR restart web services
systemctl restart pveproxy pvedaemon
```

### VMs Not Visible

**Symptom:** VMs don't appear in web UI or qm list

**Solution:**
```bash
# Restart pve-cluster service
systemctl restart pve-cluster

# Check pmxcfs status
ps aux | grep pmxcfs

# If needed, restart pmxcfs
killall pmxcfs
systemctl start pve-cluster
```

### Storage Not Accessible

**Symptom:** Storage pools show as unavailable

**Solution:**
```bash
# Check storage status
pvesm status

# Remount if needed
pvesm status --verbose

# Check /etc/pve/storage.cfg
cat /etc/pve/storage.cfg
```

### Corosync Still Running

**Symptom:** corosync process still active after completion

**Solution:**
```bash
# Stop and disable
systemctl stop corosync
systemctl disable corosync
systemctl mask corosync

# Verify
ps aux | grep corosync
```

### /etc/pve Not Mounted

**Symptom:** /etc/pve directory is not accessible

**Solution:**
```bash
# Restart pve-cluster
systemctl restart pve-cluster

# Check mount
mount | grep pve

# Check pmxcfs
ps aux | grep pmxcfs

# If severe, restore from backup
cp /root/cluster-removal-backup-*/config.db.backup /var/lib/pve-cluster/config.db
systemctl restart pve-cluster
```

## Recovery Procedures

### Full Recovery from Backup

If something goes wrong and you need to restore:

```bash
# Stop services
systemctl stop pve-cluster corosync

# Restore configuration
cp /root/cluster-removal-backup-*/config.db.backup /var/lib/pve-cluster/config.db
cp /root/cluster-removal-backup-*/corosync.conf.backup /etc/pve/corosync.conf
cp -r /root/cluster-removal-backup-*/corosync.backup/* /etc/corosync/

# Restart services
systemctl start corosync
systemctl start pve-cluster

# Verify
pvecm status
```

## Joining a New Cluster

After successful deconfiguration, the node can join a new cluster:

```bash
# From the new cluster's existing node
pvecm add <this-node-ip>

# Follow prompts and enter root password
```

Or add another node to this one:

```bash
# On this node, create new cluster
pvecm create <cluster-name>

# On other node, join this cluster  
pvecm add <this-node-ip>
```

## Best Practices

1. **Always reboot after deconfiguration** to verify persistence
2. **Keep backups** until confident everything works
3. **Document your cluster state** before running script
4. **Test VM migrations** after rejoining a cluster
5. **Update /etc/hosts** manually if needed for SSH access

## Support

- **Script Issues:** Check `/var/log/pve_cluster_removal_*.log`
- **Proxmox Issues:** Consult Proxmox VE documentation
- **Recovery:** Use backup in `/root/cluster-removal-backup-*/`

---

*Van Auken Tech · Thomas Van Auken*
