# CLI Tools Installer — User Manual
### Van Auken Tech · Thomas Van Auken
**Script:** `cli-tools-install.sh`
**Version:** 1.0.0
**Compatibility:** Proxmox VE 8.x / 9.x · Debian Bookworm / Trixie

---

## Purpose

This script installs **46 command-line tools** on a Proxmox VE host in a single unattended run. It is designed to be the first script run on a freshly built PVE host to bring it to a fully equipped operational state.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Operating System | Proxmox VE 8.x or 9.x (Debian Bookworm or Trixie) |
| User | Must be run as **root** |
| Internet | Required — packages downloaded from apt repositories |
| Disk space | ~500 MB free recommended |

---

## Running the Script

### One-liner (recommended)
```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh)
```

### Download and run
```bash
wget -O cli-tools-install.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/cli-tools/cli-tools-install.sh
chmod +x cli-tools-install.sh
./cli-tools-install.sh
```

The script requires no arguments and no interaction. It runs fully automatically from start to finish.

---

## What You Will See

### 1. Header
The VANAUKEN TECH ASCII banner displays, followed by host name, date, PVE version, and the log file path.

### 2. Preflight Checks
The script verifies:
- It is running as root
- Internet connectivity is available (ping 8.8.8.8)

If either check fails, the script stops with a clear error message.

### 3. Configuring Repositories
The script:
- Installs prerequisite tools (`gnupg2`, `ca-certificates`, `wget`, `curl`, `lsb-release`)
- Detects the OS codename
- Enables `contrib`, `non-free`, and `non-free-firmware` in `/etc/apt/sources.list` if not already present

### 4. Updating Package Lists
Runs `apt-get update`. Output goes to the log file only — the terminal shows a single status line.

### 5. Installing Packages
Each package is installed one at a time. Every line shows:
```
    [▸] Installing <package name>...              ✔ OK
```
or
```
    [▸] Installing <package name>...              ✘ FAILED
```
Failed packages are tracked and reported in the final summary. A failure does not stop the script.

### 6. Post-Install Configuration
After all packages are installed, the script automatically:
- Creates a `bat → batcat` symlink (Debian names the bat binary `batcat`)
- Enables and starts the `qemu-guest-agent` systemd service
- Runs `sensors-detect` non-interactively to configure lm-sensors
- Runs `updatedb` to build the plocate file index

### 7. Verification
Each package is checked via `command -v` (binary in PATH) and `dpkg -s` (installed in package database). Results are shown as:
```
    htop                                    ✔ Verified
    some-package                            ✘ Not Found
```

### 8. Final Summary
A colour-coded summary block displays:
- Total installed / total attempted
- Any failures listed in red
- Full list of installed packages in green
- Path to the full log file

---

## Packages Installed

### System Monitoring & Performance
| Package | What It Does |
|---------|-------------|
| `htop` | Interactive process viewer — see CPU, memory, processes in real time |
| `lm-sensors` | Read hardware temperature and voltage sensors |
| `glances` | System-wide monitoring overview (CPU, disk, network, processes) |
| `iftop` | Real-time network bandwidth usage per connection |
| `smartmontools` | S.M.A.R.T. disk health monitoring via `smartctl` |
| `ncdu` | Visual disk usage analyser — find what's consuming space |
| `iotop` | Monitor which processes are reading/writing disk I/O |
| `btop` | Modern resource monitor — successor to htop/top |
| `s-tui` | CPU frequency, utilisation, and temperature TUI with stress test |
| `iptraf-ng` | Interactive IP traffic monitor by interface and connection |

### Storage & File Utilities
| Package | What It Does |
|---------|-------------|
| `rsync` | Efficient file sync and transfer (local or remote via SSH) |
| `zfsutils-linux` | ZFS pool and dataset management (`zpool`, `zfs` commands) |
| `plocate` | Fast file search — `locate filename` using a daily-updated index |
| `dos2unix` | Convert Windows CRLF line endings to Unix LF and vice versa |
| `libguestfs-tools` | Inspect and modify virtual disk images (`virt-filesystems`, etc.) |

### Networking
| Package | What It Does |
|---------|-------------|
| `net-tools` | Classic networking: `ifconfig`, `netstat`, `route` |
| `wget` | Download files from the command line (non-interactive) |
| `curl` | Transfer data with URLs — HTTP, FTP, and more |
| `mtr` | Network diagnostic combining ping + traceroute in one view |
| `ipset` | Manage IP sets for efficient iptables/nftables rules |
| `sshpass` | Non-interactive SSH with password (for scripted connections) |
| `axel` | Multi-connection download accelerator (faster than wget) |
| `nfs-common` | NFS client — mount NFS shares |
| `nfs-kernel-server` | NFS server — export shares to other hosts |
| `qemu-guest-agent` | QEMU/KVM guest agent for PVE management integration |
| `iperf3` | Network bandwidth testing — current version (v3) |
| `iperf` | Network bandwidth testing — legacy version (v2) |

### Shell, Dev & Terminal Tools
| Package | What It Does |
|---------|-------------|
| `tmux` | Terminal multiplexer — multiple panes, persistent sessions |
| `zsh` | Z shell — extended bash with better completion and plugins |
| `git` | Version control system |
| `bat` | Syntax-highlighted `cat` replacement (binary: `batcat` on Debian) |
| `fzf` | Fuzzy finder — interactive search for files, history, etc. |
| `ripgrep` | Extremely fast `grep` alternative (`rg` command) |
| `msr-tools` | Read and write CPU Model Specific Registers (`rdmsr`, `wrmsr`) |
| `finger` | Look up user information |
| `grc` | Generic colouriser — adds colour to command output |
| `dialog` | Create shell dialog boxes and menus in scripts |

### X11 Display & Forwarding
| Package | What It Does |
|---------|-------------|
| `xauth` | X11 authentication cookies — required for SSH X11 forwarding |
| `xterm` | X11 terminal emulator |
| `x11-apps` | Core X11 applications (xclock, xeyes, etc.) |
| `x11-utils` | X11 utilities (`xdpyinfo`, `xwininfo`, etc.) |
| `x11-xserver-utils` | X server utilities (`xrandr`, `xset`, etc.) |
| `xinit` | X session initialiser (`startx`) |
| `xorg` | Full X.Org display server stack |
| `libx11-6` | X11 client-side library (runtime) |
| `libx11-dev` | X11 client-side library development headers |

---

## Log File

The full apt output for every package installation is written to:
```
/var/log/cli-tools-install-YYYYMMDD-HHMMSS.log
```
If a package fails, check this log for the full error message.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Must be run as root` | Script run as non-root user | Run as root or with `sudo` |
| `No internet connectivity` warning | DNS or network issue | Check network, retry |
| Package shows `✘ FAILED` | Apt error (repo, dependency, disk) | Check log file for details |
| `bat` not found after install | Debian installs it as `batcat` | Script creates the symlink automatically |
| `sensors` shows no data | lm-sensors needs module config | Run `sensors-detect` manually |

---

## Notes

- Does **not** use `--no-install-recommends` — full installs with all recommended packages
- `ntop`/`ntopng` is not included — the ntopng community repo does not yet publish Debian Trixie packages
- Running the script again on an already-configured host is safe — apt will skip already-installed packages

---

*Created by: Thomas Van Auken — Van Auken Tech*
*atlas.mgmt.home.vanauken.tech*
