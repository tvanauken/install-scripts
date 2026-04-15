# Kali-Style Prompt Installer for macOS — Build Log

> Created by: Thomas Van Auken — Van Auken Tech

---

## Build Log Overview

This document records all actions taken during the creation, testing, and refinement of the Kali-Style Prompt Installer for macOS.

---

## Version 1.0.0 — Initial Release

**Date:** 2026-04-15
**Author:** Thomas Van Auken — Van Auken Tech

### Actions Performed

#### 1. Requirements Analysis

- Analyzed macOS-specific requirements vs Linux version
- Identified key differences:
  - zsh is default shell since macOS Catalina (10.15)
  - BSD ls uses `-G` flag instead of GNU `--color=auto`
  - No `/etc/os-release` - use `sw_vers` instead
  - User directories in `/Users` not `/home`
  - bash is version 3.2.x (BSD) unless Homebrew installed
  - Need to detect Intel vs Apple Silicon

#### 2. Version Requirements

- Set minimum macOS version to 12.7.6 (Monterey)
- Rationale: Ensures modern zsh, security updates, and consistent behavior
- Version comparison implemented without external dependencies

#### 3. Architecture Detection

- Implemented detection for:
  - `arm64` — Apple Silicon (M1, M2, M3, M4 chips)
  - `x86_64` — Intel processors
- Uses `uname -m` for reliable detection

#### 4. Branding Implementation

Applied Van Auken Tech visual identity:

| Element | Implementation |
|---------|---------------|
| Header | figlet "small" font — VANAUKEN TECH banner |
| Colour palette | `RD` `YW` `GN` `DGN` `BL` `CL` `BLD` variables |
| Section dividers | `── Section Name ──────────...` (cyan/bold) |
| Status symbols | ✔ green, ✘ red, ⚠ yellow, ◆ cyan |
| Summary block | `════════════...` style (cyan/bold) |
| Footer | `────────────...` with host + timestamp |
| Attribution | "Created by: Thomas Van Auken — Van Auken Tech" |

#### 5. macOS Adaptations

**Shell Configuration:**
- Primary: `.zshrc` (macOS default since Catalina)
- Secondary: `.bash_profile` (for bash compatibility)
- Optional: `.bashrc` (if exists)

**Color Configuration:**
```bash
# BSD ls color flag
alias ls='ls -G'

# Environment variables for color
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
```

**User Detection:**
- Uses `dscl . -read /Users/$USER UserShell` for shell detection
- Home directories at `/Users/$USERNAME`
- Handles sudo elevation correctly

#### 6. Bash 3.x Compatibility

- Avoided bash 4.x features (associative arrays, `local -a`)
- Used POSIX-compatible constructs where possible
- Version comparison works without `sort -V`

#### 7. Prompt Configuration

**Zsh Prompt:**
```zsh
if [[ $EUID -eq 0 ]]; then
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f# '
else
    PROMPT='%F{red}%n@%m%f:%F{blue}%~%f%# '
fi
```

**Bash Prompt:**
```bash
if [ "$(id -u)" -eq 0 ]; then
    PS1="${red}\u@\h${reset}:${blue}\w${reset}# "
else
    PS1="${red}\u@\h${reset}:${blue}\w${reset}\$ "
fi
```

#### 8. Documentation Created

| Document | Purpose |
|----------|--------|
| `README.md` | Quick overview and one-liner installation |
| `docs/user-manual.md` | Comprehensive macOS user guide |
| `docs/build-log.md` | This document — full action log |

---

## Testing Results

### Test Matrix

| macOS Version | Architecture | Shell | Result |
|---------------|--------------|-------|--------|
| 15.x (Sequoia) | Apple Silicon | zsh | ✔ Pass |
| 15.x (Sequoia) | Apple Silicon | bash | ✔ Pass |
| 14.x (Sonoma) | Intel | zsh | ✔ Pass |
| 13.x (Ventura) | Apple Silicon | zsh | ✔ Pass |
| 12.7.6 (Monterey) | Intel | zsh | ✔ Pass |

### Verification Checks

- [x] Script runs without errors on macOS
- [x] Version check correctly rejects older macOS
- [x] Architecture detection works for Intel and Apple Silicon
- [x] Prompt colors display correctly in Terminal.app
- [x] Prompt colors display correctly in iTerm2
- [x] BSD ls colors work with `-G` flag
- [x] Backup files created with timestamps
- [x] Idempotent re-runs work correctly
- [x] Both zsh and bash configurations installed

---

## Files in This Release

```
kali-prompt-macos/
├── kali-prompt-macos-install.sh    — Main installation script (v1.0.0)
├── README.md                       — Quick reference and one-liner
└── docs/
    ├── user-manual.md              — Comprehensive macOS user guide
    └── build-log.md                — This document
```

---

## Differences from Linux Version

| Aspect | Linux | macOS |
|--------|-------|-------|
| OS Detection | `/etc/os-release` | `sw_vers` |
| Default Shell | bash (varies) | zsh |
| ls Color Flag | `--color=auto` | `-G` |
| Color Variables | N/A | `CLICOLOR`, `LSCOLORS` |
| Home Directory | `/home/$USER` | `/Users/$USER` |
| User Shell Query | `getent passwd` | `dscl` |
| Package Manager | apt/dnf/yum | N/A (Homebrew optional) |
| Architecture | x86_64, arm64 | x86_64, arm64 |
| Primary Config | `.bashrc` | `.zshrc` |
| Secondary Config | `.zshrc` | `.bash_profile` |

---

## Change History

| Version | Date | Author | Changes |
|---------|------|--------|--------|
| 1.0.0 | 2026-04-15 | Thomas Van Auken | Initial macOS release |

---

*Created by: Thomas Van Auken — Van Auken Tech*
