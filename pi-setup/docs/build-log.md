# Van Auken Tech — Raspberry Pi Setup · Build Log

**Author:** Thomas Van Auken — Van Auken Tech
**Repository:** https://github.com/tvanauken/install-scripts

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 1.0.0 | 2026-03-27 | Initial release — Raspberry Pi OS (Raspbian) only |
| 1.1.0 | 2026-03-29 | Multi-distro support, OS detection, snap prevention |
| 1.1.1 | 2026-03-29 | Fix: internet connectivity check (multi-endpoint fallback) |
| 1.1.2 | 2026-03-29 | Fix: wordlists dpkg broken state blocks XFCE/VNC install |
| 1.1.3 | 2026-03-29 | Fix: VNC service runs as root (eliminates log permission class) |

---

## v1.0.0 — Initial Release (2026-03-27/28)

### Engineering Lessons

**Auto-reboot from apt-get upgrade:** `unattended-upgrades` with `Automatic-Reboot: true` rebooted mid-script. Fix: stop service, write `99no-autoreboot` config, hold kernel packages via `dpkg-query`.

**systemd-logind kills background processes:** `nohup` does not escape the session cgroup. Fix: `systemd-run --no-block` places script in `/system.slice/`.

**Go compilation OOM:** Large Go projects require ~600MB+ RAM for linker. Fix: pre-built ARM binaries from GitHub Releases only.

**SecLists clone OOM:** 1.4GB git clone exhausts Pi RAM+swap. Fix: skip, document as manual external-storage install.

**kali-defaults conflicts with raspberrypi-sys-mods:** Both divert `/usr/lib/python3.x/EXTERNALLY-MANAGED` to different names. Fix: `apt-mark hold kali-defaults` before any Kali package operations.

**PROMPT_SUBST not set:** Kali prompt shows `${...}` literally on Raspbian. Fix: `setopt PROMPT_SUBST` in `.zshrc`.

**Tools in /usr/sbin not in PATH:** john, lynis, etc. Fix: `/usr/local/bin` symlinks.

**VNC service failed on boot:** systemd doesn't interpret shell redirections in ExecStart. Stale lock files block restart. Fix: wrap in `bash -c`, `ExecStartPre` removes locks, `Restart=on-failure`.

---

## v1.1.0 — Multi-Distro Support (2026-03-29)

- **`detect_os()`**: sources `/etc/os-release`, sets `OS_IS_KALI`, `OS_IS_UBUNTU`, `OS_IS_RASPBIAN`, `OS_IS_DEBIAN`
- **`prevent_snap()`**: `Pin-Priority: -1` permanently blocks snapd at APT layer; purges if present
- **Ubuntu universe/multiverse**: enabled before first `apt-get update`
- **Kali native path**: `setup_kali_repo()` skips GPG/repo if already Kali
- **kali-defaults hold**: conditional — only on non-Kali
- **All docs corrected**: removed false "NOT compatible with Ubuntu/Kali" claims

---

## v1.1.1 — Internet Connectivity Fix (2026-03-29)

**Test:** boron (Pi 5 · Ubuntu 24.04 · arm64 · fresh Pi Imager install)

**Failure 1 — user error:** User ran `(curl -s URL)` instead of `sudo bash <(curl -s URL)`. Fix: large warning block added to README.

**Failure 2 — DNS not initialised in systemd-run scope:** Single endpoint `deb.debian.org` failed. Fix: multi-endpoint fallback `github.com → archive.ubuntu.com → deb.debian.org → 1.1.1.1`.

---

## v1.1.2 — dpkg Broken State Fix (2026-03-29)

**Problem:** XFCE4 and TigerVNC silently skipped on Ubuntu 24.04. All packages existed in apt cache.

**Root cause:** `kali-linux-core` → `wordlists` → `kali-defaults` (held). `wordlists` gets unpacked but not configured. Broken dpkg state blocks ALL subsequent apt operations.

**Fix:** After kali-linux-core attempt:
```bash
rm -f /var/cache/apt/archives/kali-defaults*.deb
dpkg --remove --force-remove-reinstreq wordlists   # rockyou.txt preserved on disk
dpkg --configure -a
apt-get --fix-broken install -y
```

---

## v1.1.3 — VNC Runs as Root (2026-03-29)

**Problem:** After v1.1.2, VNC service was enabled but connection was refused. Journal showed:
```
/bin/bash: line 1: /var/log/vncserver.log: Permission denied
```

**Root cause:** The systemd service ran as `tvanauken` (non-root), but `/var/log/vncserver.log` was owned by root. The service user could not open the log file for writing, causing ExecStart to fail with exit code 1.

**Architectural decision:** Changed VNC service to run as **root**.

This is the correct design for a dedicated security workstation:
- All security tools (nmap raw sockets, msfconsole, airmon-ng, etc.) require root anyway
- No permission issues with log files, system directories, or privileged network operations
- VNC config stored in `/root/.vnc/` — no ambiguity about which user's home directory
- The Pi is a single-purpose security tool — running the desktop as root is appropriate

**Changes in v1.1.3:**
- `vncserver@.service`: `User=root`, `Group=root`, `WorkingDirectory=/root`
- VNC passwd and xstartup created in `/root/.vnc/` (not `${ACTUAL_HOME}/.vnc/`)
- Service now started immediately during install (`systemctl start`) — VNC is usable without reboot
- Verification now checks `is-active` (not just `is-enabled`)
- Summary shows "Connect via VNC NOW" (no reboot needed for VNC)

### Verified on boron
- Pi 5 Model B Rev 1.0 · Ubuntu 24.04.4 LTS · arm64
- VNC active and listening on port 5901 ✅
- XFCE4 desktop session as root ✅

---

## Documentation Update Policy

Any change to a script requires immediate updates to ALL of:
1. `<script-dir>/README.md`
2. `<script-dir>/docs/user-manual.md`
3. `<script-dir>/docs/build-log.md`
4. Root `README.md`
5. `docs/collection-overview.md`
6. `~/Documents/Markdown Documents/` (local session log)

---

*Thomas Van Auken — Van Auken Tech · Last updated: 2026-03-29*
