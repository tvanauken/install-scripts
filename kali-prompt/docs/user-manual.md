# Kali-Style Prompt Installer — User Manual

> Created by: Thomas Van Auken — Van Auken Tech

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [How It Works](#how-it-works)
5. [Configuration Details](#configuration-details)
6. [Customization](#customization)
7. [Troubleshooting](#troubleshooting)
8. [Uninstallation](#uninstallation)
9. [Technical Reference](#technical-reference)

---

## Overview

The **Kali-Style Prompt Installer** transforms your standard Linux command prompt into the iconic Kali Linux prompt style — featuring a bold red username and hostname followed by a blue working directory path.

This script is designed for enterprise reliability:
- **Multi-distribution support:** Ubuntu, Debian, RHEL, Rocky, Fedora, and derivatives
- **Multi-shell support:** Automatically configures both bash and zsh
- **Safe operation:** Creates timestamped backups before any file modification
- **Idempotent:** Can be run multiple times safely; updates existing configuration
- **Logging:** Complete operation log for audit and troubleshooting

---

## Requirements

### Supported Operating Systems

| Distribution | Versions | Package Manager |
|--------------|----------|----------------|
| Ubuntu | 18.04+ | apt |
| Debian | 10+ | apt |
| Raspberry Pi OS | All | apt |
| Linux Mint | 19+ | apt |
| Pop!_OS | 20.04+ | apt |
| RHEL | 7+ | dnf/yum |
| Rocky Linux | 8+ | dnf |
| AlmaLinux | 8+ | dnf |
| CentOS | 7+ | dnf/yum |
| Fedora | 32+ | dnf |

### System Requirements

- **Shell:** bash 4.0+ or zsh 5.0+
- **Commands:** bash, grep, awk, sed, id, cp, tee
- **Permissions:** User-level (root not required unless installing for another user)
- **Network:** Internet access for curl-based installation

---

## Installation

### Standard Installation

Run the installer directly from GitHub:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

### Installation for a Specific User (as root)

If you're logged in as root but want to configure the prompt for another user:

```bash
sudo -u USERNAME bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh)
```

### Manual Download and Run

```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt/kali-prompt-install.sh -o kali-prompt-install.sh
chmod +x kali-prompt-install.sh
./kali-prompt-install.sh
```

### Activating the New Prompt

After installation, activate the prompt immediately:

```bash
exec bash -l
```

Or for zsh users:

```bash
exec zsh -l
```

Alternatively, simply open a new terminal session.

---

## How It Works

### Detection Phase

1. **User Detection:** Identifies the real user (handles `sudo` elevation correctly)
2. **Home Directory:** Locates the user's home directory via `getent` or fallback logic
3. **OS Detection:** Reads `/etc/os-release` to identify distribution and package manager
4. **Shell Detection:** Reads the user's login shell from `/etc/passwd`

### Installation Phase

1. **Package Installation:** Installs zsh if the user's shell is zsh but zsh isn't present
2. **Bash Configuration:** Adds managed configuration block to `~/.bashrc`
3. **Zsh Configuration:** Adds managed configuration block to `~/.zshrc` (if applicable)
4. **Profile Loader:** Ensures `~/.profile` sources the appropriate shell config

### Verification Phase

1. **Config Check:** Verifies managed blocks are present in all configured files
2. **Auto-Repair:** Attempts repair if verification fails
3. **Final Validation:** Confirms successful installation

---

## Configuration Details

### Files Modified

| File | Purpose |
|------|--------|
| `~/.bashrc` | Bash prompt configuration and aliases |
| `~/.zshrc` | Zsh prompt configuration and aliases (if applicable) |
| `~/.profile` | Shell config loader for login shells |

### Backup Strategy

Before modifying any file, the script creates a timestamped backup:

```
~/.bashrc.bak.20260415-143022
~/.zshrc.bak.20260415-143022
~/.profile.bak.20260415-143022
```

### Managed Block Format

All configurations are wrapped in managed block markers:

```bash
# >>> kali-prompt-install >>>
# ... configuration ...
# <<< kali-prompt-install <<<
```

This allows the script to:
- Identify existing configurations
- Update configurations without duplicating
- Remove configurations cleanly during uninstallation

---

## Customization

### Changing Prompt Colors

Edit `~/.bashrc` and modify the color codes within the managed block:

```bash
# Color codes reference:
# \033[1;31m = Bold Red
# \033[1;32m = Bold Green
# \033[1;33m = Bold Yellow
# \033[1;34m = Bold Blue
# \033[1;35m = Bold Magenta
# \033[1;36m = Bold Cyan
# \033[0m    = Reset
```

### Adding Custom Aliases

Add additional aliases within the managed block or below it in your shell config:

```bash
# Custom aliases
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt update && sudo apt upgrade -y'
```

---

## Troubleshooting

### Prompt Not Changing

**Symptom:** Prompt remains unchanged after installation.

**Solutions:**
1. Start a new shell: `exec bash -l` or `exec zsh -l`
2. Source the config directly: `source ~/.bashrc`
3. Check if the managed block exists: `grep -A5 'kali-prompt-install' ~/.bashrc`

### Permission Denied Errors

**Symptom:** Script fails with permission errors.

**Solutions:**
1. Ensure you own your home directory files
2. Check file permissions: `ls -la ~/.bashrc`
3. If installing for another user, use: `sudo -u USERNAME ./kali-prompt-install.sh`

### Colors Not Displaying

**Symptom:** Prompt shows escape codes instead of colors.

**Solutions:**
1. Verify terminal supports colors: `echo $TERM` (should show xterm-256color or similar)
2. Check for `color_prompt` setting in original `.bashrc`
3. Try a different terminal emulator

### Log File Location

All operations are logged to:

```
/var/tmp/kali-prompt-install/kali-prompt-install-YYYYMMDD-HHMMSS.log
```

If `/var/tmp` is not writable, logs are written to:

```
/tmp/kali-prompt-install-YYYYMMDD-HHMMSS.log
```

---

## Uninstallation

To remove the Kali-style prompt:

### Manual Removal

1. Edit `~/.bashrc` and remove the block between:
   ```
   # >>> kali-prompt-install >>>
   ...
   # <<< kali-prompt-install <<<
   ```

2. Edit `~/.zshrc` (if applicable) and remove the same block.

3. Edit `~/.profile` and remove the block between:
   ```
   # >>> kali-prompt-loader >>>
   ...
   # <<< kali-prompt-loader <<<
   ```

4. Start a new shell session.

### Restore from Backup

If you want to restore original configurations:

```bash
cp ~/.bashrc.bak.YYYYMMDD-HHMMSS ~/.bashrc
cp ~/.zshrc.bak.YYYYMMDD-HHMMSS ~/.zshrc
cp ~/.profile.bak.YYYYMMDD-HHMMSS ~/.profile
exec bash -l
```

---

## Technical Reference

### Script Behavior

| Feature | Behavior |
|---------|----------|
| Error Handling | `set -o pipefail` — graceful per-step failures |
| Idempotency | Re-running updates existing config, doesn't duplicate |
| Backup | Timestamped backups before any modification |
| Logging | Full operation log with timestamps |
| Exit Codes | 0 = success, non-zero = failure with error message |

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|--------|
| `LOG_DIR` | Override log directory | `/var/tmp/kali-prompt-install` |
| `SUDO_USER` | Used to detect real user when run via sudo | (system-provided) |

### Prompt Variables Set

**Bash:**
- `PS1` — Primary prompt string
- `color_prompt` — Color capability flag

**Zsh:**
- `PROMPT` — Primary prompt string

### Aliases Configured

| Alias | Command |
|-------|--------|
| `ls` | `ls --color=auto` (with fallbacks) |
| `ll` | `ls -alF --color=auto` |
| `la` | `ls -A --color=auto` |
| `l` | `ls -CF --color=auto` |
| `grep` | `grep --color=auto` |
| `egrep` | `egrep --color=auto` |
| `fgrep` | `fgrep --color=auto` |

---

*Created by: Thomas Van Auken — Van Auken Tech*
