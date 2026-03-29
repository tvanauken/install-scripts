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

---

## v1.0.0 — Initial Release (2026-03-27 / 28)

### Target
Raspberry Pi 3B running Raspbian GNU/Linux 13 (Trixie) — armhf

### What Was Built
A single-script installer combining three separate sessions of work:
- **Session 1:** Kali Linux tools installation on `underworld.mgmt.home.vanauken.tech`
- **Session 2:** XFCE + TigerVNC remote desktop setup and boot-time service hardening
- **Session 3:** Full performance tuning (CPU governor, sysctl, boot config)

### Critical Engineering Lessons

#### 1. Auto-Reboot from apt-get upgrade
`apt-get upgrade` installed a pending kernel update. `unattended-upgrades` was configured with `Automatic-Reboot: true`. The Pi rebooted mid-script, wiping `/tmp` and killing the process.

**Fix:** Stop and disable `unattended-upgrades` at script start. Write `/etc/apt/apt.conf.d/99no-autoreboot`. Use `dpkg-query` to get actual package names, then `apt-mark hold` to hold kernel packages before any upgrade.

#### 2. systemd-logind Kills Background Processes
`nohup` does not escape systemd's session cgroup. `KillUserProcesses=yes` in `logind.conf` terminates all processes in the session's cgroup when SSH disconnects, regardless of nohup.

**Fix:** Use `systemd-run --no-block --unit=name` to place the script in `/system.slice/` instead of the SSH session scope. This makes it immune to SSH disconnect.

#### 3. Go Compilation OOM
Compiling nuclei, subfinder, etc. requires ~600MB+ RAM for the Go linker. The Pi 3B (970MB RAM) OOM-crashed and rebooted during compilation.

**Fix:** Never compile Go on-device. Download pre-built ARM binaries from GitHub Releases using the GitHub API. The script's `download_go_tool()` function handles this.

#### 4. SecLists Clone OOM
`git clone --depth 1` of SecLists (~1.4GB) also caused OOM on the Pi 3B.

**Fix:** Skip SecLists auto-installation. Document as a manual step requiring external storage. rockyou.txt (134MB) is sufficient for core use cases.

#### 5. kali-defaults Conflicts with raspberrypi-sys-mods
Both packages try to divert `/usr/lib/python3.x/EXTERNALLY-MANAGED` using different names (`.original` vs `.orig`), causing dpkg to fail at unpack.

**Fix:** `apt-mark hold kali-defaults` before any Kali package operations. After `kali-linux-core` install attempt, delete the broken `.deb` from cache and run `apt --fix-broken install`.

#### 6. PROMPT_SUBST Not Set
The Kali-style prompt showed `${debian_chroot:+($debian_chroot)──}` literally because `PROMPT_SUBST` is not enabled by default on Raspbian.

**Fix:** `setopt PROMPT_SUBST` in `.zshrc` before the `PROMPT=` definition.

#### 7. Tools in /usr/sbin Not in PATH
john, lynis, chkrootkit, netdiscover, arp-scan, hping3 install to `/usr/sbin` which may not be in PATH for non-root users.

**Fix:** Create `/usr/local/bin` symlinks for all tools found in `/usr/sbin`.

#### 8. VNC Service Failed on Boot
Two root causes:
1. Shell redirections (`> /dev/null`) in `ExecStart` are not interpreted by systemd — it passes them literally to the binary.
2. Stale X lock files (`/tmp/.X1-lock`) from crashed sessions block VNC restart.

**Fix:** Wrap all ExecStart/ExecStop in `/bin/bash -c "..."`. Add `ExecStartPre` to unconditionally remove stale lock files. Add `Restart=on-failure` with `RestartSec=10`.

#### 9. $- Variable in SSH Heredoc
Writing `/etc/zsh/zshrc` via a nested SSH heredoc caused `$-` to expand to `hBs` instead of the literal string `$-`.

**Fix:** Write all config files locally and deploy via `scp`. This avoids multi-level shell quoting entirely.

---

## v1.1.0 — Multi-Distro Support (2026-03-29)

### Problem
The v1.0.0 script had a hardcoded assumption that the OS was Raspbian. The header comment incorrectly stated "NOT compatible with Ubuntu, Kali Linux." This was wrong — all these OSes run on Pi hardware and use apt.

