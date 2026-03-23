# CLI Tools Installer — Build Log
### Van Auken Tech · Thomas Van Auken
**Date:** 2026-03-22 (updated 2026-03-23)
**Host:** atlas.mgmt.home.vanauken.tech
**PVE Version:** 9.1.6 (Debian Trixie)
**Script:** `cli-tools-install.sh`
**GitHub:** https://github.com/tvanauken/install-scripts/tree/main/cli-tools

---

## Overview

This document is the action log for the creation, testing, and deployment of the CLI Tools Installer script on `atlas.mgmt.home.vanauken.tech`.

---

## Actions Taken

### 1. Requirements Gathered
- User provided a list of 37 CLI tools to install (from cliapps.rtf, later pasted directly)
- User confirmed `wget` (originally listed as `wet`)
- User requested X11 dependencies included
- User specified no `--no-install-recommends` flag
- User requested Proxmox Community Scripts visual style

### 2. Script Created
- Reviewed Proxmox VE Community Scripts style at community-scripts.org
- Installed `figlet` on atlas to generate compact ASCII art header
- Generated `VANAUKEN TECH` header using figlet "small" font (64 chars wide — fits standard terminals)
- Wrote complete 317-line bash script with:
  - Unified colour palette (RD/YW/GN/DGN/BL/CL/BLD)
  - msg_info / msg_ok / msg_warn / msg_error / section() helper functions
  - cleanup trap on EXIT
  - Preflight (root check, internet check)
  - Repository configuration (contrib/non-free/non-free-firmware)
  - Per-package install loop with `[▸] Installing... ✔ OK` live output
  - Post-install: bat symlink, qemu-guest-agent enable, sensors-detect, updatedb
  - Per-package verification (command -v + dpkg -s)
  - Colour summary block

### 3. Initial Test Run
- Script deployed to `/root/cli-tools-install.sh` on atlas
- `bash -n` syntax check: ✔ Pass
- Full run executed: **44/45 packages installed**
- One failure: `ntopng` — ntop.org repo does not publish Debian Trixie packages
- Root cause: PVE 9.x is based on Debian 13 (Trixie), not Bookworm; ntop repo has no Trixie release

### 4. ntop Removed
- User confirmed: scratch ntop entirely
- ntopng repo removed from the server: `rm /etc/apt/sources.list.d/ntop-stable.list`
- Script updated to remove ntopng install and ntopng repository setup

### 5. Header Fix
- Original block Unicode (██) header was cutting off the "N" in VANAUKEN on some terminals
- Unicode block chars are double-width in terminals; total display width exceeded 80 columns
- Fix: replaced with figlet "small" ASCII-only font output (64 chars wide)
- User confirmed: keep the block letter style, just make it smaller
- figlet installed on atlas; `figlet -f small "VANAUKEN TECH"` output hardcoded into script

### 6. iperf Added (2026-03-23)
- User requested `iperf` be added to the script
- `iperf3` (current v3) and `iperf` (legacy v2) added to Networking section
- Added to verification list
- Both packages installed successfully on atlas
- GitHub repo updated, documentation updated

### 7. Final Verification
- **44/44 packages installed, 34/34 verified, 0 failures**
- Script copied to `/root/Downloads/cli-tools-install.sh`
- Script pushed to `tvanauken/install-scripts` → `cli-tools/`

---

## Deployment Results

| Metric | Value |
|--------|-------|
| Packages attempted | 46 |
| Packages installed | 46 |
| Packages failed | 0 |
| Packages verified | 36 |
| Verification failures | 0 |
| Install log | `/var/log/cli-tools-install-*.log` |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-22 | Initial creation — 44 packages, Proxmox community script style |
| 2026-03-22 | ntop removed — repo does not support Debian Trixie |
| 2026-03-22 | Header resized to figlet small font — fits 80-column terminals |
| 2026-03-23 | iperf3 and iperf added — 46 packages total |

---

## Notes

- `bat` binary on Debian is installed as `batcat` — script auto-creates `/usr/local/bin/bat` symlink
- `zfs-utils-linux` (display name) maps to Debian package `zfsutils-linux`
- `virt-filesystems` is provided by `libguestfs-tools`
- `netstat` is provided by `net-tools` (already in list)
- `iperf3` is the current maintained version; `iperf` (v2) included for compatibility with older test setups

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
