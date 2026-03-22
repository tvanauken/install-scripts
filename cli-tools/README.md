# CLI Tools Installer for Proxmox VE

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Tested on: atlas.mgmt.home.vanauken.tech · PVE 9.1.6 · Debian Trixie

## Overview

Installs and verifies **44 CLI tools** on a Proxmox VE host, grouped into logical categories. Features a Proxmox-community-script-style colourised terminal UI with per-package progress, post-install configuration, and a final verification + summary.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

## Packages Installed

### System Monitoring & Performance
| Package | Description |
|---------|-------------|
| htop | Interactive process viewer |
| lm-sensors | Hardware temperature/voltage sensors |
| glances | System monitoring overview |
| iftop | Network bandwidth monitor |
| smartmontools | S.M.A.R.T. disk health monitoring |
| ncdu | NCurses disk usage analyzer |
| iotop | Disk I/O monitor |
| btop | Resource monitor (htop successor) |
| s-tui | CPU stress/frequency TUI |
| iptraf-ng | Interactive IP traffic monitor |

### Storage & File Utilities
| Package | Description |
|---------|-------------|
| rsync | File sync and transfer |
| zfsutils-linux | ZFS management tools |
| plocate | Fast file locate database |
| dos2unix | Line-ending converter |
| libguestfs-tools | Virtual disk/filesystem tools (virt-filesystems) |

### Networking
| Package | Description |
|---------|-------------|
| net-tools | ifconfig, netstat, etc. |
| wget | Non-interactive file downloader |
| curl | URL transfer tool |
| mtr | Network diagnostic (ping + traceroute) |
| ipset | IP set management for iptables |
| sshpass | Non-interactive SSH password auth |
| axel | Multi-connection download accelerator |
| nfs-common | NFS client |
| nfs-kernel-server | NFS server |
| qemu-guest-agent | QEMU/KVM guest agent |

### Shell, Dev & Terminal Tools
| Package | Description |
|---------|-------------|
| tmux | Terminal multiplexer |
| zsh | Z shell |
| git | Version control |
| bat | Cat with syntax highlighting |
| fzf | Fuzzy finder |
| ripgrep | Fast grep alternative |
| msr-tools | CPU MSR read/write utilities |
| finger | User information lookup |
| grc | Generic log colouriser |
| dialog | Shell dialog boxes |

### X11 Display & Forwarding
| Package | Description |
|---------|-------------|
| xauth | X11 authentication for SSH forwarding |
| xterm | X11 terminal emulator |
| x11-apps | Core X11 applications |
| x11-utils | X11 utilities |
| x11-xserver-utils | X server utilities |
| xinit | X session initialiser |
| xorg | Full X.Org display server |
| libx11-6 | X11 client library |
| libx11-dev | X11 client library development headers |

## Post-Install Actions

- Creates `bat → batcat` symlink (Debian installs bat as `batcat`)
- Enables and starts `qemu-guest-agent` service
- Runs `sensors-detect` non-interactively for lm-sensors
- Updates the `plocate` database

## Notes

- Does **not** use `--no-install-recommends` — full package installs with all recommended dependencies
- Enables `contrib`, `non-free`, and `non-free-firmware` apt sources if not already present
- Full install log written to `/var/log/cli-tools-install-YYYYMMDD-HHMMSS.log`

---
*Van Auken Tech · atlas.mgmt.home.vanauken.tech*
