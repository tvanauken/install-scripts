# Kali-Style Prompt Installer for macOS — User Manual

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

The **Kali-Style Prompt Installer for macOS** transforms your standard macOS Terminal prompt into the iconic Kali Linux prompt style — featuring a bold red username and hostname followed by a blue working directory path.

This script is specifically designed for macOS:
- **Version Support:** macOS 12.7.6 (Monterey) and later
- **Architecture Support:** Both Intel (x86_64) and Apple Silicon (arm64)
- **Shell Support:** zsh (macOS default since Catalina) and bash
- **Safe Operation:** Creates timestamped backups before any modifications
- **Idempotent:** Can be run multiple times safely

---

## Requirements

### Supported macOS Versions

| Version | Name | Status |
|---------|------|--------|
| 12.7.6+ | Monterey | ✅ Supported |
| 13.x | Ventura | ✅ Supported |
| 14.x | Sonoma | ✅ Supported |
| 15.x | Sequoia | ✅ Supported |

### Supported Architectures

| Architecture | Processor | Status |
|--------------|-----------|--------|
| arm64 | Apple Silicon (M1, M2, M3, M4) | ✅ Supported |
| x86_64 | Intel | ✅ Supported |

### System Requirements

- **Shell:** zsh 5.8+ (default) or bash 3.2+
- **Permissions:** User-level (sudo not required for normal use)
- **Network:** Internet access for curl-based installation
- **Terminal:** Terminal.app, iTerm2, or any compatible terminal

---

## Installation

### Standard Installation (Recommended)

Run the installer directly from GitHub using bash:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

Or using zsh (macOS default shell):

```zsh
zsh <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh)
```

### Manual Download and Run

```bash
curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/kali-prompt-macos/kali-prompt-macos-install.sh -o kali-prompt-macos-install.sh
chmod +x kali-prompt-macos-install.sh
./kali-prompt-macos-install.sh
```

### Activating the New Prompt

After installation, activate the prompt immediately:

```bash
exec zsh -l
```

Or for bash users:

```bash
exec bash -l
```

Alternatively, open a new Terminal window.

---

## How It Works

### Detection Phase

1. **Platform Check:** Verifies running on macOS (Darwin)
2. **Version Check:** Ensures macOS 12.7.6 or later using `sw_vers`
3. **Architecture Detection:** Identifies Intel or Apple Silicon using `uname -m`
4. **User Detection:** Identifies the real user (handles `sudo` correctly)
5. **Shell Detection:** Reads user's login shell via `dscl`

### Installation Phase

1. **Zsh Configuration:** Adds managed block to `~/.zshrc` (primary)
2. **Bash Configuration:** Adds managed block to `~/.bash_profile`
3. **Color Setup:** Configures `CLICOLOR` and `LSCOLORS` for BSD ls

### Verification Phase

1. **Config Check:** Verifies managed blocks are present
2. **Auto-Repair:** Attempts repair if verification fails
3. **Final Validation:** Confirms successful installation

---

## Configuration Details

### Files Modified

| File | Purpose | Priority |
|------|---------|----------|
| `~/.zshrc` | Zsh prompt and aliases | Primary (macOS default) |
| `~/.bash_profile` | Bash prompt and aliases | Secondary |
| `~/.bashrc` | Bash non-login shells | If exists |

### Backup Strategy

Before modifying any file, the script creates a timestamped backup:

```
~/.zshrc.bak.20260415-143022
~/.bash_profile.bak.20260415-143022
```

### Managed Block Format

All configurations are wrapped in managed block markers:

```bash
# >>> kali-prompt-macos-install >>>
# ... configuration ...
# <<< kali-prompt-macos-install <<<
```

---

## Customization

### Changing Prompt Colors

Edit `~/.zshrc` (for zsh) or `~/.bash_profile` (for bash) and modify the color codes:

