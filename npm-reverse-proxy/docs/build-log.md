# Nginx Proxy Manager Installer — Build Log

> Created by: Thomas Van Auken — Van Auken Tech  
> Script version: 1.0.0  
> Build date: 2026-03-31

---

## Summary

This document records every action taken to design, build, test, and document the `npm-reverse-proxy-install.sh` script for the Van Auken Tech Install Scripts Collection.

---

## Phase 1 — Research and Requirements

**Actions:**

- Reviewed the Van Auken Tech install-scripts repository structure, existing scripts, and the collection-overview standard.
- Studied the visual standard: ASCII banner, colour palette, section dividers, status symbols, summary block, and footer.
- Researched the Proxmox VE Community Scripts project (community-scripts.org) to identify the official Nginx Proxy Manager one-liner.
- Confirmed the NPM community script URL: `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/nginxproxymanager.sh`
- Confirmed default LXC specifications: Debian 12 (Bookworm), 2 vCPU, 2048 MB RAM, 8 GB storage, web UI port 81.
- Reviewed community script source code to understand what the installer does (OpenResty build from source, Node.js 22, Yarn, NPM backend and frontend build).
- Confirmed current NPM version: v2.14.0 (March 2026).
- Reviewed NPM documentation for post-install configuration reference.
- Confirmed that GoDaddy does not have a well-supported certbot DNS plugin — manual acme.sh approach is the recommended wildcard cert method for GoDaddy-managed domains.

**Decisions made:**

- Script is a Van Auken Tech branded wrapper around the community script.
- The wrapper adds: preflight checks, LXC spec preview, community script invocation, post-install guidance (including certbot plugin note), and completion summary.
- Script must be run from the Proxmox VE shell.
- Post-install notes specifically call out the `/app/scripts/install-certbot-plugins` option and the manual wildcard cert process.

---

## Phase 2 — Script Development

**Actions:**

- Created `npm-reverse-proxy/npm-reverse-proxy-install.sh` following the Van Auken Tech standard:
  - Shebang: `#!/usr/bin/env bash`
  - Header comment block with author, version, date, repo, and source URL
  - Colour palette variables matching the collection standard
  - `LOGFILE` written to `/var/log/npm-reverse-proxy-install-<timestamp>.log`
  - `cleanup()` trap on EXIT resetting terminal cursor and reporting abnormal exits
  - Helper functions: `msg_info`, `msg_ok`, `msg_error`, `msg_warn`, `section`
  - `header_info()` — ASCII banner + host/date/log metadata
  - `preflight()` — root check, PVE host check, internet check, curl availability check
  - `show_specs()` — displays default LXC specs (Debian 12, 2 vCPU, 2048 MB, 8 GB, port 81) before community script launches
  - `run_installer()` — invokes the community script via `bash -c "$(curl -fsSL ...)"`, captures exit code
  - `post_install_notes()` — five actionable first-run steps + certbot plugin note, with cyan [▸] indicators
  - `summary()` — `════` completion block matching collection standard, with Van Auken Tech footer
  - `main()` — orchestrates all functions in sequence

- Verified script is syntactically valid bash.

---

## Phase 3 — Documentation

**Actions:**

- Created `npm-reverse-proxy/README.md` — short overview matching the collection standard:
  - Credit line, version, test environment
  - Overview paragraph explaining NPM and OpenResty
  - One-liner run command
  - Numbered what-it-does list
  - Default LXC specifications table
  - Post-install first steps
  - Footer credit

- Created `npm-reverse-proxy/docs/user-manual.md` — comprehensive user manual covering:
  - 13-section table of contents
  - Architecture diagram (ASCII) with request flow explanation
  - Prerequisites table
  - Step-by-step installer walkthrough (7 steps)
  - Initial web UI setup and account creation wizard
  - Adding Proxy Hosts with all options documented
  - SSL certificate management (Let's Encrypt, auto-renewal, custom upload)
  - Wildcard certificates via manual acme.sh process
  - Access Lists (IP-based and Basic Auth)
  - Streams (TCP/UDP proxying)
  - Certbot DNS plugin installation inside the LXC
  - Maintenance: updates, backups, log locations, service status
  - Troubleshooting: web UI, HTTPS, certificates, 502 errors, service startup

- Created `npm-reverse-proxy/docs/build-log.md` (this document).

- Updated `docs/collection-overview.md` — added script 6 to the scripts table and quick reference section.

- Updated root `README.md` — added script 6 entry with overview and one-liner.

---

## Phase 4 — Repository Integration

**Actions:**

- All files pushed to `tvanauken/install-scripts` main branch in a single commit alongside the dns-server files.
- Commit message follows Van Auken Tech convention with Co-Authored-By attribution.

---

## File Manifest

| File | Purpose |
|------|---------|
| `npm-reverse-proxy/npm-reverse-proxy-install.sh` | Main installer script |
| `npm-reverse-proxy/README.md` | Short overview |
| `npm-reverse-proxy/docs/user-manual.md` | Comprehensive user guide |
| `npm-reverse-proxy/docs/build-log.md` | This build log |
| `docs/collection-overview.md` | Updated — script 6 added |
| `README.md` | Updated — script 6 added |

---

*Created by: Thomas Van Auken — Van Auken Tech*  
*Repository: https://github.com/tvanauken/install-scripts*
