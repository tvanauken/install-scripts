# Van Auken Tech — Raspberry Pi Setup · User Manual
**Script:** `pi-setup.sh` · **Version:** 1.1.2
**Author:** Thomas Van Auken — Van Auken Tech
**Updated:** 2026-03-29

---

## Supported Hardware & Operating Systems

This script runs on **Raspberry Pi hardware only** (armhf or arm64 ARM architecture).
The architecture check is the definitive gate — if the hardware is a Pi, the OS is the choice.

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

### ⚠ The command has three parts — all required

| Part | Why |
|------|-----|
| `sudo` | Script must run as root — exits immediately without it |
| `bash <(` | Process substitution: downloads and executes the script |
| `curl -s URL` | Downloads the script from GitHub |

**Wrong:**
```bash
curl -s https://...            # downloads only, does not run
(curl -s https://...)          # subshell — does nothing useful
```
**Right:**
```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

---

## What the Script Installs — All 16 Sections

| Section | What Happens |
|---------|-------------|
| 1 | **Hardware Detection** — Pi model (1/2/3B/3B+/4/5/Zero/Zero2W), RAM, arch, boot config path |
| 2 | **OS Detection** — identifies Kali/Ubuntu/Raspbian/Debian; sets flags for conditional logic |
| 3 | **Preflight** — root, ARM arch gate, apt check, disk, internet (multi-endpoint), target user |
| 4 | **Snap Prevention** — snapd `Pin-Priority: -1` (permanent APT block), purged if present |
| 5 | **Reboot Prevention** — holds kernel packages, disables unattended-upgrades auto-reboot |
| 6 | **System Update** — `apt update/upgrade`; enables Ubuntu universe+multiverse if needed |
| 7 | **Security Tools** — 40+ tools from distro repos; graceful per-package failure |
| 8 | **Python Tools** — isolated venv `/opt/security-venv`: impacket, scapy, theHarvester, etc. |
| 9 | **Ruby Tools** — wpscan via `gem install --no-document` |
| 10 | **Go Binaries** — pre-built ARM binaries: nuclei, subfinder, httpx, naabu, feroxbuster |
| 11 | **Kali Repository + Metasploit** — kali-rolling at priority 100; dpkg state fully repaired |
| 12 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords); SecLists documented as manual |
| 13 | **XFCE4 + TigerVNC** — headless XFCE4, VNC port 5901, systemd service, auto-recovery |
| 14 | **Performance Tuning** — CPU governor, sysctl, disabled services, boot config, overclock |
| 15 | **ZSH Shell** — Kali-style prompt, Van Auken Tech banner, aliases, plugins, MOTD |
| 16 | **Verification** — checks all tools, VNC service, snapd block |

---

## OS-Specific Behaviour

### Raspberry Pi OS (Raspbian)
- All tools directly available in repos
- kali-defaults held to prevent dpkg diversion conflict with raspberrypi-sys-mods
- Boot config at `/boot/config.txt` or `/boot/firmware/config.txt`

### Ubuntu Desktop / Server
- `universe` and `multiverse` repos enabled automatically before any install
- snapd purged and blocked (Ubuntu ships snapd by default)
- Boot config at `/boot/firmware/config.txt`

### Kali Linux ARM Desktop
- kali-rolling repository already configured — GPG key and repo setup skipped
- kali-defaults hold not applied (legitimate Kali package)
- Metasploit checked for existing install before attempting reinstall

### All Distros
- After Kali repo section, dpkg state is fully repaired:
  `wordlists` package (stuck unpacked) is force-removed from dpkg tracking;
  `rockyou.txt` file remains on disk. This ensures XFCE4 and TigerVNC
  can install cleanly regardless of distro.

---

## Snap Prevention

Snapd is **permanently blocked** at the APT layer on every run:

```
/etc/apt/preferences.d/99no-snap:
  Package: snapd
  Pin: release a=*
  Pin-Priority: -1
