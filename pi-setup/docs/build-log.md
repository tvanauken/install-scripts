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

---

## v1.0.0 — Initial Release (2026-03-27/28)

### Target
Raspberry Pi 3B · Raspbian GNU/Linux 13 (Trixie) · armhf

### Critical Engineering Lessons

#### 1. Auto-Reboot from apt-get upgrade
`apt-get upgrade` installed a pending kernel update. `unattended-upgrades` with `Automatic-Reboot: true` rebooted the Pi mid-script, wiping `/tmp`.

**Fix:** Stop `unattended-upgrades`, write `99no-autoreboot` apt config, hold kernel packages via `dpkg-query` + `apt-mark hold`.

#### 2. systemd-logind Kills Background Processes
`nohup` does not escape systemd's session cgroup. `KillUserProcesses=yes` kills all session processes on SSH disconnect.

**Fix:** Use `systemd-run --no-block` to place script in `/system.slice/` instead of SSH session scope.

#### 3. Go Compilation OOM
Compiling nuclei/subfinder on a Pi 3B (~970MB RAM) OOM-crashed and rebooted the system.

**Fix:** Never compile Go on-device. Download pre-built ARM binaries from GitHub Releases.

#### 4. SecLists Clone OOM
`git clone --depth 1` of SecLists (~1.4GB) also caused OOM.

**Fix:** Skip SecLists. rockyou.txt (134MB) is sufficient. Document SecLists as a manual external-storage install.

#### 5. kali-defaults Conflicts with raspberrypi-sys-mods
Both packages divert `/usr/lib/python3.x/EXTERNALLY-MANAGED` to different names, causing dpkg to fail.

**Fix:** `apt-mark hold kali-defaults` before any Kali package operations. Delete broken `.deb` from cache and run `apt --fix-broken install` after.

#### 6. PROMPT_SUBST Not Set
Kali prompt showed `${debian_chroot:+...}` literally — `PROMPT_SUBST` is not enabled by default on Raspbian.

**Fix:** `setopt PROMPT_SUBST` in `.zshrc` before `PROMPT=`.

#### 7. Tools in /usr/sbin Not in PATH
john, lynis, chkrootkit, etc. install to `/usr/sbin`. Non-root PATH may not include it.

**Fix:** Create `/usr/local/bin` symlinks for all `/usr/sbin` tools.

#### 8. VNC Service Failed on Boot
Systemd doesn't interpret shell redirections in `ExecStart`. Stale X lock files block restart.

**Fix:** Wrap ExecStart/ExecStop in `/bin/bash -c "..."`. Add `ExecStartPre` to remove stale locks. Add `Restart=on-failure`.

#### 9. $- Variable in SSH Heredoc
Nested SSH heredoc caused `$-` to expand to its runtime value instead of being written literally.

**Fix:** Write all config files locally and deploy via `scp`.

---

## v1.1.0 — Multi-Distro Support (2026-03-29)

### Changes

- **New `detect_os()` function:** Reads `/etc/os-release`, sets `OS_IS_KALI`, `OS_IS_UBUNTU`, `OS_IS_RASPBIAN`, `OS_IS_DEBIAN`. Checks `ID_LIKE` for derivatives.

- **New `prevent_snap()` function:** Writes `Pin-Priority: -1` for snapd permanently. Purges snapd if present. Critical on Ubuntu which ships snapd by default.

- **Ubuntu universe/multiverse:** Enabled before first `apt-get update`. Without this, hashcat, cewl, zsh-autosuggestions, tigervnc, and others are missing from Ubuntu's default repos.

- **Kali native path:** On native Kali, `setup_kali_repo()` skips GPG key and repo addition. Checks for existing msfconsole before attempting install.

- **Conditional kali-defaults hold:** `apt-mark hold kali-defaults` only on non-Kali systems.

- **Fixed all documentation:** Removed incorrect "NOT compatible with Ubuntu/Kali" claims from all docs.

