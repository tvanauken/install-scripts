# Van Auken Tech — Raspberry Pi Setup · User Manual
**Script:** `pi-setup.sh` · **Version:** 1.1.3
**Author:** Thomas Van Auken — Van Auken Tech
**Updated:** 2026-03-29

---

## Supported Hardware & Operating Systems

This script runs on **Raspberry Pi hardware only** (armhf or arm64).

| OS | Versions | Arch | Status |
|---|---|---|---|
| **Raspberry Pi OS** (Raspbian) | Bookworm 12, Trixie 13 | armhf · arm64 | ✅ Tested |
| **Ubuntu Desktop** | 22.04 LTS, 24.04 LTS | arm64 | ✅ Tested |
| **Ubuntu Server** | 22.04 LTS, 24.04 LTS | arm64 | ✅ Tested |
| **Kali Linux ARM Desktop** | Rolling | arm64 | ✅ Supported |
| **Debian ARM** | Bookworm, Trixie | armhf · arm64 | ✅ Supported |

❌ NOT compatible with: x86/x86_64, Proxmox VE, non-apt distros
Package manager: **apt only** — snapd is blocked and purged on every run.

---

## Running the Script

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

### ⚠ All three parts are required

| Part | Why |
|------|-----|
| `sudo` | Script requires root — exits immediately without it |
| `bash <(` | Downloads and executes the script |
| `curl -s URL` | Downloads the script from GitHub |

---

## What the Script Installs — All 16 Sections

| Section | What Happens |
|---------|-------------|
| 1 | **Hardware Detection** — Pi model, RAM, arch, boot config path |
| 2 | **OS Detection** — identifies Kali/Ubuntu/Raspbian/Debian; adapts logic |
| 3 | **Preflight** — root, ARM arch gate, apt, disk, internet, target user |
| 4 | **Snap Prevention** — `Pin-Priority: -1` permanent APT block, purge if present |
| 5 | **Reboot Prevention** — holds kernel packages, disables unattended-upgrades |
| 6 | **System Update** — `apt update/upgrade`; Ubuntu universe+multiverse enabled |
| 7 | **Security Tools** — 40+ tools from distro repos; graceful per-package failure |
| 8 | **Python Tools** — isolated venv `/opt/security-venv`: impacket, scapy, theHarvester |
| 9 | **Ruby Tools** — wpscan via `gem install --no-document` |
| 10 | **Go Binaries** — pre-built ARM: nuclei, subfinder, httpx, naabu, feroxbuster |
| 11 | **Kali Repository + Metasploit** — kali-rolling at priority 100; dpkg state repaired |
| 12 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords) |
| 13 | **XFCE4 + TigerVNC** — root session, VNC port 5901, started immediately |
| 14 | **Performance Tuning** — CPU governor, sysctl, services, boot config, overclock |
| 15 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins |
| 16 | **Verification** — all tools checked, VNC confirmed running |

---

## Enterprise Design

### Services Run as Root

All systemd services installed by this script run as `User=root`. This is standard
practice for a dedicated security workstation:

| Service | User | Why |
|---------|------|-----|
| `vncserver@1.service` | root | Security tools need root; no file permission issues |
| `cpu-performance-governor.service` | root | System-level CPU tuning |

### VNC Starts Immediately — No Reboot Required for VNC

VNC is started during the install script. You can connect before rebooting.
Reboot only activates the boot config changes (GPU memory, CPU overclock).

### Crash Recovery

All services include:
```ini
Restart=on-failure
RestartSec=10
```
And `ExecStartPre` removes stale X lock files before every start. If VNC crashes
for any reason, systemd automatically recovers it within 10 seconds.

---

## Connecting via VNC

- **Address:** `<pi-ip>:5901`
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Desktop:** XFCE4 as root (compositor disabled for VNC performance)
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)

### Managing VNC

```bash
vnc-status     # systemctl status vncserver@1
vnc-start      # start VNC server
vnc-stop       # stop VNC server
vnc-restart    # restart VNC server
vnc-log        # journalctl -u vncserver@1 -f
vncpasswd      # change VNC password
```

### Troubleshooting VNC

```bash
vnc-log                                          # check for errors
journalctl -u vncserver@1 --no-pager -n 50      # full boot log
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1      # clear stale locks (manual)
vnc-restart                                      # restart after fix
sudo ufw allow 5901/tcp                          # if firewall is blocking
```

Note: Stale lock files are cleared automatically by `ExecStartPre` on every service
start. Manual clearing should only be needed in unusual circumstances.

