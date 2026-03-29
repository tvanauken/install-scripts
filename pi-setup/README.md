# Van Auken Tech — Raspberry Pi Setup

> Created by: Thomas Van Auken — Van Auken Tech
> **Current Version:** 1.1.2

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
> **2. `bash <(`** — tells bash to download and pipe the script for execution.
> Do NOT run `curl ...` alone. Do NOT run `(curl ...)` alone.
>
> **3. `curl -s URL`** — downloads the script from GitHub.
>
> ### ❌ These are WRONG and will NOT work:
> ```bash
> curl -s https://...                   # downloads only, does not run
> (curl -s https://...)                 # curl in a subshell — does nothing useful
> bash https://...                      # bash cannot take a URL directly
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
| 13 | **XFCE4 + TigerVNC** — headless XFCE desktop, VNC port 5901, systemd auto-start |
| 14 | **Performance Tuning** — CPU governor, sysctl, disabled services, boot config, overclock |
| 15 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins |
| 16 | **Verification** — checks all 40+ tools and VNC service |

---

## Tested On

| Host | Hardware | OS | Arch | Result |
|------|----------|----|----|--------|
| underworld | Pi 3B | Raspbian Trixie 13 | armhf | ✅ v1.0.0 — all tools, VNC, perf tuning |
| boron | Pi 5 Model B Rev 1.0 | Ubuntu 24.04.4 LTS | arm64 | ✅ v1.1.2 — all tools, XFCE+VNC confirmed |

---

## Performance Tuning Applied

### Live (no reboot needed)
- CPU governor → `performance` (eliminates VNC frequency-scaling latency)
- XFCE compositor disabled (biggest single VNC responsiveness improvement)
- Pulseaudio disabled (~19MB RAM freed)
- sysctl: `vm.swappiness=100`, `vm.vfs_cache_pressure=50`, `vm.dirty_ratio=5`
- TCP buffers tuned for remote desktop throughput
- Services disabled: bluetooth, ModemManager, avahi-daemon, colord, rpi-eeprom-update, rtkit-daemon

### After Reboot
- GPU memory → **16MB** (frees 60MB+ RAM for tools and desktop)
- CPU overclocked to safe model-specific values:

  | Model | Default | Overclocked | over_voltage |
  |-------|---------|-------------|-------------|
  | Pi 5 | 2400 MHz | **2800 MHz** | 2 |
  | Pi 4 | 1500 MHz | **1800 MHz** | 2 |
  | Pi 3B | 1200 MHz | **1350 MHz** | 2 |
  | Pi 3B+ | 1400 MHz | **1400 MHz** | 0 (already max) |
  | Pi Zero 2W | 1000 MHz | **1100 MHz** | 2 |
  | Pi Zero | — | No overclock | — |

- `vc4-kms-v3d` overlay disabled (GPU driver not needed for headless VNC)
- Unused hardware disabled: camera, display auto-detect, audio, splash

---

## Remote Desktop (VNC)

- **Server:** TigerVNC on display `:1` — port **5901**
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Auto-start:** `vncserver@1.service` enabled in systemd
- **Recovery:** `Restart=on-failure` + `RestartSec=10` + stale lock cleanup

```bash
vnc-status     # service status
vnc-restart    # restart server
vnc-log        # follow live log
vncpasswd      # change password
```

---

## After Running

```bash
sudo reboot                    # activate GPU + overclock settings
# Connect VNC client to <pi-ip>:5901
vncpasswd                      # CHANGE the default password
sudo msfdb init                # first-time Metasploit DB setup
nuclei -update-templates       # update nuclei scan templates
piinfo                         # ZSH alias: system overview
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

*Van Auken Tech · Thomas Van Auken · v1.1.2*
