# Van Auken Tech — Kali-Style Prompt Installer for macOS

> Created by: Thomas Van Auken — Van Auken Tech

**Directory:** [`kali-prompt-macos/`](./)
**Script:** [`kali-prompt-macos-install.sh`](kali-prompt-macos-install.sh)

Installs a **Kali Linux-style command prompt** on macOS 12.7.6 (Monterey) or later. Supports both **Intel** and **Apple Silicon** Macs. Auto-detects user shell (zsh/bash) and configures the classic red username/hostname with blue working directory prompt.

---

## System Requirements

| Requirement | Details |
|-------------|--------|
| macOS Version | 12.7.6 (Monterey) or later |
| Architecture | Intel (x86_64) or Apple Silicon (arm64) |
| Shell | zsh (default) or bash |
| Permissions | User-level (no sudo required) |

---

## One-Liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

Or using zsh (macOS default):

```zsh
zsh <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

---

## What It Does

1. **Verifies** macOS version (12.7.6 minimum) and architecture
2. **Detects** target user and home directory
3. **Identifies** the user's login shell (zsh or bash)
4. **Configures** `.zshrc` with Kali-style prompt (primary on macOS)
5. **Configures** `.bash_profile` for bash compatibility
6. **Verifies** all configurations are in place
7. **Creates** backups of all modified files

---

## Prompt Style

**Regular user:**
```
username@hostname:/path/to/dir%
```

**Root user:**
```
root@hostname:/path/to/dir#
```

Colours:
- **Username@Hostname:** Bold Red
- **Working Directory:** Bold Blue
- **Prompt Symbol:** Default (# for root, % for zsh user, $ for bash user)

---

## macOS-Specific Features

- Uses BSD `ls -G` for colored directory listings (not GNU `--color=auto`)
- Sets `CLICOLOR=1` and `LSCOLORS` environment variables
- Configures both `.zshrc` and `.bash_profile` for shell flexibility
- Detects Apple Silicon vs Intel architecture
- Validates macOS version before installation

---

## Documentation

- [User Manual](docs/user-manual.md) — Comprehensive usage guide
- [Build Log](docs/build-log.md) — Development and testing history

---

*Van Auken Tech · Thomas Van Auken*
