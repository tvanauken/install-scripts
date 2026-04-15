# Kali-Style Prompt Installer — Build Log

> Created by: Thomas Van Auken — Van Auken Tech

---

## Build Log Overview

This document records all actions taken during the creation, testing, and refinement of the Kali-Style Prompt Installer script.

---

## Version 1.0.0 — Initial Release

**Date:** 2026-04-15
**Author:** Thomas Van Auken — Van Auken Tech

### Actions Performed

#### 1. Script Analysis and Design

- Reviewed original `bootstrap-kali-prompt.sh` script
- Identified core functionality: Kali-style prompt installation for bash/zsh
- Mapped target distributions: Ubuntu, Debian, RHEL, Rocky, Fedora, and derivatives
- Documented requirement for multi-distro, multi-shell support

#### 2. Branding Implementation

Applied Van Auken Tech visual identity standard:

| Element | Implementation |
|---------|---------------|
| Header | figlet "small" font — VANAUKEN TECH banner |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` variables |
| Section dividers | `── Section Name ──────────...` (cyan/bold) |
| Status: in-progress | `◆  message...` (cyan) |
| Status: success | `✔  message` (green) |
| Status: warning | `⚠  message` (yellow) |
| Status: error | `✘  message` (red) |
| Summary block | `════════════...` style (cyan/bold) |
| Footer | `────────────...` with host + timestamp (dark green) |
| Attribution | "Created by: Thomas Van Auken — Van Auken Tech" |

#### 3. Code Enhancements

**Error Handling:**
- Changed from `set -Eeuo pipefail` to `set -o pipefail` for compatibility
- Added cleanup trap for terminal cursor reset
- Implemented graceful per-step failure handling

**OS Detection:**
- Extended distribution detection beyond original 4 distros
- Added support for derivatives (Mint, Pop!_OS, Zorin, Elementary, etc.)
- Added Oracle Linux, AlmaLinux, CentOS support
- Implemented `ID_LIKE` fallback for unrecognized distributions

**Shell Detection:**
- Improved shell detection via `getent passwd`
- Added fallback for systems without getent
- Default to bash configuration when shell is unsupported

**File Operations:**
- Implemented idempotent managed block replacement
- Added timestamped backups before any file modification
- Ensured proper file ownership after modifications
- Added directory creation for missing paths

**Logging:**
- Implemented comprehensive logging to `/var/tmp/kali-prompt-install/`
- Added fallback to `/tmp/` if `/var/tmp/` is not writable
- Log file includes all operations with timestamps

#### 4. Prompt Configuration

**Bash Prompt:**
```bash
# Root: red user@host, blue path, # symbol
\[\033[1;31m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]#

# User: red user@host, blue path, $ symbol
\[\033[1;31m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]$
```

**Zsh Prompt:**
```zsh
# Root: red user@host, blue path, # symbol
%F{red}%n@%m%f:%F{blue}%~%f#

# User: red user@host, blue path, $ symbol
%F{red}%n@%m%f:%F{blue}%~%f$
```

**Aliases Added:**
- `ls`, `ll`, `la`, `l` — with color auto-detection and macOS fallbacks
- `grep`, `egrep`, `fgrep` — with color output

#### 5. Verification System

- Implemented post-install verification checks
- Added auto-repair capability for failed verifications
- Final validation ensures installation success before completion

#### 6. Documentation Created

| Document | Purpose |
|----------|--------|
| `README.md` | Quick overview and one-liner installation |
| `docs/user-manual.md` | Comprehensive user guide |
| `docs/build-log.md` | This document — full action log |

---

## Testing Results

### Test Matrix

| Distribution | Version | Shell | Result | Notes |
|--------------|---------|-------|--------|-------|
| Ubuntu | 22.04 LTS | bash | ✔ Pass | Standard configuration |
| Ubuntu | 22.04 LTS | zsh | ✔ Pass | Zsh auto-installed |
| Debian | 12 (Bookworm) | bash | ✔ Pass | Standard configuration |
| Debian | 12 (Bookworm) | zsh | ✔ Pass | Zsh pre-installed |
| Rocky Linux | 9 | bash | ✔ Pass | dnf package manager |
| Fedora | 39 | bash | ✔ Pass | dnf package manager |
| RHEL | 8 | bash | ✔ Pass | yum package manager |
| Raspberry Pi OS | Bookworm | bash | ✔ Pass | ARM64 architecture |

### Verification Checks

- [x] Script runs without errors on all target distributions
- [x] Prompt colors display correctly in xterm, gnome-terminal, konsole
- [x] Root vs user prompt symbol (# vs $) works correctly
- [x] Aliases function correctly
- [x] Backup files created with correct timestamps
- [x] Log files written to correct location
- [x] Idempotent re-runs work correctly
- [x] Managed block detection and replacement works
- [x] User ownership preserved on modified files

---

## Files in This Release

```
kali-prompt/
├── kali-prompt-install.sh    — Main installation script (v1.0.0)
├── README.md                 — Quick reference and one-liner
└── docs/
    ├── user-manual.md        — Comprehensive user guide
    └── build-log.md          — This document
```

---

## Change History

| Version | Date | Author | Changes |
|---------|------|--------|--------|
| 1.0.0 | 2026-04-15 | Thomas Van Auken | Initial release |

---

*Created by: Thomas Van Auken — Van Auken Tech*
