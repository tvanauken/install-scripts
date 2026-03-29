# Van Auken Tech — Raspberry Pi Setup

> Created by: Thomas Van Auken — Van Auken Tech
> **Current Version:** 1.1.3

---

## ⚠ Raspberry Pi Hardware Required (armhf / arm64)

| OS | Versions | Arch | Status |
|---|---|---|---|
| **Raspberry Pi OS** (Raspbian) | Bookworm 12, Trixie 13 | armhf · arm64 | ✅ Tested |
| **Ubuntu Desktop** | 22.04 LTS, 24.04 LTS | arm64 | ✅ Tested |
| **Ubuntu Server** | 22.04 LTS, 24.04 LTS | arm64 | ✅ Tested |
| **Kali Linux ARM Desktop** | Rolling | arm64 | ✅ Supported |
| **Debian ARM** | Bookworm, Trixie | armhf · arm64 | ✅ Supported |

❌ NOT compatible with: x86/x86_64 systems, Proxmox VE, non-apt distros

Package manager: **apt only** — snapd is permanently blocked and purged.

---

# ╔══════════════════════════════════════════════════════════╗
# ║  RUN COMMAND — COPY THIS EXACTLY, ALL THREE PARTS        ║
# ╚══════════════════════════════════════════════════════════╝

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

> ## ⚠ CRITICAL — ALL THREE PARTS ARE REQUIRED
>
> **1. `sudo`** — the script must run as root. Without it the script exits immediately.
>
> **2. `bash <(`** — tells bash to download and execute the script.
> Do NOT run `curl ...` alone. Do NOT run `(curl ...)` alone.
>
> **3. `curl -s URL`** — downloads the script from GitHub.
>
> ### ❌ These are WRONG and will NOT work:
> ```bash
> curl -s https://...                   # downloads only, does not run
> (curl -s https://...)                 # subshell — does nothing useful
> ```
> ### ✅ The ONLY correct form:
> ```bash
> sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
> ```

---

## What It Does — All 16 Sections

| Section | Description |
|---------|-------------|
| 1 | **Hardware Detection** — Pi model (Pi 1/2/3B/3B+/4/5/Zero/Zero 2W), RAM, arch, boot config path |
| 2 | **OS Detection** — auto-adapts for Raspberry Pi OS / Ubuntu / Kali / Debian |
| 3 | **Preflight** — root check, ARM arch gate, apt check, disk, internet, target user |
| 4 | **Snap Prevention** — snapd permanently blocked at APT layer (Pin-Priority -1), purged |
| 5 | **Reboot Prevention** — kernel hold, unattended-upgrades disabled |
| 6 | **System Update** — apt update/upgrade; enables Ubuntu universe+multiverse |
| 7 | **Security Tools** — 40+ tools from distro repos with graceful per-package failure |
| 8 | **Python Tools** — isolated venv at `/opt/security-venv`: impacket, scapy, theHarvester |
| 9 | **Ruby Tools** — wpscan via `gem install` |
| 10 | **Go Binaries** — pre-built ARM: nuclei, subfinder, httpx, naabu, feroxbuster |
| 11 | **Kali Repository + Metasploit** — kali-rolling at priority 100 + Metasploit Framework |
| 12 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords) |
| 13 | **XFCE4 + TigerVNC** — headless root session, VNC port 5901, starts immediately, survives reboot/crash |
| 14 | **Performance Tuning** — CPU governor, sysctl, disabled services, boot config, overclock |
| 15 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins |
| 16 | **Verification** — checks all 40+ tools and VNC service |

---

## Enterprise Design Decisions

### All Services Run as Root
Every systemd service installed by this script runs as `User=root`. This is correct
for a dedicated security workstation:
- All security tools (nmap raw sockets, msfconsole, airmon-ng) require root anyway
- No file permission issues with log files or system directories
- VNC config stored in `/root/.vnc/` — clean and unambiguous

### VNC Starts Immediately — No Reboot Required
The VNC service is started during install. You can connect via VNC before rebooting.
Reboot is only required to activate the boot config tuning (GPU memory, overclock).

### Crash Recovery Built In
All services have `Restart=on-failure` and `RestartSec=10`. If VNC crashes for any
reason (stale lock files, X error, etc.), systemd automatically restarts it within 10 seconds.
`ExecStartPre` clears stale X lock files before every start.

### apt Only — No Snap Ever
Snapd is blocked at the APT resolver layer with `Pin-Priority: -1`. This cannot be
overridden by accident. On Ubuntu, snapd is purged and all snap directories removed.

---

## Tested On

| Host | Hardware | OS | Arch | Result |
|------|----------|----|------|--------|
| underworld | Pi 3B | Raspbian Trixie 13 | armhf | ✅ v1.0.0 — all tools, VNC, performance tuning |
| boron | Pi 5 Model B Rev 1.0 | Ubuntu 24.04.4 LTS | arm64 | ✅ v1.1.3 — all tools, XFCE+VNC as root confirmed |

---

## Performance Tuning Applied

### Live (no reboot needed)
- CPU governor → `performance`
- XFCE compositor disabled
- Pulseaudio disabled (~19MB RAM freed)
- sysctl: `vm.swappiness=100`, `vm.vfs_cache_pressure=50`, `vm.dirty_ratio=5`
- TCP buffers tuned for VNC throughput
- Services disabled: bluetooth, ModemManager, avahi-daemon, colord, rpi-eeprom-update, rtkit-daemon

### After Reboot
- GPU memory → **16MB** (frees 60MB+ RAM)
- CPU overclocked to safe model-specific values
- `vc4-kms-v3d` overlay disabled
- Unused hardware disabled: camera, display auto-detect, audio, splash

---

## Remote Desktop (VNC)

- **Service:** `vncserver@1.service` — runs as **root**, starts at boot
- **Server:** TigerVNC on display `:1` — port **5901**
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Recovery:** `Restart=on-failure` + `RestartSec=10` + stale lock file cleanup

```bash
vnc-status     # service status
vnc-restart    # restart server
vnc-log        # follow live log
vncpasswd      # change password
```

---

## After Running

```bash
# VNC is already running — connect immediately:
# <pi-ip>:5901  password: VanAwsome1
vncpasswd                      # CHANGE the default password
msfdb init                     # first-time Metasploit DB setup (as root in VNC terminal)
nuclei -update-templates       # update nuclei scan templates
piinfo                         # ZSH alias: system overview
sudo reboot                    # optional: activate GPU + overclock settings
```

---

## Requirements

- Raspberry Pi (any supported model — auto-detected)
- Supported OS (see table above)
- armhf or arm64 architecture
- **Root or sudo access** — script exits immediately without it
- Internet connectivity
- 3GB+ free disk space (10GB+ recommended)

---

*Van Auken Tech · Thomas Van Auken · v1.1.3*