---

## OS-Specific Behaviour

### Raspberry Pi OS (Raspbian)
- All tools directly in repos; kali-defaults held for dpkg conflict prevention
- Boot config at `/boot/config.txt` or `/boot/firmware/config.txt`

### Ubuntu Desktop / Server
- `universe` and `multiverse` enabled before any install
- snapd purged and blocked (Ubuntu ships snapd by default)
- Boot config at `/boot/firmware/config.txt`

### Kali Linux ARM Desktop
- kali-rolling pre-configured — GPG key and repo addition skipped
- kali-defaults hold not applied; metasploit checked for existing install

### All Distros
- After Kali repo section, dpkg state fully repaired:
  `wordlists` force-removed from dpkg tracking; `rockyou.txt` preserved on disk

---

## Snap Prevention

```
/etc/apt/preferences.d/99no-snap:
  Package: snapd
  Pin: release a=*
  Pin-Priority: -1
```

- Cannot be installed via apt
- Cannot be pulled in as a dependency
- Block survives reboots and upgrades
- If already installed: purged, all snap directories removed

---

## Security Tools Quick Reference

```bash
nmap-quick <ip>          # nmap -sV -sC
nmap-full  <ip>          # all 65535 ports
nmap-sweep <subnet>      # ping sweep
nmap-vuln  <ip>          # vulnerability scripts
msf                      # msfconsole (root session)
msfdb init               # first-time database setup
searchsploit <term>      # search exploit database
sqlmap-full -u <url>     # sqlmap batch, level 5, risk 3
nuclei -u <url>          # vulnerability templates scan
subfinder -d <domain>    # subdomain enumeration
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://<ip>
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
wordlists                # list /usr/share/wordlists/
piinfo                   # system overview
```

---

## Performance Tuning Details

| Setting | Value | Why |
|---------|-------|-----|
| CPU governor | `performance` | Eliminates VNC frequency-scaling latency |
| XFCE compositor | Disabled | Biggest single VNC responsiveness improvement |
| Pulseaudio | Disabled | ~19MB freed; no audio on headless server |
| `vm.swappiness` | 100 | Pi uses zram — aggressively swapping to compressed RAM is fast |
| `vm.vfs_cache_pressure` | 50 | Retains more filesystem cache; reduces SD reads |
| `vm.dirty_ratio` | 5 | Flushes writes to SD sooner — reduces data loss window |
| GPU memory | 16MB | Frees 60MB+ RAM (default 76MB on Pi 3) |
| CPU overclock | Model-specific | Safe tested values per Pi model |
| `vc4-kms-v3d` | Disabled | GPU driver not loaded for headless — saves RAM |

---

## Maintenance

```bash
update                     # sudo apt update && apt upgrade -y
msfupdate                  # Metasploit (run in VNC terminal as root)
nuclei -update-templates   # nuclei templates
sudo searchsploit -u       # exploit database
wpscan --update            # wpscan database
```

---

## Key File Locations

```
/usr/local/bin/kali-pi-banner       Dynamic login banner
/etc/zsh/zshrc                      System ZSH: banner on login + clear override
~/.zshrc  /root/.zshrc              Personal ZSH: prompt, aliases, tools
/etc/motd                           SSH login message
/etc/issue.net                      SSH pre-login banner

/root/.vnc/passwd                   VNC password (root session)
/root/.vnc/xstartup                 VNC XFCE4 startup script
/var/log/vncserver.log              VNC server log

/usr/share/wordlists/rockyou.txt    Password wordlist (134MB)
/usr/share/exploitdb/               searchsploit database
/usr/share/metasploit-framework/    Metasploit Framework
/opt/security-venv/                 Python security tools venv

/var/log/van-auken-pi-setup-*.log   Full installation log

/etc/systemd/system/vncserver@.service         VNC service (User=root)
/etc/systemd/system/cpu-performance-governor.service  CPU governor
/etc/apt/preferences.d/99no-snap    snapd permanent block
/etc/apt/preferences.d/kali-pin     Kali APT priority (100)
/etc/apt/apt.conf.d/99no-autoreboot Auto-reboot prevention
/etc/sysctl.d/99-van-auken-pi.conf  Kernel tuning
/boot/firmware/config.txt           Boot config (Pi 4/5)
/boot/config.txt                    Boot config (Pi 3 and older)
```

---

*Thomas Van Auken — Van Auken Tech · v1.1.3 · 2026-03-29*
