# Van Auken Tech — Raspberry Pi Setup · User Manual

**Script:** `pi-setup.sh`
**Author:** Thomas Van Auken — Van Auken Tech
**Version:** 1.0 · March 2026

---

## Overview

This manual covers the complete environment installed by `pi-setup.sh` on a Raspberry Pi running Raspbian. The script configures three major components:

1. **Kali Linux Security Tools** — 40+ penetration testing tools
2. **XFCE Remote Desktop** — TigerVNC-based remote desktop on port 5901
3. **Performance Tuning** — CPU, RAM, kernel, and boot optimisations

---

## Connecting to the Pi

### SSH
```bash
ssh tvanauken@<pi-ip-address>
```

### VNC (Remote Desktop)
Connect any VNC client to `<pi-ip>:5901`
- Default password: `VanAwsome1` — **change with `vncpasswd`**
- Resolution: 1920×1080 (auto-reduced to 1280×720 on low-RAM devices)
- Desktop: XFCE4

Recommended VNC clients:
- macOS: [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/)
- Windows: RealVNC Viewer or TigerVNC Viewer
- Linux: `vncviewer <ip>:5901`

---

## Managing the VNC Service

The VNC service is a systemd unit (`vncserver@1.service`) that starts automatically on boot.

```bash
vnc-status     # Show service status
vnc-start      # Start VNC
vnc-stop       # Stop VNC
vnc-restart    # Restart VNC
vnc-log        # Follow live log (Ctrl+C to exit)
vnc-passwd     # Change VNC password

# Full systemd commands
sudo systemctl status vncserver@1
journalctl -u vncserver@1 -f
```

### Troubleshooting VNC

**Cannot connect:**
```bash
vnc-status         # Check if service is running
vnc-log            # Check for errors
vnc-restart        # Restart and try again
```

**Stale lock files (service fails to start):**
```bash
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
vnc-start
```
Note: The systemd service cleans these automatically via `ExecStartPre`.

---

## The Shell Environment

### Login Banner
Every new SSH session or shell start shows the Van Auken Tech banner:
- Hostname in figlet ASCII art
- Host, IP, VNC address, CPU temperature, uptime
- Van Auken Tech credit footer

The banner also appears after every `clear` command.

### ZSH Prompt
```
┌──(tvanauken㉿hostname)-[~/path]
└─$
```
- Green brackets = regular user
- Blue/red brackets = root
- Right side shows exit code and background jobs

### Key Aliases

| Alias | Action |
|-------|--------|
| `piinfo` | Show Pi model, IP, temperature, RAM, disk, VNC |
| `vnc-status` | VNC service status |
| `vnc-restart` | Restart VNC |
| `vnc-log` | Follow VNC log |
| `mem` | Show RAM usage |
| `disk` | Show disk usage |
| `ports` | Show listening ports |
| `myip` | Show public IP |
| `update` | apt update + upgrade |

---

## Security Tools Reference

### Information Gathering
```bash
nmap-quick <ip>          # nmap -sV -sC
nmap-full <ip>           # Full port scan
nmap-sweep <subnet>      # Ping sweep
nmap-vuln <ip>           # Vulnerability scripts
sudo netdiscover -r 192.168.1.0/24
sudo arp-scan 192.168.1.0/24
```

### Web Application
```bash
nikto -h http://target.com
sqlmap -u "http://target.com/page?id=1"
sqlmap-full -u "http://target.com/page?id=1"
gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt
wfuzz -w /usr/share/wordlists/dirb/common.txt http://target.com/FUZZ
wpscan --url http://target.com
```

### Password Attacks
```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.1
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
hashcat -m 0 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
```

### Exploitation
```bash
msf                      # Launch Metasploit (alias)
sudo msfdb init          # First-time DB setup
searchsploit apache 2.4
```

### OSINT
```bash
theHarvester -d example.com -b all
recon-ng
nuclei -u https://target.com
subfinder -d example.com
```

### Forensics
```bash
binwalk firmware.bin
exiftool image.jpg
steghide extract -sf image.jpg
```

### Wordlists
```bash
wordlists                # List /usr/share/wordlists/
rockyou                  # Count rockyou.txt lines
ls /usr/share/wordlists/rockyou.txt  # 134MB, 14.3M passwords
```

---

## Performance Tuning Details

### What Was Tuned

**CPU Governor (`performance`)**
Prevents the Pi from downclocking between requests. Critical for VNC responsiveness — with the default `ondemand` governor, the CPU takes time to ramp up frequency, causing noticeable lag when moving windows or typing.

**XFCE Compositor (disabled)**
The XFCE window compositor (xfwm4) adds GPU-rendered shadows, transparency, and animations. Over VNC, this renders remotely and creates massive overhead. Disabling it is the single biggest VNC performance improvement.

**sysctl Tuning**
- `vm.swappiness=100` — Raspbian uses zram (compressed RAM-based swap). Swapping to zram is fast; aggressively using it keeps real RAM free for tools.
- `vm.vfs_cache_pressure=50` — Keeps more filesystem metadata in RAM, reducing SD card read latency.
- `vm.dirty_ratio=5` — Flushes writes to the SD card sooner, reducing data loss risk from unexpected power loss.
- TCP buffers — Improves throughput for VNC and network security tools.

**Disabled Services**
Services disabled to free RAM and reduce background CPU usage:
- `bluetooth` — not used on headless server
- `avahi-daemon` — mDNS discovery not needed
- `colord` — colour management not needed headless
- `ModemManager` — no cellular modem
- `pulseaudio` — no audio on headless server (~19MB freed)

**Boot Config (`/boot/config.txt` or `/boot/firmware/config.txt`)**
- `gpu_mem=16` — Reduces GPU reserved memory to minimum for headless operation
- CPU overclock — Model-specific safe values applied automatically
- `vc4-kms-v3d` overlay disabled — GPU driver not loaded (saves RAM)
- `camera_auto_detect=0`, `display_auto_detect=0`, `dtparam=audio=off` — Unused hardware disabled

### Checking Performance
```bash
piinfo              # System overview including CPU temp
watch -n1 vcgencmd measure_temp   # Live CPU temperature
watch -n1 free -h                 # Live RAM usage
cpu_freq=$(vcgencmd measure_clock arm | cut -d= -f2); echo "$((cpu_freq/1000000)) MHz"  # Current CPU freq
```

---

## Maintenance

```bash
update                           # System packages
sudo msfupdate                   # Metasploit
nuclei -update-templates         # nuclei templates
sudo searchsploit -u             # Exploit database
wpscan --update                  # wpscan database
```

---

## Key File Locations

```
/usr/local/bin/kali-pi-banner     Login banner script
/etc/zsh/zshrc                    System ZSH (banner + clear override)
~/.zshrc                          Personal ZSH config
/usr/share/wordlists/rockyou.txt  Password wordlist
/usr/share/exploitdb/             searchsploit database
/usr/share/metasploit-framework/  Metasploit installation
/opt/security-venv/               Python security tools venv
/var/log/van-auken-pi-setup-*.log Setup log
/var/log/vncserver.log            VNC server log
/etc/sysctl.d/99-van-auken-pi.conf  Kernel tuning parameters
/etc/apt/sources.list.d/kali.list Kali repository
/etc/apt/preferences.d/kali-pin  Kali APT priority
```

---

*Thomas Van Auken — Van Auken Tech*
*underworld.mgmt.home.vanauken.tech*
