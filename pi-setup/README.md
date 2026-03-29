# Van Auken Tech — Raspberry Pi Setup

> Created by: Thomas Van Auken — Van Auken Tech

---

## ⚠ Raspberry Pi Hardware Required (armhf / arm64)

Supported operating systems:

| OS | Versions | Arch |
|---|---|---|
| **Raspberry Pi OS** (Raspbian) | Bookworm 12, Trixie 13 | armhf · arm64 |
| **Ubuntu Desktop** | 22.04 LTS, 24.04 LTS | arm64 |
| **Ubuntu Server** | 22.04 LTS, 24.04 LTS | arm64 |
| **Kali Linux ARM Desktop** | Rolling | arm64 |
| **Debian ARM** | Bookworm, Trixie | armhf · arm64 |

❌ NOT compatible with: x86 / x86_64 systems, Proxmox VE, non-apt distros

Package manager: **apt only** — snapd is explicitly blocked and purged.

---

# ╔══════════════════════════════════════════════════════════╗
# ║  RUN COMMAND — COPY THIS EXACTLY, ALL OF IT              ║
# ╚══════════════════════════════════════════════════════════╝

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

> ## ⚠ CRITICAL — THE COMMAND HAS THREE PARTS
>
> **1. `sudo`** — the script must run as root. Without `sudo` it will immediately exit.
>
> **2. `bash <(`** — this tells your shell to download the script and pipe it into bash.
> Do NOT run `curl ...` alone. Do NOT run `(curl ...)` alone. You need `bash <(curl ...)`.
>
> **3. `curl -s URL`** — downloads the script. The `-s` flag suppresses download noise.
>
> ### ❌ These are WRONG and will not work:
> ```bash
> curl -s https://...                        # downloads but does not run
> (curl -s https://...)                      # runs curl in a subshell — does nothing useful
> bash https://...                           # bash cannot take a URL directly
> sudo curl -s https://... | bash            # works but loses process substitution
> ```
> ### ✅ This is the ONLY correct form:
> ```bash
> sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
> ```

---

## What It Does

A single script that transforms a fresh Raspberry Pi into a complete Kali Linux-style security workstation with a high-performance XFCE remote desktop. Auto-detects the Pi model and OS and adapts all settings accordingly.

| Section | Description |
|---------|-------------|
| 1 | **Hardware Detection** — Pi model, arch, RAM, boot config path |
| 2 | **OS Detection** — auto-adapts for Raspberry Pi OS / Ubuntu / Kali / Debian |
| 3 | **Preflight** — root check, arch gate, disk/internet checks |
| 4 | **Snap Prevention** — snapd blocked at APT layer, purged if present |
| 5 | **Reboot Prevention** — kernel hold, unattended-upgrades disabled |
| 6 | **System Update** — apt update/upgrade + base dependencies |
| 7 | **Security Tools** — 40+ tools (nmap, hydra, sqlmap, aircrack-ng, etc.) |
| 8 | **Python Tools** — impacket, scapy, theHarvester in isolated venv |
| 9 | **Ruby Tools** — wpscan via gem |
| 10 | **Go Binaries** — nuclei, subfinder, httpx (pre-built ARM — no compilation) |
| 11 | **Kali Repository** — kali-rolling at priority 100 + Metasploit Framework |
| 12 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords) |
| 13 | **XFCE + TigerVNC** — headless desktop, VNC port 5901, systemd auto-start |
| 14 | **Performance Tuning** — CPU governor, sysctl, services, boot config, overclock |
| 15 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins |
| 16 | **Verification** — checks all tools and VNC service |

---

## Performance Tuning Applied

### Live (active immediately, no reboot needed)
- CPU governor → `performance` (eliminates frequency-scaling VNC latency)
- XFCE compositor disabled (single biggest VNC responsiveness gain)
- Pulseaudio disabled (~19MB RAM freed on headless server)
- sysctl: `vm.swappiness=100`, `vm.vfs_cache_pressure=50`, `vm.dirty_ratio=5`
- TCP buffers tuned for remote desktop + security tool throughput
- Services disabled: bluetooth, ModemManager, avahi-daemon, colord, rpi-eeprom-update, rtkit-daemon

### After Reboot (requires `sudo reboot`)
- GPU memory reduced to **16MB** (frees RAM for tools and desktop)
- CPU overclocked to tested safe values per model:

  | Model | Default | Overclocked | over_voltage |
  |---|---|---|---|
  | Pi 5 | 2400 MHz | **2800 MHz** | 2 |
  | Pi 4 | 1500 MHz | **1800 MHz** | 2 |
  | Pi 3B | 1200 MHz | **1350 MHz** | 2 |
  | Pi 3B+ | 1400 MHz | **1400 MHz** | 0 (already max) |
  | Pi Zero 2W | 1000 MHz | **1100 MHz** | 2 |
  | Pi Zero | — | No overclock | — |

- `vc4-kms-v3d` overlay disabled (GPU driver not needed for headless VNC)
- Unused hardware disabled: camera, display auto-detect, audio, splash screen

---

## Remote Desktop (VNC)

- **Server:** TigerVNC on display `:1` — port **5901**
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Auto-start:** `vncserver@1.service` enabled in systemd (survives reboots)
- **Recovery:** `Restart=on-failure` + `RestartSec=10`

```bash
vnc-status     # service status
vnc-restart    # restart server
vnc-log        # follow live log
vncpasswd      # change password
```

---

## After Running

```bash
sudo reboot                       # activate GPU + overclock settings
# Then connect your VNC client to <pi-ip>:5901
vncpasswd                         # CHANGE THE DEFAULT PASSWORD
sudo msfdb init                   # first-time Metasploit DB setup
nuclei -update-templates          # update vulnerability scan templates
piinfo                            # ZSH alias: system overview
```

---

## Requirements

- Raspberry Pi (any model — script auto-adapts)
- Supported OS (see table above)
- armhf or arm64 architecture
- **Root or sudo access** (required — script exits immediately without it)
- Internet connectivity
- 3GB+ free disk space (10GB+ recommended for full toolset)

---

*Van Auken Tech · Thomas Van Auken*