---

## v1.1.1 — Internet Connectivity Fix (2026-03-29)

### Problem
First real-world test on `boron.mgmt.home.vanauken.tech` (Pi 5 · Ubuntu 24.04 · arm64) failed the internet check.

Single endpoint `https://deb.debian.org` failed when DNS was not yet initialised inside the systemd-run service scope. The Pi had internet (the script was just downloaded) but returned a false negative.

**Exact failure:** ✘ No internet connectivity — aborting

### Fix
Replaced single-endpoint check with multi-endpoint fallback loop:
```bash
for _ep in "https://github.com" "https://archive.ubuntu.com" "https://deb.debian.org" "http://1.1.1.1"; do
  curl -fsSL --max-time 5 "$_ep" > /dev/null 2>&1 && _net_ok=true && break
done
```
GitHub is tried first (most reliable). IP-based `1.1.1.1` is the final fallback (no DNS required).

### Also Fixed
- `pi-setup/README.md`: Added large `sudo bash <()` warning. First failure was user running `(curl ...)` alone without `sudo bash`.

---

## v1.1.2 — XFCE/VNC/Metasploit Install Fix (2026-03-29)

### Problem
On Ubuntu 24.04 arm64 (`boron`), XFCE4 and TigerVNC failed to install after the Kali repository section:

```
⚠ xfce4-goodies — not available
⚠ xfce4-terminal — not available
⚠ tigervnc-standalone-server — not available
⚠ tigervnc-common — not available
```

All packages ARE in the apt cache (`apt-cache show` confirmed). The real cause was a **broken dpkg state** discovered via `dpkg --audit`:

```
The following packages have been unpacked but not yet configured:
 wordlists   Contains the rockyou wordlist
```

**Root cause chain:**
1. Script installs `kali-linux-core` from kali-rolling repo
2. `kali-linux-core` depends on `wordlists`, which depends on `kali-defaults`
3. `kali-defaults` is held (`apt-mark hold kali-defaults`) to prevent the dpkg diversion conflict
4. `wordlists` package gets unpacked from the `.deb` file but cannot be configured because its dependency (`kali-defaults`) is held
5. dpkg is now in a **partially configured state**
6. All subsequent `apt-get install` calls fail because dpkg refuses to run with unconfigured packages
7. XFCE4, TigerVNC, and Metasploit all install at priority 500 from universe — but dpkg blocks them all

### Fix
Added three lines to `setup_kali_repo()` cleanup section:

```bash
# Previously:
rm -f /var/cache/apt/archives/kali-defaults*.deb 2>/dev/null || true
apt-get --fix-broken install -y >> "$LOGFILE" 2>&1 || true

# v1.1.2 fix:
rm -f /var/cache/apt/archives/kali-defaults*.deb 2>/dev/null || true
dpkg --remove --force-remove-reinstreq wordlists 2>/dev/null || true  # remove broken dpkg state
dpkg --configure -a 2>/dev/null || true                               # configure any unconfigured
apt-get --fix-broken install -y >> "$LOGFILE" 2>&1 || true
```

`dpkg --remove --force-remove-reinstreq wordlists` removes the package from dpkg's tracking while leaving the actual `rockyou.txt` file on disk. This clears the broken state and allows all subsequent apt operations to proceed normally.

### Verified On
- boron (Pi 5 · Ubuntu 24.04 · arm64) — XFCE and TigerVNC installed correctly after fix

---

## Documentation Update Policy

Per Van Auken Tech standards — **any change to a script requires immediate updates to ALL of:**

1. `<script-dir>/README.md`
2. `<script-dir>/docs/user-manual.md`
3. `<script-dir>/docs/build-log.md`
4. Root `README.md`
5. `docs/collection-overview.md`
6. `~/Documents/Markdown Documents/` (local session log)

---

*Thomas Van Auken — Van Auken Tech · Last updated: 2026-03-29*
