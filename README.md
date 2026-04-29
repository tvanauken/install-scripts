# Van Auken Tech — Install Scripts Collection

> Created by: Thomas Van Auken — Van Auken Tech

A collection of helper and utility scripts for Van Auken Tech infrastructure. All scripts share a unified visual identity modelled after the [Proxmox VE Community Scripts](https://community-scripts.org/scripts).

---

## Scripts

### 1. CLI Tools Installer
**Directory:** [`cli-tools/`](cli-tools/)
**Script:** [`cli-tools-install.sh`](cli-tools/cli-tools-install.sh)

Installs and verifies **46 CLI tools** on a Proxmox VE host across five categories: system monitoring, storage, networking, shell/dev tools, and X11 display dependencies.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

---

### 2. PVE Drive Cleanup & Initialization
**Directory:** [`pve-drive-init/`](pve-drive-init/)
**Script:** [`drive_init.sh`](pve-drive-init/drive_init.sh)

Scans all drives, identifies remnant data from previous systems (ZFS, LVM, Ceph, mdadm, old partition tables), and performs a thorough 7-step multi-pass wipe. System drives are always protected. Requires a single `YES` confirmation before any data is touched.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-drive-init/drive_init.sh)
```

---

### 3. Drive Inventory Report Generator
**Directory:** [`drive-inventory/`](drive-inventory/)
**Script:** [`generate_drive_inventory.sh`](drive-inventory/generate_drive_inventory.sh)

Scans all storage devices and generates a comprehensive markdown inventory report — drive count, capacity totals, media classification, serial numbers, storage topology, LVM, and ZFS pool status. Live per-drive progress shown in terminal.

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/drive-inventory/generate_drive_inventory.sh)
```

---

### 4. PVE Cluster Node Removal
**Directory:** [`pve-node-remove/`](pve-node-remove/)
**Script:** [`pve_node_remove.sh`](pve-node-remove/pve_node_remove.sh)

Safely removes a node from a Proxmox VE cluster. Scans all cluster nodes, presents an interactive selection menu, then performs complete removal including cluster membership, SSH keys, /etc/hosts configuration, and cleanup of the removed node to standalone status.

**Preflight Requirements:**
- Healthy cluster with quorum
- Root SSH access to ALL nodes
- VMs/containers migrated off target node
- No HA resources on target node

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh)
```

---

### 5. Raspberry Pi Setup
**Directory:** [`pi-setup/`](pi-setup/)
**Script:** [`pi-setup.sh`](pi-setup/pi-setup.sh)

> ⚠ **RASPBERRY PI HARDWARE ONLY** (armhf / arm64)
> Supported OS: **Raspberry Pi OS**, **Ubuntu Desktop/Server**, **Kali Linux ARM**, **Debian ARM**
> NOT compatible with Proxmox VE or x86/x86_64 systems.
>
> **IMPORTANT:** Must be run with `sudo bash <(curl -s URL)` — not curl alone.

Complete Raspberry Pi setup: **40+ Kali Linux security tools**, **XFCE remote desktop** (TigerVNC on port 5901), and **full performance tuning** (CPU governor, sysctl, overclock, disabled services). Auto-detects Pi model (Pi 1/2/3B/3B+/4/5/Zero/Zero 2W) AND OS (Raspberry Pi OS / Ubuntu / Kali / Debian) and adapts all settings accordingly. **apt only — snapd explicitly blocked.**

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

---

### 6. Technitium DNS Server — Full Installation
**Directory:** [`dns-server/`](dns-server/)
**Script:** [`technitium-dns-install.sh`](dns-server/technitium-dns-install.sh)

> **Full installer** — installs Technitium DNS Server from scratch on any Debian-based LXC/VM.
> Configures split-horizon DNS with VLAN zones for UniFi network integration.

**Features:**
- Installs Technitium DNS Server from official source
- Creates admin account and authenticates via API
- Configures recursion and upstream forwarders
- Creates primary zone + VLAN sub-zones + backend zones (for SSL proxy)
- Creates reverse DNS zones
- Enables RFC 2136 dynamic updates
- Configures firewall rules

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-install.sh)
```

