# Van Auken Tech — Raspberry Pi Setup · Build Log

**Author:** Thomas Van Auken — Van Auken Tech
**Date:** 2026-03-27 through 2026-03-29
**Host:** underworld.mgmt.home.vanauken.tech
**Hardware:** Raspberry Pi 3B · Raspbian 13 (Trixie) · armhf · 970MB RAM

---

## Project Scope

This script consolidates work from three separate sessions:

1. **Session 1 (2026-03-27/28):** Kali Linux tools installation
2. **Session 2 (separate):** XFCE + TigerVNC remote desktop setup and boot-time service fix
3. **Session 3 (separate):** Performance tuning (CPU governor, sysctl, services, boot config)

---

## Critical Lessons Learned

### 1. Auto-Reboot from apt-get upgrade

**Problem:** `apt-get upgrade` installed a pending kernel update. The Pi had `unattended-upgrades` configured with `Automatic-Reboot: true`. The Pi rebooted mid-script (~1 minute after launch), wiping `/tmp` and killing the process.

**Solution (applied in script):**
- Stop and disable `unattended-upgrades` at script start
- Write `/etc/apt/apt.conf.d/99no-autoreboot` to disable auto-reboot
- Use `dpkg-query` to get actual package names then `apt-mark hold` to hold kernel packages
- Store all scripts in `/root/` not `/tmp/` (persistent)

### 2. systemd-logind Kills Background Processes

**Problem:** After reboot, script was re-launched with `nohup`. Despite nohup, the process was killed when the SSH session ended. Modern systemd places SSH session processes in a control group (cgroup). `KillUserProcesses=yes` in `logind.conf` terminates ALL processes in the cgroup when the session ends — regardless of nohup.

**Solution:** Used `systemd-run --no-block --unit=kali-setup` to launch as a transient systemd service, placing the process in `/system.slice/` instead of the SSH session scope.

### 3. Go Compilation OOM Kills Pi

**Problem:** Attempted `go install nuclei@latest` directly on the Pi. Compiling nuclei requires ~600MB+ RAM for the Go linker. With 970MB RAM + 969MB swap, the system OOM-killed the process and rebooted.

**Solution:** Never compile Go on the Pi. Use pre-built ARM binaries from GitHub Releases via the GitHub API:
```bash
curl -fsSL "https://api.github.com/repos/projectdiscovery/nuclei/releases/latest" \
  | grep "linux_arm.zip" | cut -d'"' -f4
```

### 4. SecLists Clone OOM

**Problem:** `git clone --depth 1 https://github.com/danielmiessler/SecLists` — even shallow, SecLists contains ~1.4GB of data. The clone operation exhausted RAM+swap and caused another reboot.

**Solution:** Skip SecLists auto-installation. Document it as a manual step requiring external storage. rockyou.txt (134MB) serves the core use case.

### 5. kali-defaults Conflicts with raspberrypi-sys-mods

**Problem:** Installing `kali-defaults` (pulled in by `wordlists` and `kali-linux-core`) caused dpkg to fail. Both `kali-defaults` and `raspberrypi-sys-mods` try to divert `/usr/lib/python3.x/EXTERNALLY-MANAGED` but to different names (`.original` vs `.orig`).

**Solution:**
- `apt-mark hold kali-defaults` at the very start of the script (before any Kali packages)
- After Kali section, `rm -f /var/cache/apt/archives/kali-defaults*.deb` then `apt --fix-broken install`

### 6. PROMPT_SUBST Not Set — Literal `${...}` in Prompt

**Problem:** The Kali-style prompt displayed `${debian_chroot:+($debian_chroot)──}` literally instead of evaluating it.

**Root cause:** `PROMPT_SUBST` is not enabled by default in zsh on Raspbian. This option is required for parameter expansion inside PROMPT.

**Solution:** `setopt PROMPT_SUBST` added to `.zshrc` before the PROMPT definition.

### 7. Tools in /usr/sbin Not in PATH

**Problem:** `john`, `lynis`, `chkrootkit`, `netdiscover`, `arp-scan`, `hping3` were installed but not found via `command -v` for non-root users because `/usr/sbin` is excluded from the default PATH in some contexts.

**Solution:** Create symlinks in `/usr/local/bin/` for all tools found in `/usr/sbin/`.

### 8. VNC Service Failed on Boot

**Problem:** `vncserver@1.service` worked when manually started but failed at boot. Two root causes:
1. Shell redirections (`> /dev/null 2>&1`) in `ExecStart` were not interpreted correctly by systemd
2. Stale X lock files from previous sessions (`/tmp/.X1-lock`) blocked restart

**Solution:**
- Wrap all VNC commands in `bash -c "..."` so shell features work correctly
- Add `ExecStartPre` to remove stale lock files
- Add `Restart=on-failure` with `RestartSec=10` for automatic recovery

### 9. $- Variable Expansion in SSH Heredoc

**Problem:** Writing `/etc/zsh/zshrc` via a nested SSH heredoc caused `$-` (current shell flags) to expand to its value (`hBs`) instead of being written literally.

**Solution:** Write the file locally and deploy via `scp`, avoiding the nested heredoc quoting issue entirely.

---

## Architecture Decision: Pre-Built Go Binaries

The script deliberately downloads pre-built ARM binaries for all Go tools rather than using `go install`. This decision was made after multiple OOM events on the Pi 3B.

Go compilation of large projects (nuclei, subfinder) requires:
- ~600MB RAM during linking
- 10-30 minutes of CPU time on a Pi
- Risk of OOM crash and system reboot

Pre-built binaries:
- Install in seconds
- Require zero additional RAM
- Are officially provided by each project for ARM

---

## Final State (underworld)

### Tools Installed
nmap, masscan, netdiscover, arp-scan, hping3, tcpdump, tshark, wireshark, mitmproxy, proxychains4, nikto, sqlmap, gobuster, dirb, wfuzz, ffuf, whatweb, sslscan, wpscan, hydra, medusa, john, hashcat, aircrack-ng, reaver, macchanger, binwalk, steghide, exiftool, msfconsole, msfvenom, searchsploit, nuclei, subfinder, httpx, theHarvester, recon-ng, rkhunter, chkrootkit, lynis

### Performance Improvements
- RAM freed (live): ~41MB (pulseaudio + disabled services)
- RAM freed (after reboot): +60MB (GPU memory reduction)
- CPU: governor set to `performance`
- CPU overclock: 1200MHz → 1350MHz (Pi 3B)

---

*Thomas Van Auken — Van Auken Tech*
*Document created: 2026-03-29*
