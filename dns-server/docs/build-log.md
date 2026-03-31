# Technitium DNS Server — Build Log

> Created by: Thomas Van Auken — Van Auken Tech
> Script version: 1.1.0
> Build date: 2026-03-31

---

## Summary

This document records every action taken to design, build, correct, and document `dns-server-install.sh` — the Technitium DNS Server post-install configuration script for the Van Auken Tech Install Scripts Collection.

---

## Phase 1 — Research

- Read `tvanauken/install-scripts` repository: `README.md`, `docs/collection-overview.md`, `cli-tools/cli-tools-install.sh` to establish exact Van Auken Tech visual and code standard.
- Confirmed community-scripts.org Technitium DNS installer URL and default LXC specs: Debian 13, 1 vCPU, 512 MB RAM, 2 GB disk, port 5380.
- Confirmed Technitium HTTP API endpoints for account creation, authentication, settings, zone creation, and RFC 2136 configuration.
- User clarified: script must be post-install configuration only — does NOT create the LXC.

**Decision:** Script connects to the Technitium API on an already-running LXC and configures it entirely via HTTP API calls. No SSH into the LXC required.

---

## Phase 2 — Initial Build (Incorrect — Discarded)

- First version incorrectly wrapped the community script one-liner, calling `bash -c "$(curl -fsSL ...)"` to create the LXC.
- Discarded in full after user correction.

---

## Phase 3 — Correct Build

**Script structure implemented:**

- `header_info()` — VANAUKEN TECH ASCII banner, host/date/log metadata
- `preflight()` — root check, auto-installs `curl` and `jq` via apt-get
- `collect_config()` — interactive prompts with clear explanation of fresh install vs already-configured scenarios
- `wait_for_service()` — polls `http://<IP>:5380/api/user/login` up to 30 times (2s intervals)
- `create_account()` — `POST /api/user/createAccount`; gracefully handles already-exists
- `get_token()` — `POST /api/user/login`; exits with clear error if authentication fails
- `configure_recursion()` — `POST /api/settings/set` with `recursion=AllowAll` and `forwarders=<value>`
- `create_zones()` — loops ALL_ZONES array, calls `POST /api/zones/create` for each
- `enable_rfc2136()` — loops ALL_ZONES array, calls `POST /api/zones/options/set` with `allowDynamicUpdates=true`
- `summary()` — completion block listing all configured values
- `main()` — orchestrates all functions in sequence

**Van Auken Tech standard compliance verified:**
- `#!/usr/bin/env bash` shebang
- `set -o pipefail`
- `trap cleanup EXIT`
- Root check
- Colour palette: `RD` `YW` `GN` `DGN` `BL` `CL` `BLD`
- Section dividers, status symbols, completion block, footer
- Attribution in footer and script header comment
- Timestamped log file at `/var/log/dns-server-config-<timestamp>.log`

---

## Phase 4 — Account Handling Clarification

**Issue:** Prompts were ambiguous — user did not know whether to enter new credentials (fresh install) or existing credentials (already used web UI wizard).

**Fix:** Added explicit explanation block in `collect_config()`:
- Green `[▸]` block explains fresh install scenario
- Yellow `[▸]` block explains already-configured scenario
- `create_account()` failure message changed from `msg_warn` to `msg_ok "Account already exists — logging in with provided credentials"`
- `get_token()` failure message explicitly tells user to check if they entered their existing web UI credentials

---

## Phase 5 — Documentation

- `dns-server/README.md` — updated with Step 1 (install LXC from community-scripts.org) / Step 2 (run this script) usage pattern
- `dns-server/docs/user-manual.md` — comprehensive guide covering all prompts, what each API call does, post-script record management, DHCP client setup, maintenance, and troubleshooting
- `dns-server/docs/build-log.md` — this document
- `docs/collection-overview.md` — table and quick reference updated to reflect post-install nature
- `README.md` (root) — script 5 entry updated with correct description and Step 1/Step 2 callout
- Local build log created at `~/Documents/Markdown Documents/dns-npm-postinstall-scripts-build-log.md`

---

## Commit History

| Commit SHA | Description |
|------------|-------------|
| `4808a57` | Initial (incorrect) LXC wrapper |
| `ce3ef80` | Rewritten as post-install config script |
| `30cf1fc` | Account prompt clarification |
| `98f29cd` | Collection docs corrected |

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
