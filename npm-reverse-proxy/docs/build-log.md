# Nginx Proxy Manager — Build Log

> Created by: Thomas Van Auken — Van Auken Tech
> Script version: 1.1.0
> Build date: 2026-03-31

---

## Summary

This document records every action taken to design, build, correct, and document `npm-reverse-proxy-install.sh` — the Nginx Proxy Manager post-install configuration script for the Van Auken Tech Install Scripts Collection.

---

## Phase 1 — Research

- Read `tvanauken/install-scripts` repository to establish Van Auken Tech visual and code standard.
- Confirmed community-scripts.org NPM installer URL and default LXC specs: Debian 12, 2 vCPU, 2048 MB RAM, 8 GB disk, port 81, NPM v2.14.0.
- Confirmed NPM HTTP API endpoints: `POST /api/users` for account creation, `POST /api/tokens` for authentication, `POST /api/nginx/certificates` for cert import.
- Confirmed: NPM v2.x has no default credentials. First admin must be created either through web UI wizard or via `POST /api/users` API call (both work on fresh install).
- User clarified: script must be post-install configuration only — does NOT create the LXC.

**Decision:** Script connects to NPM API on an already-running LXC and configures it via HTTP API. No SSH into the LXC required.

---

## Phase 2 — Initial Build (Incorrect — Discarded)

- First version incorrectly wrapped the community script one-liner.
- Discarded in full after user correction.

---

## Phase 3 — Correct Build

**Script structure implemented:**

- `header_info()` — VANAUKEN TECH ASCII banner, host/date/log metadata
- `preflight()` — root check, auto-installs `curl` and `jq` via apt-get
- `collect_config()` — interactive prompts with clear explanation of fresh install vs already-configured scenarios; optional SSL cert file path collection with file existence validation
- `wait_for_service()` — polls `http://<IP>:81/api` up to 30 times (2s intervals)
- `create_admin()` — `POST /api/users`; gracefully handles already-exists by showing clear message
- `get_token()` — `POST /api/tokens`; exits with clear error if authentication fails, including guidance for existing-account scenario
- `import_cert()` — `POST /api/nginx/certificates` as multipart form; skipped entirely if no cert paths provided; reports cert ID on success
- `summary()` — completion block listing server URL, admin email, cert status, and next steps
- `main()` — orchestrates all functions in sequence

**Van Auken Tech standard compliance verified** — same as dns-server script.

---

## Phase 4 — Account Handling Clarification

**Issue:** NPM has a web UI setup wizard on first visit. Prompts were ambiguous about whether to enter new or existing credentials.

**Fix:** Added explicit explanation block in `collect_config()`:
- Green `[▸]` block for fresh install scenario
- Yellow `[▸]` block for already-configured scenario
- `create_admin()` error changed to `msg_ok "Account already exists — logging in with provided credentials"`
- `get_token()` failure includes explicit message about checking existing web UI credentials

---

## Phase 5 — Documentation

- `npm-reverse-proxy/README.md` — updated with Step 1 / Step 2 usage pattern
- `npm-reverse-proxy/docs/user-manual.md` — comprehensive guide covering all prompts, API calls explained, proxy host setup, SSL cert management, maintenance, troubleshooting
- `npm-reverse-proxy/docs/build-log.md` — this document
- `docs/collection-overview.md` — updated to reflect post-install nature
- `README.md` (root) — script 6 entry updated with correct description
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
