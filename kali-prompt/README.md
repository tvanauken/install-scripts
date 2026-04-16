# Van Auken Tech — Kali-Style Prompt Installer

> Created by: Thomas Van Auken — Van Auken Tech

**Directory:** [`kali-prompt/`](./)
**Script:** [`kali-prompt-install.sh`](kali-prompt-install.sh)
**Version:** 2.1.0

Installs the authentic **Kali Linux two-line prompt** on any supported Linux distribution. Auto-detects user shell (bash/zsh) and configures accordingly.

---

## Prompt Style

```
┌──(user㉿hostname)-[~/path]
└─$ 
```

- **Green** prompt for regular users
- **Red** prompt for root
- **Blue** working directory path

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

After installation, activate immediately:

```bash
exec bash -l
```

---

## What It Does

1. **Detects** target user and home directory (handles `sudo` correctly)
2. **Identifies** the operating system and package manager
3. **Detects** the user's login shell (bash or zsh)
4. **Configures** `.bashrc` with authentic Kali two-line prompt
5. **Configures** `.zshrc` if user's shell is zsh
6. **Neutralizes** any pre-existing `alias ls=` definitions that could conflict
7. **Creates** timestamped backups of all modified files
8. **Verifies** all configurations are in place

---

## Documentation

- [User Manual](docs/user-manual.md) — Comprehensive usage guide
- [Build Log](docs/build-log.md) — Development and testing history

---

*Van Auken Tech · Thomas Van Auken*
