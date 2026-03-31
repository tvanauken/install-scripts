# Technitium DNS Server Installer — Build Log

> Created by: Thomas Van Auken — Van Auken Tech  
> Script version: 1.0.0  
> Build date: 2026-03-31

---

## Summary

This document records every action taken to design, build, test, and document the `dns-server-install.sh` script for the Van Auken Tech Install Scripts Collection.

---

## Phase 1 — Research and Requirements

**Actions:**

- Reviewed the Van Auken Tech install-scripts repository structure, existing scripts (`cli-tools-install.sh`, `drive_init.sh`, `generate_drive_inventory.sh`, `pi-setup.sh`), and the collection-overview standard.
- Studied the visual standard: figlet-style ASCII banner, colour palette (`RD`, `YW`, `GN`, `DGN`, `BL`, `CL`, `BLD`), section dividers, status symbols, summary block, and footer.
- Researched the Proxmox VE Community Scripts project (community-scripts.org) to identify the official Technitium DNS one-liner.
- Confirmed the Technitium DNS community script URL: `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/technitiumdns.sh`
- Confirmed default LXC specifications: Debian 13, 1 vCPU, 512 MB RAM, 2 GB storage, web UI port 5380.
- Reviewed Technitium DNS documentation for post-install configuration reference.

**Decisions made:**

- Script is a Van Auken Tech branded wrapper around the community script — it does not replicate the community script logic.
- The wrapper adds: preflight checks, LXC spec preview, community script invocation, post-install guidance, and completion summary.
- Script must be run from the Proxmox VE shell (not inside an LXC).
- Preflight checks must validate: root access AND pveversion (confirms PVE host, not just any Linux box).

---

## Phase 2 — Script Development

**Actions:**

- Created `/dns-server/dns-server-install.sh` following the Van Auken Tech standard exactly:
  - Shebang: `#!/usr/bin/env bash`
  - Header comment block with author, version, date, repo, and source URL
  - Colour palette variables matching the collection standard
  - `LOGFILE` written to `/var/log/dns-server-install-<timestamp>.log`
  - `cleanup()` trap on EXIT resetting terminal cursor and reporting abnormal exits
  - Helper functions: `msg_info`, `msg_ok`, `msg_error`, `msg_warn`, `section`
  - `header_info()` — ASCII banner + host/date/log metadata
  - `preflight()` — root check, PVE host check, internet check, curl availability check
  - `show_specs()` — displays default LXC specs before community script launches
  - `run_installer()` — invokes the community script via `bash -c "$(curl -fsSL ...)"` and checks exit code
  - `post_install_notes()` — six actionable first-run steps with cyan [▸] indicators
  - `summary()` — `════` completion block matching collection standard, with footer crediting Van Auken Tech
  - `main()` — orchestrates all functions in sequence

- Verified script is syntactically valid bash.
- Confirmed `set -o pipefail` is not used at the top level to prevent community script interaction issues; error handling is done at function level.

---

## Phase 3 — Documentation

**Actions:**

- Created `dns-server/README.md` — short overview matching the collection standard:
  - Credit line, version, test environment
  - Overview paragraph explaining Technitium DNS
  - One-liner run command
  - Numbered what-it-does list
  - Default LXC specifications table
  - Post-install first steps
  - Footer credit

- Created `dns-server/docs/user-manual.md` — comprehensive user manual covering:
  - 14-section table of contents
  - Architecture diagram (ASCII)
  - DNS query flow explanation
  - Prerequisites table
  - Step-by-step installer walkthrough (7 steps)
  - Initial web UI configuration
  - Recursive resolution setup with forwarder options
  - Authoritative zone creation and record management
  - Split-horizon DNS explanation and configuration
  - RFC 2136 dynamic DNS update setup
  - Blocklists and filtering
  - DNS over HTTPS and TLS
  - Pointing DHCP clients to Technitium (UniFi and generic)
  - Maintenance: updates, backups, log locations
  - Troubleshooting: DNS resolution, web UI, zone issues, recursion failures

- Created `dns-server/docs/build-log.md` (this document).

- Updated `docs/collection-overview.md` — added script 5 to the scripts table and quick reference section.

- Updated root `README.md` — added script 5 entry with overview and one-liner.

---

## Phase 4 — Repository Integration

**Actions:**

- All files pushed to `tvanauken/install-scripts` main branch in a single commit.
- Commit message follows Van Auken Tech convention with Co-Authored-By attribution.

---

## File Manifest

| File | Purpose |
|------|---------|
| `dns-server/dns-server-install.sh` | Main installer script |
| `dns-server/README.md` | Short overview |
| `dns-server/docs/user-manual.md` | Comprehensive user guide |
| `dns-server/docs/build-log.md` | This build log |
| `docs/collection-overview.md` | Updated — script 5 added |
| `README.md` | Updated — script 5 added |

---

*Created by: Thomas Van Auken — Van Auken Tech*  
*Repository: https://github.com/tvanauken/install-scripts*