### Changes Made

#### New: `detect_os()` function (Section 2)
Added before `preflight()`. Sources `/etc/os-release` and sets boolean flags:
- `OS_IS_KALI` — native Kali Linux
- `OS_IS_UBUNTU` — Ubuntu (any flavour)
- `OS_IS_RASPBIAN` — Raspberry Pi OS
- `OS_IS_DEBIAN` — generic Debian

Also checks `ID_LIKE` for derivative distros.

#### New: `prevent_snap()` function (Section 4)
Added after preflight. Writes `/etc/apt/preferences.d/99no-snap` with `Pin-Priority: -1` (apt-layer permanent block). Purges snapd and all snap directories if already installed. Critical on Ubuntu which ships snapd by default.

#### Ubuntu: universe + multiverse (Section 6)
On Ubuntu, `add-apt-repository universe` and `add-apt-repository multiverse` are called before the first `apt-get update`. Without this, many security tools (hashcat, cewl, zsh-autosuggestions, etc.) are missing from Ubuntu's default repos.

#### Kali native path (Section 11)
On native Kali, `setup_kali_repo()` takes a completely different path:
- Skips GPG key download and repo addition (already kali-rolling)
- Checks if msfconsole already exists before attempting install
- Returns early with `return 0`

#### kali-defaults hold: conditional (Section 5)
`apt-mark hold kali-defaults` is now only applied on non-Kali systems. On native Kali, `kali-defaults` is a legitimate package and should not be held.

#### Header and documentation
Removed incorrect "NOT compatible with Ubuntu, Kali Linux" claims from:
- Script header comment
- `pi-setup/README.md`
- Root `README.md`
- `docs/collection-overview.md`

Added supported OS table to README with correct information.

---

## v1.1.1 — Internet Connectivity Fix (2026-03-29)

### Problem
First real-world test of v1.1.0 on `boron.mgmt.home.vanauken.tech` (Raspberry Pi 5, Ubuntu 24.04 arm64, fresh Pi Imager install) revealed an internet connectivity check failure.

**System:** Pi 5 Model B Rev 1.0 · Ubuntu 24.04.4 LTS · arm64 · 4GB RAM · 222GB free

The script was launched via `systemd-run` (to survive SSH session disconnect). The preflight internet check used a single endpoint:
```bash
curl -fsSL --max-time 8 https://deb.debian.org > /dev/null 2>&1
```
This failed inside the systemd transient service scope because DNS resolution for `deb.debian.org` was not yet fully initialised when the service started. The Pi clearly had internet (the script was just downloaded from GitHub), but the check returned false negative.

**Exact failure:**
```
✔ Architecture: arm64
✔ Package manager: apt
✔ Disk space: 222GB free
✘ No internet connectivity — aborting
```

### Fix
Replaced the single-endpoint check with a multi-endpoint fallback loop:

```bash
local _net_ok=false
for _ep in "https://github.com" "https://archive.ubuntu.com" "https://deb.debian.org" "http://1.1.1.1"; do
  curl -fsSL --max-time 5 "$_ep" > /dev/null 2>&1 && _net_ok=true && break
done
unset _ep
$_net_ok || { msg_error "No internet connectivity — aborting"; exit 1; }
```

GitHub is tried first (most reliable — the script was just downloaded from there). Any single successful response passes the check. This handles partial DNS initialisation and per-endpoint availability differences across networks.

### Also Fixed
- **README.md documentation:** Added prominent `sudo bash <()` warning explaining that running `(curl ...)` alone does not execute the script. This was the root cause of the user's first failure before the internet check issue was discovered.
- **Version bumped** to 1.1.1.

---

## Documentation Update Policy

Per Van Auken Tech standards: **any change to a script requires immediate updates to ALL of the following:**

1. `<script-dir>/README.md` — short overview, one-liner, requirements
2. `<script-dir>/docs/user-manual.md` — comprehensive user guide
3. `<script-dir>/docs/build-log.md` — add entry for the change
4. Root `README.md` — collection index entry
5. `docs/collection-overview.md` — scripts table and quick reference
6. `~/Documents/Markdown Documents/` — local session log

---

*Thomas Van Auken — Van Auken Tech*
*Last updated: 2026-03-29*
