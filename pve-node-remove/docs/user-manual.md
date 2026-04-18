# PVE Cluster Node Removal — User Manual
### Van Auken Tech · Thomas Van Auken
**Script:** `pve_node_remove.sh`
**Version:** 1.0.0
**Compatibility:** Proxmox VE 8.x / 9.x · Debian Bookworm / Trixie

---

## Purpose

This script safely removes a node from a Proxmox VE cluster. It handles all aspects of node removal including:

- Stopping cluster services on the target node
- Removing the node from cluster membership (corosync)
- Cleaning up the node directory in `/etc/pve/nodes/`
- Removing SSH keys from cluster `authorized_keys`
- Updating `/etc/hosts` on all remaining nodes for reliable connectivity
- Cleaning SSH `known_hosts` to remove stale entries
- Configuring the removed node as a standalone Proxmox server
- Verifying cluster health and full-mesh SSH connectivity

> **This operation is NOT reversible. Once confirmed, the node will be permanently removed from the cluster.**

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Operating System | Proxmox VE 8.x or 9.x |
| User | Must be run as **root** |
| Cluster State | Must be healthy with quorum |
| SSH Access | Root password SSH access to ALL nodes |
| Target Node | Must have NO VMs, containers, or HA resources |

---

## Running the Script

### One-liner
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh)
```

### Download and run
```bash
wget -O pve_node_remove.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh
chmod +x pve_node_remove.sh
./pve_node_remove.sh
```

---

## What You Will See

### 1. Header
The VANAUKEN TECH ASCII banner with host, date, PVE version, and log file path.

### 2. Preflight Requirements
A list of requirements that must be met before proceeding:
- Healthy cluster with quorum
- Root SSH access to ALL nodes
- VMs/containers migrated off target node
- No HA resources on target node
- No Ceph OSDs on target node

### 3. Preflight Checks
- Root verification
- Proxmox VE detection
- Cluster health and quorum verification
- Auto-installs `sshpass` if not present

### 4. Node Discovery
Scans the cluster and displays all nodes:

```
  ╔══════════════════════════════════════════════════════════════╗
  ║              CLUSTER NODES                                   ║
  ╚══════════════════════════════════════════════════════════════╝

  [1]  atlas                 192.168.200.80   (local)
  [2]  titan                 192.168.200.10
  [3]  photon                192.168.200.152
  [4]  pm03                  192.168.200.193
```

### 5. Node Selection
Select the node to remove by entering its number. You cannot select the local node.

### 6. SSH Credentials
Enter the root password for cluster nodes. The script tests SSH connectivity before proceeding.

### 7. Target Verification
Verifies the target node:
- Has no VMs
- Has no LXC containers
- Has no HA resources
- Is reachable via SSH

### 8. Removal Plan
Before any action is taken, the full plan is displayed:

```
  ╔══════════════════════════════════════════════════════════════╗
  ║              REMOVAL PLAN — REVIEW CAREFULLY                 ║
  ╚══════════════════════════════════════════════════════════════╝

  NODE TO BE REMOVED:
      ✘  pm03                  192.168.200.193

  NODES REMAINING:
      ✔  atlas                 192.168.200.80
      ✔  titan                 192.168.200.10
      ✔  photon                192.168.200.152
```

### 9. Confirmation Gate
```
  ╔══════════════════════════════════════════════════════════════╗
  ║  !! THIS OPERATION IS NOT REVERSIBLE !!                      ║
  ║  The node will be permanently removed from the cluster.      ║
  ╚══════════════════════════════════════════════════════════════╝

  Type  YES  to proceed (anything else aborts):
```

Only the exact string `YES` (uppercase) proceeds. Any other input aborts with no changes made.

### 10. Execution (Steps 1–8)

| Step | What Happens |
|------|--------------|
| 1 | Stop cluster services on target node |
| 2 | Remove node from cluster membership (`pvecm delnode`) |
| 3 | Delete `/etc/pve/nodes/<target>/` directory |
| 4 | Remove target's SSH key from cluster `authorized_keys` |
| 5 | Update `/etc/hosts` on all remaining nodes |
| 6 | Clean SSH `known_hosts` on all remaining nodes |
| 7 | Clean cluster config on target node (make standalone) |
| 8 | Verify cluster health and SSH mesh connectivity |

### 11. Final Summary
A beautiful summary showing cluster status, remaining nodes, removed node, and connectivity verification.

---

## Log File

All output is simultaneously written to the terminal and:
```
/var/log/pve_node_remove_YYYYMMDD_HHMMSS.log
```

---

## Safety Notes

- **Cannot remove local node** — you must run the script from a different cluster node
- **Always review the Removal Plan** before typing `YES`
- **Verify VMs are migrated** — the script will refuse to proceed if VMs exist on the target
- **SSH connectivity is tested** before any changes are made
- **The removed node becomes standalone** — it can be re-joined to a cluster later or used independently

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Cluster is NOT quorate" | Not enough nodes online | Bring offline nodes back online |
| SSH connection fails | Wrong password or SSH disabled | Verify root password and SSH config |
| "Node has VMs" | VMs still on target | Migrate or remove VMs first |
| "Cannot remove local node" | Running from target node | SSH to a different node first |
| Node still shows after removal | Stale cache | Wait and refresh, or restart pve-cluster |

---

## What Happens to the Removed Node

The removed node is configured as a standalone Proxmox server:
- Corosync is disabled
- Cluster configuration files are removed
- The node can be:
  - Re-installed fresh
  - Joined to a different cluster
  - Used as a standalone Proxmox server

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