*Post-install configuration script also available:* [`dns-server-install.sh`](dns-server/dns-server-install.sh)

---

### 7. Nginx Proxy Manager — Full Installation & Dynamic SSL Proxy
**Directory:** [`npm-reverse-proxy/`](npm-reverse-proxy/)
**Script:** [`nginx-proxy-manager-install.sh`](npm-reverse-proxy/nginx-proxy-manager-install.sh)

> **Full installer** — installs Nginx Proxy Manager from scratch with dynamic SSL proxy.
> Provides valid HTTPS for any internal server via a single wildcard certificate.

**Features:**
- Installs Docker and NPM container (or native installation)
- Creates admin account and authenticates via API
- Requests wildcard Let's Encrypt certificate (DNS challenge via Cloudflare)
- Configures dynamic SSL proxy with Lua SRV resolver
- Automatically routes HTTPS requests to backend servers via SRV records
- Configures firewall rules

**How the Dynamic SSL Proxy Works:**
1. Browser requests `https://server.vlan.domain.tld`
2. DNS returns the proxy server's IP
3. Wildcard certificate validates the connection
4. Lua script queries SRV record for backend target + port
5. Request is proxied to the real server with valid SSL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

*Post-install configuration script also available:* [`npm-reverse-proxy-install.sh`](npm-reverse-proxy/npm-reverse-proxy-install.sh)

---

### 8. Kali-Style Prompt Installer (Linux)
**Directory:** [`kali-prompt/`](kali-prompt/)
**Script:** [`kali-prompt-install.sh`](kali-prompt/kali-prompt-install.sh)

> **Universal Linux Support** — works on Ubuntu, Debian, RHEL, Rocky, Fedora, and derivatives.
> Auto-detects user shell (bash/zsh) and configures accordingly.

Installs the iconic **Kali Linux-style command prompt** — bold red username@hostname with blue working directory. Creates backups of all modified files and includes comprehensive logging.

**Features:**
- Multi-distribution support (Debian/RHEL families)
- Auto-detects and configures bash and/or zsh
- Idempotent — safe to run multiple times
- Creates timestamped backups
- Includes color-enabled aliases (ls, grep, etc.)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

---

### 9. Kali-Style Prompt Installer (macOS)
**Directory:** [`kali-prompt-macos/`](kali-prompt-macos/)
**Script:** [`kali-prompt-macos-install.sh`](kali-prompt-macos/kali-prompt-macos-install.sh)

> 🍎 **macOS 12.7.6 (Monterey) or later** — supports both Intel and Apple Silicon Macs.
> Auto-detects user shell (zsh/bash) and configures accordingly.

Installs the iconic **Kali Linux-style command prompt** on macOS — bold red username@hostname with blue working directory. Specifically adapted for macOS with BSD `ls -G` colors and `CLICOLOR`/`LSCOLORS` environment variables.

**Features:**
- Supports macOS 12.7.6+ (Monterey, Ventura, Sonoma, Sequoia)
- Intel (x86_64) and Apple Silicon (arm64) support
- Configures both zsh (macOS default) and bash
- Uses BSD color flags (-G) for ls
- Idempotent — safe to run multiple times
- Creates timestamped backups

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

---

### 10. PVE VM & CT Cleanup
**Directory:** [`pve-vm-ct-cleanup/`](pve-vm-ct-cleanup/)
**Script:** [`pve_vm_ct_cleanup.sh`](pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)

> ⚠ **IRREVERSIBLE OPERATION** — All data will be permanently destroyed.
> No undo. Backups deleted. Snapshots removed.

Completely removes a VM or container from Proxmox VE, including **all** associated resources. Presents an interactive menu to select from discovered VMs and CTs, then performs an 8-step comprehensive cleanup with multi-layer confirmation.

