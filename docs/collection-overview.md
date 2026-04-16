# Van Auken Tech — Install Scripts Collection
### Thomas Van Auken — Van Auken Tech
**Repository:** https://github.com/tvanauken/install-scripts

---

## What This Repository Is

A collection of custom scripts for Van Auken Tech infrastructure, all adhering to the **Van Auken Tech standard** for script design and visual presentation. Every script in this collection shares a unified look, feel, and behaviour.

Scripts 1–3 target Proxmox VE hosts directly. Script 4 targets Raspberry Pi hardware. Scripts 5–6 configure already-deployed LXC containers — install the LXC first from community-scripts.org, then run the script. Scripts 7–8 are cross-platform prompt installers.

---

## Scripts in This Collection

| # | Script | Directory | Target | Version | Purpose |
|---|--------|-----------|--------|---------|--------|
| 1 | CLI Tools Installer | [`cli-tools/`](../cli-tools/) | Proxmox VE | 1.0.0 | Installs 46 CLI tools + X11 deps |
| 2 | PVE Drive Cleanup & Init | [`pve-drive-init/`](../pve-drive-init/) | Proxmox VE | 1.0.0 | Wipes drives with remnant data for fresh deployment |
| 3 | Drive Inventory Generator | [`drive-inventory/`](../drive-inventory/) | Proxmox VE | 1.0.0 | Scans all drives, generates markdown inventory report |
| 4 | **Raspberry Pi Setup** | [`pi-setup/`](../pi-setup/) | **Raspberry Pi** | 1.0.0 | Kali tools + XFCE desktop + performance tuning |
| 5 | Technitium DNS Server | [`dns-server/`](../dns-server/) | Debian/Ubuntu | **3.0.0** | UniFi survey, root hints, dynamic zones, auto-sync |
| 6 | Nginx Proxy Manager | [`npm-reverse-proxy/`](../npm-reverse-proxy/) | Debian/Ubuntu | **3.0.0** | Native install, Lua SRV resolver, dynamic SSL proxy |
| 7 | Kali-Style Prompt (Linux) | [`kali-prompt/`](../kali-prompt/) | Any Linux | **2.1.0** | Authentic Kali two-line prompt on any distro |
| 8 | **Kali-Style Prompt (macOS)** | [`kali-prompt-macos/`](../kali-prompt-macos/) | **macOS 12.7.6+** | 2.0.0 | Authentic Kali-style prompt on Intel/Apple Silicon Macs |

> ⚠ Script 4 requires **Raspberry Pi hardware** (armhf/arm64). Supported OS: Raspberry Pi OS, Ubuntu Desktop/Server, Kali Linux ARM, Debian ARM.
> NOT compatible with Proxmox VE or x86/x86_64 systems.
> Must be run with `sudo bash <(curl -s URL)` — not curl alone.

> ℹ Scripts 5–6 now include **full installation scripts** that install and configure from scratch. Also available are post-install scripts for existing installations.

> 🍎 Script 8 requires **macOS 12.7.6 (Monterey)** or later. Supports both Intel and Apple Silicon Macs.

> 📖 See the [DNS & NPM Infrastructure Manual](dns-npm-infrastructure-manual.md) for complete documentation on deploying the DNS + reverse proxy pair.

---

## Quick Reference — One-Liners

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
