# Van Auken Tech — Raspberry Pi Setup

> Created by: Thomas Van Auken — Van Auken Tech

---

> ## ⚠  RASPBERRY PI ONLY
> This script is designed **exclusively** for **Raspbian GNU/Linux** running on a Raspberry Pi.
>
> - ✅ Supported: Raspbian Bookworm (12), Trixie (13) — armhf or arm64
> - ✅ Tested on: Pi 3B, Pi 3B+, Pi 4, Pi 5, Zero 2W
> - ❌ NOT compatible with: Proxmox VE, Ubuntu, x86 Debian, Kali Linux, or any non-Pi system
>
> **Running this on a non-Pi system will fail the architecture check and exit.**

---

## One-Liner

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

---

## What It Does

A single script that transforms a fresh Raspbian Raspberry Pi into a complete Kali Linux-style security workstation with a high-performance XFCE remote desktop.

| Section | Description |
|---------|-------------|
| 1 | **Hardware Detection** — auto-detects Pi model, RAM, arch, boot config path |
| 2 | **Reboot Prevention** — holds kernel packages, disables unattended-upgrades |
| 3 | **System Update** — apt update/upgrade (kernel held) + base dependencies |
| 4 | **Security Tools** — 40+ Kali tools from Raspbian repos (nmap, sqlmap, hydra, metasploit...) |
| 5 | **Python Tools** — impacket, scapy, theHarvester in isolated venv |
| 6 | **Ruby Tools** — wpscan via gem |
| 7 | **Go Binaries** — nuclei, subfinder, httpx (pre-built ARM — no compilation) |
| 8 | **Kali Repository** — kali-rolling (pinned at priority 100) + Metasploit Framework |
| 9 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords) |
| 10 | **XFCE + TigerVNC** — headless XFCE desktop, VNC on port 5901, auto-start service |
| 11 | **Performance Tuning** — CPU governor, sysctl, disabled services, boot config, overclock |
| 12 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins |
| 13 | **Verification** — checks all 40+ tools and VNC service |

---

## Performance Tuning Applied

### Live (no reboot required)
- CPU governor → `performance` (eliminates frequency scaling latency)
- XFCE compositor disabled (major VNC responsiveness improvement)
- Pulseaudio disabled (~19MB RAM freed on headless server)
- sysctl: `vm.swappiness=100`, `vm.vfs_cache_pressure=50`, `vm.dirty_ratio=5`
- TCP buffers and `somaxconn` tuned for remote desktop throughput
- Services disabled: bluetooth, ModemManager, avahi-daemon, colord, rpi-eeprom-update, rtkit-daemon

### After Reboot
- GPU memory reduced to **16MB** (frees RAM for tools and desktop)
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
- Unused hardware disabled: camera, display, audio, splash

---

## Remote Desktop (VNC)

- **Server:** TigerVNC on display `:1` (port `5901`)
- **Resolution:** 1920×1080 (1280×720 on <768MB RAM devices)
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Auto-start:** `vncserver@1.service` enabled in systemd
- **Recovery:** `Restart=on-failure` with 10-second delay

```bash
# Manage VNC
vnc-status     # check service status
vnc-restart    # restart VNC server
vnc-log        # follow live service log
vncpasswd      # change VNC password
```

---

## Requirements

- Raspberry Pi (any model — script auto-adapts)
- Raspbian GNU/Linux 12 (Bookworm) or 13 (Trixie)
- armhf or arm64 architecture
- Root or sudo access
- Internet connectivity
- 3GB+ free disk space (10GB+ recommended)

---

## After Running

1. **Reboot:** `sudo reboot` (activates GPU/overclock settings)
2. **Connect via VNC:** `<your-pi-ip>:5901`
3. **Change VNC password:** `vncpasswd`
4. **Init Metasploit DB:** `sudo msfdb init`
5. **Update nuclei templates:** `nuclei -update-templates`

---

*Van Auken Tech · Thomas Van Auken*
