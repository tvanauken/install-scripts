# Van Auken Tech — Raspberry Pi Setup · User Manual
**Script:** `pi-setup.sh` · **Version:** 1.1.1
**Author:** Thomas Van Auken — Van Auken Tech
**Updated:** 2026-03-29

---

## Supported Hardware & Operating Systems

This script runs on **Raspberry Pi hardware only** (armhf or arm64 ARM architecture).
The architecture check is the definitive gate — if the hardware is a Pi, the OS is the choice.

| OS | Versions | Arch |
|---|---|---|
| **Raspberry Pi OS** (Raspbian) | Bookworm 12, Trixie 13 | armhf · arm64 |
| **Ubuntu Desktop** | 22.04 LTS, 24.04 LTS | arm64 |
| **Ubuntu Server** | 22.04 LTS, 24.04 LTS | arm64 |
| **Kali Linux ARM Desktop** | Rolling | arm64 |
| **Debian ARM** | Bookworm, Trixie | armhf · arm64 |

❌ NOT compatible with: x86/x86_64, Proxmox VE, non-apt distros
Package manager: **apt only** — snapd is blocked and purged.

---

## Running the Script

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pi-setup/pi-setup.sh)
```

### ⚠ The command has three parts — all are required

| Part | Why |
|------|-----|
| `sudo` | Script must run as root — exits immediately without it |
| `bash <(` | Tells bash to download and execute the script via process substitution |
| `curl -s URL` | Downloads the script from GitHub |

**Wrong:**
```bash
curl -s https://...          # downloads only, does not run
(curl -s https://...)        # subshell — does nothing useful
bash https://...             # bash cannot take a URL directly
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
| 2 | **OS Detection** — auto-identifies distro, sets flags for Kali/Ubuntu/Raspbian/Debian |
| 3 | **Preflight** — root check, ARM arch gate, apt check, disk/internet, resolves calling user |
| 4 | **Snap Prevention** — pins snapd at APT priority -1 (permanent block), purges if present |
| 5 | **Reboot Prevention** — holds kernel packages, disables unattended-upgrades auto-reboot |
| 6 | **System Update** — `apt update/upgrade`; enables Ubuntu universe+multiverse if needed |
| 7 | **Security Tools** — 40+ tools installed from distro repos with graceful per-package failure |
| 8 | **Python Tools** — isolated venv at `/opt/security-venv`: impacket, scapy, theHarvester, etc. |
| 9 | **Ruby Tools** — wpscan installed via `gem install --no-document` |
| 10 | **Go Binaries** — pre-built ARM binaries: nuclei, subfinder, httpx, naabu, feroxbuster |
| 11 | **Kali Repository** — kali-rolling at priority 100 + Metasploit (skipped on native Kali) |
| 12 | **Wordlists** — rockyou.txt (134MB, 14.3M passwords); SecLists documented as manual |
| 13 | **XFCE + TigerVNC** — headless XFCE4, VNC port 5901, systemd service, auto-recovery |
| 14 | **Performance Tuning** — CPU governor, sysctl, disabled services, boot config, overclock |
| 15 | **ZSH Shell** — Kali prompt, Van Auken Tech login banner, aliases, plugins, MOTD |
| 16 | **Verification** — checks all tools, VNC service state, snapd block |

---

## OS-Specific Behaviour

### Raspberry Pi OS (Raspbian)
- All tools available directly in repos
- kali-defaults held to prevent dpkg diversion conflict with raspberrypi-sys-mods
- Boot config at `/boot/config.txt` or `/boot/firmware/config.txt`

### Ubuntu Desktop / Server
- `universe` and `multiverse` repositories enabled automatically before any install
- snapd purged and blocked at the APT layer (Ubuntu ships snapd by default)
- Boot config at `/boot/firmware/config.txt`

### Kali Linux ARM Desktop
- kali-rolling repository already configured — GPG key and repo addition are skipped
- kali-defaults hold not applied (no conflict on native Kali)
- Metasploit checked for existing install before attempting reinstall

### Debian ARM
- Treated same as Raspbian for repo and conflict handling

---

## Snap Prevention (All Distros)

Snapd is **permanently blocked** at the APT layer:

```
/etc/apt/preferences.d/99no-snap:
  Package: snapd
  Pin: release a=*
  Pin-Priority: -1
```

This means:
- snapd cannot be installed manually via apt
- snapd cannot be pulled in as a dependency
- The block survives reboots and apt upgrades
- If snapd was already installed it is purged and all snap directories removed

---

## Connecting via VNC

- **Address:** `<pi-ip>:5901`
- **Default password:** `VanAwsome1` — change immediately with `vncpasswd`
- **Desktop:** XFCE4 (compositor disabled for performance)
- **Resolution:** 1920×1080 (auto-reduced to 1280×720 on <768MB RAM)

### VNC Management Aliases

```bash
vnc-status     # systemctl status vncserver@1
vnc-start      # start VNC server
vnc-stop       # stop VNC server
vnc-restart    # restart VNC server
vnc-log        # journalctl -u vncserver@1 -f
vnc-passwd     # change VNC password
```

### Troubleshooting VNC

**Service fails to start:**
```bash
vnc-log                         # check for errors
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1   # remove stale locks
vnc-start
```
Note: `ExecStartPre` in the systemd unit removes stale locks automatically on every start.

**Cannot connect:**
```bash
vnc-status                      # is service running?
sudo ufw allow 5901/tcp         # open firewall if needed
```

---

## The Login Banner

Every new SSH session and every `clear` command shows the Van Auken Tech banner:
- Hostname rendered in `figlet -f small` ASCII art
- IP, VNC address, CPU temperature, uptime
- Van Auken Tech credit footer

The banner script is at `/usr/local/bin/kali-pi-banner` and generates the hostname dynamically, so it works correctly on any Pi regardless of hostname.

---

## The ZSH Prompt

```
┌──(username㉿hostname)-[~/path]
└─$
```

- **Green brackets** = regular user
- **Blue/red brackets** = root
- **Right prompt** shows exit code on failure and background job count
- `setopt PROMPT_SUBST` enables `${VIRTUAL_ENV:+...}` to expand at render time (required for correct prompt)

---

## Security Tools Quick Reference

```bash
nmap-quick <ip>          # nmap -sV -sC
nmap-full  <ip>          # nmap -sV -sC -p- (all 65535 ports)
nmap-sweep <subnet>      # ping sweep
nmap-vuln  <ip>          # vulnerability scripts
msf                      # sudo msfconsole
sudo msfdb init          # first-time Metasploit DB setup
searchsploit apache 2.4  # search exploit database
sqlmap-full -u <url>     # sqlmap --batch --level=5 --risk=3
wpscan --url <url>       # WordPress scanner
nuclei -u <url>          # vulnerability templates scan
subfinder -d <domain>    # subdomain enumeration
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://<ip>
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
wordlists                # list /usr/share/wordlists/
rockyou                  # count rockyou.txt passwords
piinfo                   # system overview
```

---

## Performance Tuning Details

### Live (immediate, no reboot needed)
- **CPU governor → `performance`**: eliminates frequency-scaling latency that makes VNC sluggish
- **XFCE compositor disabled**: biggest single VNC improvement — compositor renders over the network
- **Pulseaudio disabled**: ~19MB RAM freed (no audio on headless server)
- **sysctl tuning**: zram-optimised swap, reduced SD card writes, TCP throughput for VNC

### After Reboot
- **GPU memory 16MB**: frees 60MB+ RAM for tools and desktop (default is 76MB on Pi 3)
- **CPU overclock**: model-specific safe values applied automatically
- **Unused hardware disabled**: camera, display auto-detect, audio, splash screen, vc4-kms-v3d

### Overclock Values by Model

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
update                           # sudo apt update && sudo apt upgrade -y
sudo msfupdate                   # Metasploit
nuclei -update-templates         # nuclei scan templates
sudo searchsploit -u             # exploit database
wpscan --update                  # wpscan vulnerability database
```

### After Reboot (required once after install)
```bash
sudo reboot
# Then connect VNC client to <ip>:5901
vncpasswd                        # CHANGE THE DEFAULT PASSWORD
sudo msfdb init                  # Metasploit database setup
```

---

## Key File Locations

```
/usr/local/bin/kali-pi-banner    Dynamic login banner
/etc/zsh/zshrc                   System ZSH (banner + clear override, all users)
~/.zshrc                         Personal ZSH (prompt, aliases, tools)
/etc/motd                        SSH login message
/etc/issue.net                   SSH pre-login banner
/usr/share/wordlists/rockyou.txt Password wordlist (134MB)
/usr/share/exploitdb/            searchsploit database
/usr/share/metasploit-framework/ Metasploit installation
/opt/security-venv/              Python security tools venv
/var/log/van-auken-pi-setup-*.log  Full installation log
/var/log/vncserver.log           VNC server log
/etc/sysctl.d/99-van-auken-pi.conf  Kernel tuning parameters
/etc/apt/sources.list.d/kali.list   Kali repository
/etc/apt/preferences.d/kali-pin     Kali APT priority (100)
/etc/apt/preferences.d/99no-snap    snapd permanent block
/etc/apt/apt.conf.d/99no-autoreboot Auto-reboot prevention
```

---

*Thomas Van Auken — Van Auken Tech*