**Features:**
- Interactive selection of all VMs and containers
- Multi-layer confirmation (VMID entry + "DESTROY" keyword)
- Complete cleanup: Stop → Remove HA → Remove replication → Remove snapshots → Remove backups → Remove storage → Delete guest → Verify removal
- Full operation logging to `/var/log/`
- Supports PVE 8.x and 9.x

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
```

---

### 11. Technitium DNS Server — Standalone LXC Installation
**Directory:** [`dns-server/`](dns-server/)
**Script:** [`technitium-dns-standalone.sh`](dns-server/technitium-dns-standalone.sh)

> **Standalone installer** — creates LXC container and installs Technitium DNS in one command.
> Runs from Proxmox node — no existing LXC required.

**Features:**
- Creates Debian 13 LXC container (2 CPU, 2GB RAM, 8GB disk)
- Installs Technitium DNS Server with .NET 9.0 runtime
- Installs 5 pre-configured apps:
  - Advanced Blocking v10
  - Auto PTR v4
  - Drop Requests v7
  - Log Exporter v2.1
  - Query Logs (Sqlite) v8
- Configures 4 Hagezi blocklists (multi, popupads, tif, fake)
- Privacy-first root hints recursion (no external forwarders)
- QNAME minimization enabled
- Auto-detects storage pools
- No configuration prompts — enterprise defaults

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/technitium-dns-standalone.sh)
```

*Full installer with UniFi integration also available:* [`technitium-dns-install.sh`](dns-server/technitium-dns-install.sh)

---

### 12. Technitium DNS Server — Generic Installer
**Directory:** [`install/`](install/)
**Script:** [`technitiumdnsgeneric-install.sh`](install/technitiumdnsgeneric-install.sh)

> **Generic installer** — installs Technitium DNS with hardcoded 5-app configuration.
> For testing and generic deployments. NOT a replication script.

**Features:**
- Installs .NET ASP.NET Core 10.0 runtime
- Installs Technitium DNS Server (latest portable version)
- Installs 5 hardcoded apps:
  - Advanced Blocking
  - DNS Block List (DNSBL)
  - Failover
  - Geo Country
  - What Is My Dns
- Configures recursion for all networks
- Enables query logging in UTC time
- Disables systemd-resolved to free port 53
- Auto-starts service on boot

**Requirements:**
- Debian 13 (Trixie) or compatible
- Root access
- Internet connectivity

```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/install/technitiumdnsgeneric-install.sh | bash
```

**⚠ Limitations:**
- Hardcoded app list (5 apps only)
- Generic configuration (not environment-specific)
- No replication capability
- Single OS support (Debian 13 Trixie)

For production replication that queries an existing server's API and duplicates its configuration, use a dedicated replication script instead.

---

## Visual Standard

All scripts share the same Van Auken Tech visual identity:

| Element | Style |
|---------|-------|
| Header | figlet "small" font — VANAUKEN TECH |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` |
| Section dividers | `── Section Name ──────────...` (cyan/bold) |
| Status symbols | ✔ green · ✘ red · ⚠ yellow · ◆ cyan · ▸ cyan |
| Summary block | `════════` style (cyan/bold) |
| Footer | `────────` with host + timestamp |

## Requirements

- Scripts 1–4, 10–11: Proxmox VE 8.x (Debian Bookworm) or 9.x (Debian Trixie) · Root access
- Script 5: Raspberry Pi hardware (armhf / arm64) · Raspberry Pi OS / Ubuntu / Kali Linux ARM / Debian · **sudo** required
- Scripts 6–7: Requires LXC already deployed via community-scripts.org · Root access · Network access to LXC IP
- Script 8: Any Linux distribution (Ubuntu, Debian, RHEL, Rocky, Fedora, derivatives) · User-level access
- Script 9: macOS 12.7.6+ (Monterey or later) · Intel or Apple Silicon · User-level access
- All scripts require internet connectivity. Missing dependencies are auto-installed.

---

*Van Auken Tech · Thomas Van Auken*