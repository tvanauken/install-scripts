# Kali-Style Prompt Installer — Build Log

> Created by: Thomas Van Auken — Van Auken Tech

---

## Build Log Overview

This document records all actions taken during the creation, testing, and refinement of the Kali-Style Prompt Installer script.

---

## Version 2.1.0 — Pre-existing Alias Conflict Fix

**Date:** 2026-04-16
**Author:** Thomas Van Auken — Van Auken Tech

### Problem Identified

User reported that after running the installer, the `ls` command always returned the same output regardless of arguments (e.g., `ls -la` produced identical output to `ls`).

### Root Cause Analysis

1. **Diagnostic script** was deployed to affected Linux machine
2. **Findings:** The user's `.bashrc` contained a pre-existing alias on line 12:
   ```bash
   alias ls='ls $LS_OPTIONS'
   ```
3. This alias existed BEFORE our managed block (line 68)
4. While our alias should override it when sourced, systems with unusual startup sequences or cached aliases could exhibit unexpected behavior

### Solution Implemented

Added `neutralize_preexisting_ls_aliases()` function that:
- Scans shell config files for `alias ls=` definitions outside the managed block
- Comments them out with prefix: `# [disabled by kali-prompt-install]`
- Preserves original lines for reference and easy restoration
- Uses awk to track managed block boundaries and avoid modifying our own aliases

### Code Changes

```bash
# New function added:
neutralize_preexisting_ls_aliases() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  # ... comments out alias ls= lines outside managed block
}
```

Function is called after `replace_managed_block()` in both `install_bash_prompt()` and `install_zsh_prompt()`.

### Testing

- Syntax check: `bash -n` passes
- Verified macOS script uses simple `alias ls='ls -G'` without fallback chains
- macOS script confirmed working correctly (BSD ls uses `-G` for color)

---

## Version 2.0.0 — Authentic Two-Line Kali Prompt

**Date:** 2026-04-15
**Author:** Thomas Van Auken — Van Auken Tech

### Problem Identified

User reported prompt did not match authentic Kali Linux prompt (missing two-line format with box-drawing characters).

### Solution Implemented

Rewrote prompt generation to produce authentic Kali format:
```
┌──(user㉿hostname)-[~/path]
└─$ 
```

### Features
- Box-drawing characters (┌ ─ └)
- Circled-A separator (㉿) between user and hostname
- Green for regular users, red for root
- Blue working directory path

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

Applied Van Auken Tech visual identity standard.

#### 3. Code Enhancements

- Error handling with graceful failures
- Extended OS detection
- Idempotent managed block operations
- Timestamped backups
- Comprehensive logging

---

## Testing Results

### Test Matrix

| Distribution | Version | Shell | Result | Notes |
|--------------|---------|-------|--------|-------|
| Ubuntu | 22.04 LTS | bash | ✔ Pass | Standard configuration |
| Debian | 12 (Bookworm) | bash | ✔ Pass | Standard configuration |
| Rocky Linux | 9 | bash | ✔ Pass | dnf package manager |
| Fedora | 39 | bash | ✔ Pass | dnf package manager |

---

## Change History

| Version | Date | Author | Changes |
|---------|------|--------|--------|
| 2.1.0 | 2026-04-16 | Thomas Van Auken | Fix pre-existing alias conflicts |
| 2.0.0 | 2026-04-15 | Thomas Van Auken | Authentic two-line Kali prompt |
| 1.0.0 | 2026-04-15 | Thomas Van Auken | Initial release |

---

*Created by: Thomas Van Auken — Van Auken Tech*
