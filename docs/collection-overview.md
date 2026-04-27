# Van Auken Tech — Install Scripts Collection
### Thomas Van Auken — Van Auken Tech
**Repository:** https://github.com/tvanauken/install-scripts

---

## What This Repository Is

A collection of custom scripts for Van Auken Tech infrastructure, all adhering to the **Van Auken Tech standard** for script design and visual presentation. Every script in this collection shares a unified look, feel, and behaviour.

Scripts 1–4, 10–11 target Proxmox VE hosts directly. Script 5 targets Raspberry Pi hardware. Scripts 6–7 configure already-deployed LXC containers — install the LXC first from community-scripts.org, then run the script. Scripts 8–9 are cross-platform prompt installers.

---

## Scripts in This Collection

| # | Script | Directory | Target | Version | Purpose |
|---|--------|-----------|--------|---------|--------|
| 1 | CLI Tools Installer | [`cli-tools/`](../cli-tools/) | Proxmox VE | 1.0.0 | Installs 46 CLI tools + X11 deps |
| 2 | PVE Drive Cleanup & Init | [`pve-drive-init/`](../pve-drive-init/) | Proxmox VE | 1.0.0 | Wipes drives with remnant data for fresh deployment |
| 3 | Drive Inventory Generator | [`drive-inventory/`](../drive-inventory/) | Proxmox VE | 1.0.0 | Scans all drives, generates markdown inventory report |
| 4 | **PVE Cluster Node Removal** | [`pve-node-remove/`](../pve-node-remove/) | **Proxmox VE** | **1.0.0** | Safely removes a node from a PVE cluster |
| 5 | **Raspberry Pi Setup** | [`pi-setup/`](../pi-setup/) | **Raspberry Pi** | 1.0.0 | Kali tools + XFCE desktop + performance tuning |
| 6 | Technitium DNS Server | [`dns-server/`](../dns-server/) | Debian/Ubuntu | **3.0.0** | UniFi survey, root hints, dynamic zones, auto-sync |
| 7 | Nginx Proxy Manager | [`npm-reverse-proxy/`](../npm-reverse-proxy/) | Debian/Ubuntu | **3.0.0** | Native install, Lua SRV resolver, dynamic SSL proxy |
| 8 | Kali-Style Prompt (Linux) | [`kali-prompt/`](../kali-prompt/) | Any Linux | **2.1.0** | Authentic Kali two-line prompt on any distro |
| 9 | **Kali-Style Prompt (macOS)** | [`kali-prompt-macos/`](../kali-prompt-macos/) | **macOS 12.7.6+** | 2.0.0 | Authentic Kali-style prompt on Intel/Apple Silicon Macs |
| 10 | **PVE VM & CT Cleanup** | [`pve-vm-ct-cleanup/`](../pve-vm-ct-cleanup/) | **Proxmox VE** | **1.0.0** | Complete VM/CT removal with storage, snapshots, backups |
| 11 | **Technitium DNS (Standalone)** | [`dns-server/`](../dns-server/) | **Proxmox VE** | **1.0.0** | Creates LXC + installs DNS server in one command |

> ⚠ Script 4 requires a **healthy PVE cluster** with quorum and root SSH access to all nodes. Target node must be empty (no VMs/containers).

> ⚠ Script 5 requires **Raspberry Pi hardware** (armhf/arm64). Supported OS: Raspberry Pi OS, Ubuntu Desktop/Server, Kali Linux ARM, Debian ARM.
> NOT compatible with Proxmox VE or x86/x86_64 systems.
> Must be run with `sudo bash <(curl -s URL)` — not curl alone.

> ℹ Scripts 6–7 now include **full installation scripts** that install and configure from scratch. Also available are post-install scripts for existing installations.

> 🍎 Script 9 requires **macOS 12.7.6 (Monterey)** or later. Supports both Intel and Apple Silicon Macs.

> ⚠ Script 10 performs **IRREVERSIBLE** destruction. Multi-layer confirmation required (VMID + "DESTROY").

> 📖 See the [DNS & NPM Infrastructure Manual](dns-npm-infrastructure-manual.md) for complete documentation on deploying the DNS + reverse proxy pair.

---

## Quick Reference — One-Liners

### PVE Cluster Node Removal
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh)
```
### PVE VM & CT Cleanup
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
```

### Technitium DNS Server — Standalone LXC Installation
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
```

---
### Install Kali-Style Prompt (Any Linux Distro)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

### Install Kali-Style Prompt (macOS 12.7.6+)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

---

*Created by: Thomas Van Auken — Van Auken Tech*
