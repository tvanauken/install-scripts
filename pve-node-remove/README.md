# PVE Cluster Node Removal
### Van Auken Tech · Thomas Van Auken

> Part of the [Van Auken Tech Install Scripts Collection](../README.md)

---

## Overview

Safely removes a node from a Proxmox VE cluster. Scans all cluster nodes, presents an interactive selection menu, then performs complete removal including cluster membership, SSH keys, /etc/hosts configuration, and cleanup of the removed node to standalone status.

## Preflight Requirements

- **Healthy cluster** — must have quorum
- **Root SSH access** — to ALL cluster nodes including the target
- **VMs/Containers migrated** — target node must be empty
- **No HA resources** — on the target node
- **No Ceph OSDs** — on the target node (if using Ceph)

## Safety

**PROTECTED:** Local node cannot be selected for removal

**NOT REVERSIBLE:** Once confirmed, the node will be permanently removed from the cluster

## Usage

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh)
```

Displays all cluster nodes, prompts for selection and root password, shows full removal plan, then requires `YES` to proceed.

---
*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
