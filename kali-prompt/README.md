# Van Auken Tech — Kali-Style Prompt Installer

> Created by: Thomas Van Auken — Van Auken Tech

**Directory:** [`kali-prompt/`](./)
**Script:** [`kali-prompt-install.sh`](kali-prompt-install.sh)

Installs a **Kali Linux-style command prompt** on any supported Linux distribution. Auto-detects user shell (bash/zsh) and configures the classic red username/hostname with blue working directory prompt.

---

## Supported Distributions

| Family | Distributions |
|--------|---------------|
| Debian | Ubuntu, Debian, Raspberry Pi OS, Linux Mint, Pop!_OS, Elementary OS, Zorin OS, Kali Linux |
| RHEL | RHEL, Rocky Linux, AlmaLinux, CentOS, Oracle Linux, Fedora |

---

## One-Liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

Or with `sudo` if installing for a non-root user while running as root:

```bash
sudo -u USERNAME bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

---

## What It Does

1. **Detects** target user and home directory (handles `sudo` correctly)
2. **Identifies** the operating system and package manager
3. **Detects** the user's login shell (bash or zsh)
4. **Installs** zsh package if needed and user's shell is zsh
5. **Configures** `.bashrc` with Kali-style prompt
6. **Configures** `.zshrc` if user's shell is zsh
7. **Updates** `.profile` with shell config loader
8. **Verifies** all configurations are in place
9. **Creates** backups of all modified files

---

## Prompt Style

**Root user:**
```
root@hostname:/path/to/dir#
```

**Regular user:**
```
username@hostname:/path/to/dir$
```

Colours:
- **Username@Hostname:** Bold Red
- **Working Directory:** Bold Blue
- **Prompt Symbol:** Default (# for root, $ for user)

---

## Documentation

- [User Manual](docs/user-manual.md) — Comprehensive usage guide
- [Build Log](docs/build-log.md) — Development and testing history

---

*Van Auken Tech · Thomas Van Auken*