**Zsh colors:**
```zsh
%F{red}     # Red
%F{green}   # Green
%F{blue}    # Blue
%F{yellow}  # Yellow
%F{magenta} # Magenta
%F{cyan}    # Cyan
%f          # Reset
```

**Bash colors:**
```bash
\033[1;31m  # Bold Red
\033[1;32m  # Bold Green
\033[1;34m  # Bold Blue
\033[1;33m  # Bold Yellow
\033[1;35m  # Bold Magenta
\033[1;36m  # Bold Cyan
\033[0m     # Reset
```

### Customizing LSCOLORS

The `LSCOLORS` variable controls directory listing colors on macOS. The default is:

```bash
export LSCOLORS=ExFxBxDxCxegedabagacad
```

Each pair of characters represents foreground/background colors for different file types.

---

## Troubleshooting

### Prompt Not Changing

**Symptom:** Prompt remains unchanged after installation.

**Solutions:**
1. Start a new shell: `exec zsh -l`
2. Source the config: `source ~/.zshrc`
3. Open a new Terminal window
4. Check the managed block exists: `grep -A5 'kali-prompt-macos' ~/.zshrc`

### Colors Not Displaying

**Symptom:** Prompt shows escape codes instead of colors.

**Solutions:**
1. Ensure Terminal supports colors (Terminal.app and iTerm2 do)
2. Check `TERM` variable: `echo $TERM` (should be `xterm-256color` or similar)
3. Verify `CLICOLOR` is set: `echo $CLICOLOR` (should be `1`)

### Version Check Failing

**Symptom:** Script reports macOS version too old.

**Solutions:**
1. Check your macOS version: `sw_vers -productVersion`
2. Update macOS to 12.7.6 or later
3. The minimum version requirement is intentional for compatibility

### Log File Location

Logs are written to:

```
$TMPDIR/kali-prompt-macos-install/kali-prompt-macos-install-YYYYMMDD-HHMMSS.log
```

Typically: `/var/folders/.../kali-prompt-macos-install/...`

---

## Uninstallation

### Manual Removal

1. Edit `~/.zshrc` and remove the block between:
   ```
   # >>> kali-prompt-macos-install >>>
   ...
   # <<< kali-prompt-macos-install <<<
   ```

2. Edit `~/.bash_profile` and remove the same block.

3. Start a new shell session.

### Restore from Backup

```bash
cp ~/.zshrc.bak.YYYYMMDD-HHMMSS ~/.zshrc
cp ~/.bash_profile.bak.YYYYMMDD-HHMMSS ~/.bash_profile
exec zsh -l
```

---

## Technical Reference

### Script Behavior

| Feature | Behavior |
|---------|----------|
| Error Handling | Graceful per-step failures |
| Idempotency | Re-running updates existing config |
| Backup | Timestamped backups before modification |
| Logging | Full operation log with timestamps |
| Exit Codes | 0 = success, non-zero = failure |

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|--------|
| `LOG_DIR` | Override log directory | `$TMPDIR/kali-prompt-macos-install` |
| `SUDO_USER` | Detect real user via sudo | (system-provided) |

### Variables Set by Script

| Variable | Purpose |
|----------|--------|
| `CLICOLOR` | Enable BSD ls colors |
| `LSCOLORS` | Color scheme for ls output |
| `PS1` | Bash prompt (primary) |
| `PROMPT` | Zsh prompt |

### Aliases Configured

| Alias | Command | Note |
|-------|---------|------|
| `ls` | `ls -G` | BSD color flag |
| `ll` | `ls -alFG` | Long listing with colors |
| `la` | `ls -AG` | All files with colors |
| `l` | `ls -CFG` | Columnar with colors |
| `grep` | `grep --color=auto` | GNU-style |
| `egrep` | `egrep --color=auto` | Extended grep |
| `fgrep` | `fgrep --color=auto` | Fixed grep |

---

*Created by: Thomas Van Auken — Van Auken Tech*