```

- Cannot be installed manually via apt
- Cannot be pulled in as a dependency
- Block survives reboots and apt upgrades
- If already installed: purged, all snap directories removed

---

## Connecting via VNC

- **Address:** `<pi-ip>:5901`
- **Default password:** `VanAwsome1` — **change immediately with `vncpasswd`**
- **Desktop:** XFCE4 (compositor disabled for VNC performance)
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)

### VNC Management Aliases

```bash
vnc-status     # sudo systemctl status vncserver@1
vnc-start      # start VNC server
vnc-stop       # stop VNC server
vnc-restart    # restart VNC server
vnc-log        # journalctl -u vncserver@1 -f
vnc-passwd     # vncpasswd
```

### Troubleshooting VNC

```bash
vnc-log                                        # check for errors
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1    # remove stale locks if needed
vnc-start                                      # restart
journalctl -u vncserver@1 --no-pager -n 50    # full boot-time log
```

Note: `ExecStartPre` in the systemd unit removes stale lock files automatically
on every start — manual cleanup should only be needed in unusual circumstances.

---

## The Login Banner

Every SSH session and every `clear` command shows the Van Auken Tech banner:
- Hostname rendered with `figlet -f small` (matches Van Auken Tech install script style)
- IP address, VNC address, CPU temperature, uptime
- Van Auken Tech credit footer

Banner script: `/usr/local/bin/kali-pi-banner` (executable, all users)
System ZSH: `/etc/zsh/zshrc` (fires for every interactive ZSH session)

---

## The ZSH Prompt

```
┌──(username㉿hostname)-[~/path]
└─$
```

- **Green brackets** = regular user
- **Blue/red brackets** = root  
- **Right prompt** shows exit code on failure and background job count
- `setopt PROMPT_SUBST` enables `${VIRTUAL_ENV:+...}` to expand at render time

---

## Security Tools Quick Reference

### Information Gathering
```bash
nmap-quick <ip>          # nmap -sV -sC
nmap-full  <ip>          # nmap -sV -sC -p- (all 65535 ports)
nmap-sweep <subnet>      # sudo nmap -sn (ping sweep)
nmap-vuln  <ip>          # nmap -sV --script vuln
```

### Web Application
```bash
nikto -h http://target
sqlmap -u "http://target/page?id=1"
sqlmap-full -u "http://target/page?id=1"   # batch, level 5, risk 3
gobuster dir -u http://target -w /usr/share/wordlists/dirb/common.txt
wpscan --url http://target
nuclei -u https://target                   # vulnerability templates
subfinder -d example.com                   # subdomain enumeration
```

### Exploitation
```bash
msf                     # sudo msfconsole
sudo msfdb init         # first-time database setup
searchsploit apache 2.4
searchsploit CVE-2021-44228
```

### Password Attacks
```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.1
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
hashcat -m 0 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
```

### Wordlists
```bash
wordlists              # ls -lh /usr/share/wordlists/
rockyou                # wc -l /usr/share/wordlists/rockyou.txt
                       # 14,344,392 passwords, 134MB
```

### System Info
```bash
piinfo                 # Pi model, IP, VNC, temp, RAM, disk
ports                  # ss -tuln (listening ports)
mem                    # free -h
disk                   # df -h
```

---

## Performance Tuning Details

### What Was Changed and Why

| Setting | Value | Why |
|---------|-------|-----|
| CPU governor | `performance` | Eliminates frequency-scaling latency that makes VNC sluggish |
| XFCE compositor | Disabled | Compositor renders over VNC network — biggest single perf win |
| Pulseaudio | Disabled | No audio on headless server — frees ~19MB RAM |
| `vm.swappiness` | 100 | Pi uses zram (compressed RAM swap) — aggressively swapping to zram is fast |
| `vm.vfs_cache_pressure` | 50 | Retains more inode/dentry cache — reduces SD card reads |
| `vm.dirty_ratio` | 5 | Flushes writes to SD sooner — reduces data loss window |
| TCP buffers | 16MB | Improves VNC frame throughput and security tool network performance |
| GPU memory | 16MB | Frees 60MB+ RAM for tools (default is 76MB on Pi 3) |
| CPU overclock | Model-specific | Increases compute performance within safe tested values |
| `vc4-kms-v3d` | Disabled | GPU driver not loaded for headless VNC — saves RAM |

### CPU Overclock Values

| Model | Default | After Setup | over_voltage |
|-------|---------|-------------|-------------|
| Pi 5 | 2400 MHz | 2800 MHz | 2 |
| Pi 4 | 1500 MHz | 1800 MHz | 2 |
| Pi 3B | 1200 MHz | 1350 MHz | 2 |
| Pi 3B+ | 1400 MHz | 1400 MHz | 0 (already max) |
| Pi Zero 2W | 1000 MHz | 1100 MHz | 2 |
| Pi Zero | — | No overclock | — |

---

## Maintenance

```bash
update                           # sudo apt update && apt upgrade -y
sudo msfupdate                   # Metasploit Framework
nuclei -update-templates         # nuclei vulnerability templates
sudo searchsploit -u             # Exploit Database
wpscan --update                  # wpscan vulnerability database
```

### Reboot Note
Kernel packages are held to prevent automatic mid-session reboots.
To update the kernel deliberately:
```bash
sudo apt-mark unhold linux-image* linux-headers*
sudo apt upgrade
sudo reboot
```

---

## Key File Locations

```
/usr/local/bin/kali-pi-banner       Dynamic login banner (all users)
/etc/zsh/zshrc                      System ZSH: banner on login + clear override
~/.zshrc                            Personal ZSH: prompt, aliases, tools
/root/.zshrc                        Root ZSH config
/etc/motd                           SSH login message
/etc/issue.net                      SSH pre-login banner

/usr/share/wordlists/rockyou.txt    Password wordlist (134MB)
/usr/share/exploitdb/               searchsploit database
/usr/share/metasploit-framework/    Metasploit installation
/opt/security-venv/                 Python security tools venv

/var/log/van-auken-pi-setup-*.log   Full installation log
/var/log/vncserver.log              VNC server log

/etc/apt/sources.list.d/kali.list   Kali kali-rolling repository
/etc/apt/preferences.d/kali-pin     Kali APT priority (100)
/etc/apt/preferences.d/99no-snap    snapd permanent block
/etc/apt/apt.conf.d/99no-autoreboot Auto-reboot prevention
/etc/sysctl.d/99-van-auken-pi.conf  Kernel performance tuning

/boot/firmware/config.txt           Boot config (Pi 4/5 on Bookworm+)
/boot/config.txt                    Boot config (Pi 3 and older)
```

---

*Thomas Van Auken — Van Auken Tech · v1.1.2 · 2026-03-29*
