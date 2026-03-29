#!/usr/bin/env bash
# ============================================================================
# Van Auken Tech — Raspberry Pi Setup
# Kali Linux Security Tools · XFCE Remote Desktop · Performance Tuning
# Created by: Thomas Van Auken — Van Auken Tech
# Version: 1.1.1
# Date: 2026-03-29
# Repo: https://github.com/tvanauken/install-scripts
# ============================================================================
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  ⚠  RASPBERRY PI HARDWARE ONLY (armhf / arm64)                         ║
# ║                                                                          ║
# ║  Supported operating systems (all must use apt):                         ║
# ║    · Raspberry Pi OS  (Bookworm 12 / Trixie 13 — armhf or arm64)        ║
# ║    · Ubuntu Desktop   (22.04 LTS / 24.04 LTS — arm64)                   ║
# ║    · Ubuntu Server    (22.04 LTS / 24.04 LTS — arm64)                   ║
# ║    · Kali Linux ARM   (Desktop — arm64)                                  ║
# ║    · Debian ARM       (Bookworm / Trixie — armhf or arm64)               ║
# ║                                                                          ║
# ║  NOT compatible with: x86/x86_64, Proxmox VE, non-apt distros           ║
# ║  Package manager: apt ONLY — snap is explicitly blocked                  ║
# ║                                                                          ║
# ║  USAGE: sudo bash <(curl -s URL)                                         ║
# ║  Do NOT run curl alone. Do NOT omit sudo.                                ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Sections:
#   1  · Hardware detection   (Pi model, arch, RAM, boot config)
#   2  · OS detection         (auto-adapts to distro)
#   3  · Preflight checks
#   4  · Snap prevention      (purge + apt-layer block)
#   5  · Reboot prevention    (kernel hold, unattended-upgrades)
#   6  · System update & base dependencies
#   7  · Security tools       (from distro repos)
#   8  · Python tools         (isolated venv — /opt/security-venv)
#   9  · Ruby tools           (wpscan via gem)
#   10 · Go tools             (pre-built ARM binaries — no compilation)
#   11 · Kali repository + Metasploit
#   12 · Wordlists            (rockyou.txt)
#   13 · XFCE4 + TigerVNC    (headless, port 5901, auto-start)
#   14 · Performance tuning   (CPU, sysctl, services, boot config)
#   15 · ZSH shell environment
#   16 · Verification & summary
# ============================================================================

set -o pipefail

# ── Colour Palette (Van Auken Tech Standard) ─────────────────────────────────
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="  "

# ── Globals ───────────────────────────────────────────────────────────────────
LOGFILE="/var/log/van-auken-pi-setup-$(date +%Y%m%d-%H%M%S).log"
INSTALLED=()
SKIPPED=()
WARNINGS=()

# Hardware
PI_MODEL=""
PI_GEN=0
PI_RAM=0
ARCH=""
GO_ARCH=""
BOOT_CFG=""
GPU_MEM=16
SAFE_FREQ=0
OVER_VOLTAGE=0
LOW_RESOURCE=false

# OS identity (set by detect_os)
OS_ID="unknown"
OS_CODENAME="unknown"
OS_PRETTY="Unknown OS"
OS_IS_KALI=false
OS_IS_UBUNTU=false
OS_IS_RASPBIAN=false
OS_IS_DEBIAN=false

# User context
ACTUAL_USER=""
ACTUAL_HOME=""

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD} Script interrupted (exit ${code}) — log: ${LOGFILE}${CL}\n"
}
trap cleanup EXIT

# ── Helper Functions ──────────────────────────────────────────────────────────
msg_info()  { printf "${TAB}${YW}◆ %s...${CL}\r" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔ %-58s${CL}\n" "$1"; }
msg_error() { printf "${TAB}${RD}✘ %s${CL}\n" "$1" >&2; }
msg_warn()  { printf "${TAB}${YW}⚠ %s${CL}\n" "$1"; WARNINGS+=("$1"); }
section()   { printf "\n${BL}${BLD} ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

install_pkg() {
  local pkg="$1" label="${2:-$1}"
  printf "${TAB}${BL}[▸]${CL} Installing %-42s" "${label}..."
  if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOGFILE" 2>&1; then
    printf "${GN}✔ OK${CL}\n"; INSTALLED+=("$label")
  else
    printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("$label — not available")
  fi
}

# Download pre-built Go binary from GitHub Releases
# NEVER compiles on-device — prevents OOM crash on low-RAM Pi models
download_go_tool() {
  local repo="$1" name="$2" pattern="$3"
  printf "${TAB}${BL}[▸]${CL} Fetching  %-44s" "${name} (${pattern})..."
  if command -v "$name" >/dev/null 2>&1; then
    printf "${GN}✔ Already installed${CL}\n"; INSTALLED+=("$name"); return 0
  fi
  local url
  url=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    | grep -o "\"browser_download_url\": \"[^\"]*${pattern}[^\"]*\.zip\"" \
    | grep -v "sha256\|md5" | head -1 | cut -d'"' -f4)
  if [[ -z "$url" ]]; then
    printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("${name} — no ${pattern} release"); return 1
  fi
  local tmpdir; tmpdir=$(mktemp -d)
  if curl -fsSL "$url" -o "$tmpdir/b.zip" >> "$LOGFILE" 2>&1; then
    unzip -q "$tmpdir/b.zip" -d "$tmpdir/x/" >> "$LOGFILE" 2>&1
    local bin; bin=$(find "$tmpdir/x" -name "$name" -type f 2>/dev/null | head -1)
    if [[ -n "$bin" ]]; then
      install -m 755 "$bin" "/usr/local/bin/$name"
      printf "${GN}✔ OK${CL}\n"; INSTALLED+=("$name")
    else
      printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("${name} — binary not in archive")
    fi
  else
    printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("${name} — download failed")
  fi
  rm -rf "$tmpdir"
}

# ── Header ────────────────────────────────────────────────────────────────────
header_info() {
  clear
  echo -e "${BL}${BLD}"
  cat << 'BANNER'
 __ ___ _ _ _ _ _ _ _____ _ _ _____ ___ ___ _ _
 \ \ / /_\ | \| | /_\| | | | |/ / __| \| | |_ _| __/ __| || |
  \ V / _ \| .` |/ _ \ |_| | ' <| _|| .` | | | | _| (__| __ |
   \_/_/ \_\_|\_/_/ \_\___/|_|\_\___||_|\_| |_| |___\___|_||_|
BANNER
  echo -e "${CL}"
  echo -e "${DGN} ── Raspberry Pi Setup v1.1.1 — Kali Tools · XFCE Desktop · Performance ──${CL}"
  printf " ${DGN}Host  :${CL} ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf " ${DGN}Date  :${CL} ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf " ${DGN}Log   :${CL} ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
  echo "Van Auken Tech Pi Setup v1.1.1 Log - $(date)" > "$LOGFILE"
}

# ── Section 1 — Hardware Detection ───────────────────────────────────────────
detect_hardware() {
  section "Hardware Detection"

  PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown Raspberry Pi")
  PI_RAM=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  ARCH=$(dpkg --print-architecture 2>/dev/null || echo "unknown")

  printf " ${DGN}Model :${CL} ${BL}%s${CL}\n" "$PI_MODEL"
  printf " ${DGN}RAM   :${CL} ${BL}%s MB${CL}\n" "$PI_RAM"
  printf " ${DGN}Arch  :${CL} ${BL}%s${CL}\n" "$ARCH"

  case "$ARCH" in
    armhf) GO_ARCH="linux_arm"  ;;
    arm64) GO_ARCH="linux_arm64" ;;
    *)     msg_warn "Unrecognised architecture: $ARCH — Go binaries will be skipped" ;;
  esac

  if   echo "$PI_MODEL" | grep -q "Raspberry Pi 5";           then PI_GEN=5; SAFE_FREQ=2800; OVER_VOLTAGE=2
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 4";           then PI_GEN=4; SAFE_FREQ=1800; OVER_VOLTAGE=2
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 3 Model B+"; then PI_GEN=3; SAFE_FREQ=1400; OVER_VOLTAGE=0
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 3";           then PI_GEN=3; SAFE_FREQ=1350; OVER_VOLTAGE=2
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi Zero 2";      then PI_GEN=0; SAFE_FREQ=1100; OVER_VOLTAGE=2
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi Zero";        then PI_GEN=0; SAFE_FREQ=0;    OVER_VOLTAGE=0
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 2";           then PI_GEN=2; SAFE_FREQ=1000; OVER_VOLTAGE=2
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi";             then PI_GEN=1; SAFE_FREQ=0;    OVER_VOLTAGE=0
  else                                                              PI_GEN=0; SAFE_FREQ=0;    OVER_VOLTAGE=0
  fi

  if   [[ -f /boot/firmware/config.txt ]]; then BOOT_CFG="/boot/firmware/config.txt"
  elif [[ -f /boot/config.txt ]];          then BOOT_CFG="/boot/config.txt"
  else BOOT_CFG=""; msg_warn "Boot config not found — boot tuning will be skipped"
  fi

  [[ $PI_RAM -lt 512 ]] && GPU_MEM=32 || GPU_MEM=16
  [[ $PI_RAM -lt 768 ]] && LOW_RESOURCE=true && msg_warn "Low RAM (${PI_RAM}MB) — VNC geometry reduced to 1280x720"

  [[ -n "$BOOT_CFG" ]] && printf " ${DGN}Boot  :${CL} ${BL}%s${CL}\n" "$BOOT_CFG"
  printf " ${DGN}GPU   :${CL} ${BL}%sMB (headless-optimised)${CL}\n" "$GPU_MEM"
  [[ $SAFE_FREQ -gt 0 ]] && printf " ${DGN}OC    :${CL} ${BL}%s MHz (over_voltage=%s)${CL}\n" "$SAFE_FREQ" "$OVER_VOLTAGE"
  msg_ok "Hardware: Pi Gen ${PI_GEN} · ${ARCH} · ${PI_RAM}MB RAM"
}

# ── Section 2 — OS Detection ─────────────────────────────────────────────────
detect_os() {
  section "OS Detection"

  if [[ -f /etc/os-release ]]; then
    OS_ID=$(. /etc/os-release       && printf '%s' "${ID:-unknown}")
    OS_CODENAME=$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-unknown}")
    OS_PRETTY=$(. /etc/os-release   && printf '%s' "${PRETTY_NAME:-Unknown OS}")
    local id_like
    id_like=$(. /etc/os-release     && printf '%s' "${ID_LIKE:-}")
  fi

  case "$OS_ID" in
    kali)              OS_IS_KALI=true    ;;
    ubuntu)            OS_IS_UBUNTU=true  ;;
    raspbian|raspios)  OS_IS_RASPBIAN=true ;;
    debian)            OS_IS_DEBIAN=true  ;;
    *)
      echo "$id_like" | grep -q "ubuntu"   && OS_IS_UBUNTU=true
      echo "$id_like" | grep -q "debian"   && OS_IS_DEBIAN=true
      echo "$id_like" | grep -q "raspbian" && OS_IS_RASPBIAN=true
      ;;
  esac

  if   $OS_IS_KALI;    then printf " ${DGN}OS    :${CL} ${BL}%s (Kali Linux — native tools path)${CL}\n"     "$OS_PRETTY"
  elif $OS_IS_UBUNTU;  then printf " ${DGN}OS    :${CL} ${BL}%s (Ubuntu — universe will be enabled)${CL}\n" "$OS_PRETTY"
  elif $OS_IS_RASPBIAN;then printf " ${DGN}OS    :${CL} ${BL}%s (Raspberry Pi OS)${CL}\n"                    "$OS_PRETTY"
  elif $OS_IS_DEBIAN;  then printf " ${DGN}OS    :${CL} ${BL}%s (Debian)${CL}\n"                            "$OS_PRETTY"
  else                      printf " ${DGN}OS    :${CL} ${YW}%s (untested distro — proceeding)${CL}\n"      "$OS_PRETTY"
  fi

  msg_ok "OS detected: ${OS_ID} / ${OS_CODENAME}"
}

# ── Section 3 — Preflight Checks ─────────────────────────────────────────────
preflight() {
  section "Preflight Checks"

  [[ $EUID -ne 0 ]] && { msg_error "Must run as root: sudo bash <(curl -s URL)"; exit 1; }
  msg_ok "Running as root"

  [[ "$ARCH" != "armhf" && "$ARCH" != "arm64" ]] && {
    msg_error "Unsupported architecture: ${ARCH}"
    msg_error "Raspberry Pi hardware (armhf or arm64) required"
    exit 1
  }
  msg_ok "Architecture: ${ARCH}"

  command -v apt-get >/dev/null 2>&1 || {
    msg_error "apt-get not found — requires a Debian/Ubuntu-based OS"
    exit 1
  }
  msg_ok "Package manager: apt"

  local free_kb; free_kb=$(df / | awk 'NR==2{print $4}')
  [[ $free_kb -lt 3145728 ]] \
    && msg_warn "Low disk: $(( free_kb/1024 ))MB free (recommend 3GB+)" \
    || msg_ok "Disk space: $(( free_kb/1024/1024 ))GB free"

  # Internet — try multiple endpoints; succeed if any one responds.
  # A single endpoint (deb.debian.org) fails when DNS is not yet initialised,
  # e.g. inside systemd-run service scopes at early boot. GitHub is tried first
  # since the script was just downloaded from there.
  local _net_ok=false
  for _ep in "https://github.com" "https://archive.ubuntu.com" "https://deb.debian.org" "http://1.1.1.1"; do
    curl -fsSL --max-time 5 "$_ep" > /dev/null 2>&1 && _net_ok=true && break
  done
  unset _ep
  $_net_ok || { msg_error "No internet connectivity — aborting"; exit 1; }
  msg_ok "Internet connectivity confirmed"

  ACTUAL_USER="${SUDO_USER:-${USER}}"
  [[ "$ACTUAL_USER" == "root" ]] && \
    ACTUAL_USER=$(getent passwd 1000 2>/dev/null | cut -d: -f1 || echo "root")
  ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f6 || echo "/root")
  msg_ok "Config target: ${ACTUAL_USER} (${ACTUAL_HOME})"
}

# ── Section 4 — Snap Prevention ──────────────────────────────────────────────
prevent_snap() {
  section "Snap Prevention — apt Only Policy"

  cat > /etc/apt/preferences.d/99no-snap << 'EOF'
# Van Auken Tech — apt only, no snap
Package: snapd
Pin: release a=*
Pin-Priority: -1
EOF
  msg_ok "APT policy: snapd pinned at -1 (permanently blocked)"

  if dpkg -l snapd 2>/dev/null | grep -q '^ii'; then
    msg_info "Removing snapd"
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y snapd >> "$LOGFILE" 2>&1 || true
    rm -rf /snap /var/snap /var/lib/snapd /root/snap "${ACTUAL_HOME}/snap" 2>/dev/null || true
    msg_ok "snapd purged and all snap directories removed"
  else
    msg_ok "snapd not present"
  fi
}

# ── Section 5 — Reboot Prevention ────────────────────────────────────────────
prevent_reboot() {
  section "Reboot Prevention"

  systemctl stop    unattended-upgrades 2>/dev/null || true
  systemctl disable unattended-upgrades 2>/dev/null || true
  cat > /etc/apt/apt.conf.d/99no-autoreboot << 'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
APT::Periodic::Unattended-Upgrade "0";
EOF
  msg_ok "Auto-reboot disabled"

  local kpkgs; kpkgs=$(dpkg-query -W -f='${Package}\n' \
    'linux-image*' 'linux-headers*' 'raspberrypi-kernel*' 2>/dev/null | tr '\n' ' ')
  [[ -n "$kpkgs" ]] && apt-mark hold $kpkgs >> "$LOGFILE" 2>&1 || true
  msg_ok "Kernel packages held — mid-script reboot prevented"

  if ! $OS_IS_KALI; then
    apt-mark hold kali-defaults >> "$LOGFILE" 2>&1 || true
    msg_ok "kali-defaults held (dpkg diversion conflict prevention on non-Kali)"
  fi
}

# ── Section 6 — System Update & Base Dependencies ────────────────────────────
setup_base() {
  section "System Update & Base Dependencies"

  if $OS_IS_UBUNTU; then
    msg_info "Enabling Ubuntu universe and multiverse"
    DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >> "$LOGFILE" 2>&1 || true
    add-apt-repository -y universe   >> "$LOGFILE" 2>&1 || true
    add-apt-repository -y multiverse >> "$LOGFILE" 2>&1 || true
    msg_ok "Ubuntu: universe and multiverse enabled"
  fi

  msg_info "Running apt-get update"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq >> "$LOGFILE" 2>&1
  msg_ok "Package lists updated"

  msg_info "Upgrading packages (kernel held)"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
    -o Dpkg::Options::="--force-confold" >> "$LOGFILE" 2>&1
  msg_ok "System packages upgraded"

  for pkg in \
    curl wget git gnupg2 apt-transport-https ca-certificates lsb-release \
    build-essential python3 python3-pip python3-venv python3-dev \
    ruby ruby-dev ruby-full rubygems-integration \
    golang-go figlet \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    tmux screen vim nano less unzip p7zip-full jq bc tree \
    dbus-x11 x11-xserver-utils xauth xterm; do
    install_pkg "$pkg"
  done
}

# ── Section 7 — Security Tools ───────────────────────────────────────────────
install_security_tools() {
  section "Security Tools — Distribution Repos"

  for pkg in nmap masscan netdiscover arp-scan hping3 fping \
             dnsrecon nbtscan smbclient smbmap \
             snmp snmpd snmp-mibs-downloader onesixtyone \
             netcat-openbsd socat tcpdump tshark wireshark-common \
             mitmproxy proxychains4; do
    install_pkg "$pkg"
  done

  for pkg in nikto sqlmap dirb gobuster wfuzz ffuf whatweb sslscan; do
    install_pkg "$pkg"
  done

  for pkg in hydra medusa john hashcat crunch cewl; do
    install_pkg "$pkg"
  done

  for pkg in aircrack-ng reaver pixiewps macchanger rfkill wireless-tools iw; do
    install_pkg "$pkg"
  done

  for pkg in binwalk foremost testdisk steghide libimage-exiftool-perl \
             gdb gdb-multiarch strace file; do
    install_pkg "$pkg"
  done

  for pkg in recon-ng cherrytree dsniff ettercap-text-only \
             rkhunter chkrootkit lynis tor knockd p0f net-tools htop; do
    install_pkg "$pkg"
  done

  for tool in john lynis chkrootkit netdiscover arp-scan hping3; do
    local src; src=$(find /usr/sbin /sbin -name "$tool" -type f 2>/dev/null | head -1)
    [[ -n "$src" ]] && ln -sf "$src" "/usr/local/bin/$tool" 2>/dev/null || true
  done
  msg_ok "PATH symlinks created for /usr/sbin tools"
}

# ── Section 8 — Python Security Tools ────────────────────────────────────────
install_python_tools() {
  section "Python Security Tools — /opt/security-venv"

  python3 -m venv /opt/security-venv >> "$LOGFILE" 2>&1
  local PIP="/opt/security-venv/bin/pip"
  "$PIP" install --upgrade pip setuptools wheel >> "$LOGFILE" 2>&1
  msg_ok "Python venv created: /opt/security-venv"

  for entry in "impacket:impacket" "scapy:scapy" "theHarvester:theHarvester" \
               "dnspython:dnspython" "requests:requests" "paramiko:paramiko" \
               "colorama:colorama" "rich:rich" "beautifulsoup4:beautifulsoup4"; do
    local pkg="${entry%%:*}" label="${entry##*:}"
    printf "${TAB}${BL}[▸]${CL} pip install %-42s" "${label}..."
    if "$PIP" install "$pkg" >> "$LOGFILE" 2>&1; then
      printf "${GN}✔ OK${CL}\n"; INSTALLED+=("$label (python)")
    else
      printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("$label (python)")
    fi
  done

  for tool in theHarvester theharvester; do
    [[ -f "/opt/security-venv/bin/$tool" ]] && \
      ln -sf "/opt/security-venv/bin/$tool" "/usr/local/bin/$tool" 2>/dev/null || true
  done
  for f in /opt/security-venv/bin/impacket-*; do
    [[ -f "$f" ]] && ln -sf "$f" "/usr/local/bin/$(basename "$f")" 2>/dev/null || true
  done
  msg_ok "Python tool symlinks created"
}

# ── Section 9 — Ruby Security Tools ──────────────────────────────────────────
install_ruby_tools() {
  section "Ruby Security Tools"
  printf "${TAB}${BL}[▸]${CL} gem install %-42s" "wpscan..."
  if gem install wpscan --no-document >> "$LOGFILE" 2>&1; then
    printf "${GN}✔ OK${CL}\n"; INSTALLED+=("wpscan")
  else
    printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("wpscan")
  fi
}

# ── Section 10 — Go Security Tools (Pre-Built Binaries) ──────────────────────
install_go_binaries() {
  section "Go Security Tools — Pre-Built ARM Binaries"
  echo -e "${TAB}${YW}⚠  Pre-built ${GO_ARCH} binaries — no on-device compilation${CL}\n"

  [[ -z "$GO_ARCH" ]] && { msg_warn "No GO_ARCH — Go tools skipped"; return; }

  download_go_tool "projectdiscovery/nuclei"    "nuclei"    "$GO_ARCH"
  download_go_tool "projectdiscovery/subfinder" "subfinder" "$GO_ARCH"
  download_go_tool "projectdiscovery/httpx"     "httpx"     "$GO_ARCH"
  download_go_tool "projectdiscovery/naabu"     "naabu"     "$GO_ARCH"

  local ferox_pat; [[ "$ARCH" == "arm64" ]] && ferox_pat="aarch64" || ferox_pat="arm"
  download_go_tool "epi052/feroxbuster" "feroxbuster" "$ferox_pat"
}

# ── Section 11 — Kali Linux Repository + Metasploit ──────────────────────────
setup_kali_repo() {
  section "Kali Linux Repository + Metasploit"

  if $OS_IS_KALI; then
    msg_ok "Running on Kali Linux — kali-rolling pre-configured"
    echo -e "${TAB}${YW}⚠  Skipping GPG key + repo addition (already Kali)${CL}\n"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq >> "$LOGFILE" 2>&1

    printf "${TAB}${BL}[▸]${CL} Installing %-42s" "metasploit-framework..."
    if command -v msfconsole >/dev/null 2>&1; then
      printf "${GN}✔ Already installed${CL}\n"; INSTALLED+=("metasploit-framework")
    elif DEBIAN_FRONTEND=noninteractive apt-get install -y metasploit-framework >> "$LOGFILE" 2>&1; then
      printf "${GN}✔ OK${CL}\n"; INSTALLED+=("metasploit-framework")
    else
      printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("metasploit-framework")
    fi
    install_pkg "exploitdb" "exploitdb/searchsploit"
    return 0
  fi

  echo -e "${TAB}${YW}⚠  Adding kali-rolling at priority 100 — native packages not overridden${CL}\n"

  msg_info "Installing Kali archive signing key"
  if curl -fsSL https://archive.kali.org/archive-key.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg 2>> "$LOGFILE"; then
    msg_ok "Kali GPG key installed"
  else
    msg_warn "Kali GPG key download failed — Kali-specific packages unavailable"
    return 1
  fi

  echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" \
    > /etc/apt/sources.list.d/kali.list
  msg_ok "Kali repository: /etc/apt/sources.list.d/kali.list"

  cat > /etc/apt/preferences.d/kali-pin << 'EOF'
Package: *
Pin: release a=kali-rolling
Pin-Priority: 100
EOF
  msg_ok "APT pin: kali-rolling=100, native repos=500"

  DEBIAN_FRONTEND=noninteractive apt-get update -qq >> "$LOGFILE" 2>&1
  msg_ok "APT cache refreshed"

  printf "${TAB}${BL}[▸]${CL} Installing %-42s" "metasploit-framework (~500MB)..."
  if DEBIAN_FRONTEND=noninteractive apt-get install -y metasploit-framework >> "$LOGFILE" 2>&1; then
    printf "${GN}✔ OK${CL}\n"; INSTALLED+=("metasploit-framework")
  else
    printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("metasploit-framework")
  fi

  install_pkg "exploitdb" "exploitdb/searchsploit"

  printf "${TAB}${BL}[▸]${CL} Installing %-42s" "kali-linux-core..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y kali-linux-core >> "$LOGFILE" 2>&1 \
    && { printf "${GN}✔ OK${CL}\n"; INSTALLED+=("kali-linux-core"); } \
    || { printf "${YW}⚠ Partial${CL}\n"; SKIPPED+=("kali-linux-core (kali-defaults conflict expected)"); }

  rm -f /var/cache/apt/archives/kali-defaults*.deb 2>/dev/null || true
  DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -y >> "$LOGFILE" 2>&1 || true
  msg_ok "Package state repaired"
}

# ── Section 12 — Wordlists ────────────────────────────────────────────────────
setup_wordlists() {
  section "Wordlists"
  mkdir -p /usr/share/wordlists

  DEBIAN_FRONTEND=noninteractive apt-get install -y wordlists >> "$LOGFILE" 2>&1 || true
  [[ -f /usr/share/wordlists/rockyou.txt.gz ]] && \
    gunzip -f /usr/share/wordlists/rockyou.txt.gz >> "$LOGFILE" 2>&1 || true

  if [[ ! -f /usr/share/wordlists/rockyou.txt ]]; then
    printf "${TAB}${BL}[▸]${CL} Downloading %-40s" "rockyou.txt (134MB)..."
    if curl -fsSL \
      "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
      -o /usr/share/wordlists/rockyou.txt >> "$LOGFILE" 2>&1; then
      printf "${GN}✔ OK${CL}\n"; INSTALLED+=("rockyou.txt")
    else
      printf "${YW}⚠ SKIP${CL}\n"; SKIPPED+=("rockyou.txt — download failed")
    fi
  else
    local lines; lines=$(wc -l < /usr/share/wordlists/rockyou.txt)
    msg_ok "rockyou.txt: $(printf "%'d" "$lines") passwords"
  fi

  msg_warn "SecLists not auto-installed (1.4GB clone exceeds Pi RAM+swap). Manual:"
  echo -e "${TAB}${DGN}  sudo git clone --depth 1 https://github.com/danielmiessler/SecLists /mnt/external/seclists${CL}"
}

# ── Section 13 — XFCE4 Desktop + TigerVNC ────────────────────────────────────
setup_desktop_and_vnc() {
  section "XFCE4 Desktop + TigerVNC Remote Desktop"
  echo -e "${TAB}${YW}⚠  Headless VNC-only — no display manager installed${CL}"
  echo -e "${TAB}${YW}   Default VNC password: VanAwsome1 — change with: vncpasswd${CL}\n"

  for pkg in xfce4 xfce4-terminal xfce4-goodies; do install_pkg "$pkg"; done
  install_pkg "tigervnc-standalone-server" "tigervnc-standalone-server"
  install_pkg "tigervnc-common"

  local VNC_GEOM="1920x1080"
  $LOW_RESOURCE && VNC_GEOM="1280x720"
  msg_ok "VNC geometry: ${VNC_GEOM}"

  mkdir -p "${ACTUAL_HOME}/.vnc"

  printf 'VanAwsome1\nVanAwsome1\n\n' | vncpasswd "${ACTUAL_HOME}/.vnc/passwd" >> "$LOGFILE" 2>&1 || \
    printf '%s\n' 'VanAwsome1' | vncpasswd -f > "${ACTUAL_HOME}/.vnc/passwd"
  chmod 600 "${ACTUAL_HOME}/.vnc/passwd"
  msg_ok "VNC password set (change with: vncpasswd)"

  cat > "${ACTUAL_HOME}/.vnc/xstartup" << 'XSTART'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r /etc/X11/Xresources ]  && xrdb /etc/X11/Xresources
[ -r "$HOME/.Xresources" ]  && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
fi
exec startxfce4 --replace
XSTART
  chmod +x "${ACTUAL_HOME}/.vnc/xstartup"
  chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${ACTUAL_HOME}/.vnc"
  msg_ok "VNC xstartup: XFCE4 (compositor disabled)"

  cat > /etc/systemd/system/vncserver@.service << SVCEOF
[Unit]
Description=TigerVNC Server on display :%i — Van Auken Tech
After=syslog.target network.target
Wants=network.target

[Service]
Type=forking
User=${ACTUAL_USER}
Group=${ACTUAL_USER}
WorkingDirectory=${ACTUAL_HOME}
ExecStartPre=/bin/bash -c "/bin/rm -f /tmp/.X%i-lock /tmp/.X11-unix/X%i 2>/dev/null || true"
ExecStart=/bin/bash -c "/usr/bin/vncserver :%i -geometry ${VNC_GEOM} -depth 24 -localhost no -SecurityTypes VncAuth >> /var/log/vncserver.log 2>&1"
ExecStop=/bin/bash -c "/usr/bin/vncserver -kill :%i >> /var/log/vncserver.log 2>&1"
Restart=on-failure
RestartSec=10
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
SVCEOF

  systemctl daemon-reload
  systemctl enable vncserver@1.service
  msg_ok "VNC service enabled: vncserver@1.service (port 5901)"
  msg_ok "Connect: $(hostname -I 2>/dev/null | awk '{print $1}'):5901"

  mkdir -p /var/log/journal
  systemd-tmpfiles --create --prefix /var/log/journal >> "$LOGFILE" 2>&1 || true
  systemctl restart systemd-journald 2>/dev/null || true
  msg_ok "Persistent journaling enabled"

  ufw allow 5901/tcp >> "$LOGFILE" 2>&1 || true
}

# ── Section 14 — Performance Tuning ──────────────────────────────────────────
tune_performance() {
  section "Performance Tuning"

  for gov in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
    [[ -f "$gov" ]] && echo "performance" > "$gov" || true
  done
  msg_ok "CPU governor: performance (live)"

  cat > /etc/systemd/system/cpu-performance-governor.service << 'EOF'
[Unit]
Description=Set CPU Governor to Performance — Van Auken Tech
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do [ -f \"$f\" ] && echo performance > \"$f\"; done"
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
  systemctl enable cpu-performance-governor.service >> "$LOGFILE" 2>&1
  msg_ok "CPU governor persisted via systemd"

  cat > /etc/sysctl.d/99-van-auken-pi.conf << 'EOF'
# Van Auken Tech — Raspberry Pi Performance Tuning
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
net.core.somaxconn = 1024
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
EOF
  sysctl -p /etc/sysctl.d/99-van-auken-pi.conf >> "$LOGFILE" 2>&1
  msg_ok "Kernel parameters applied (sysctl)"

  local wifi_active=false
  for iface in $(ip link show 2>/dev/null | grep -E "wlan|wifi" | awk '{print $2}' | tr -d ':'); do
    ip link show "$iface" 2>/dev/null | grep -q "state UP" && wifi_active=true && break
  done

  local svc_list=("bluetooth" "ModemManager" "avahi-daemon" "colord"
                  "NetworkManager-wait-online" "rpi-eeprom-update" "rtkit-daemon" "lvm2-monitor")
  $wifi_active || svc_list+=("wpa_supplicant")

  for svc in "${svc_list[@]}"; do
    if systemctl is-active "$svc" &>/dev/null || systemctl is-enabled "$svc" &>/dev/null; then
      systemctl stop "$svc" 2>/dev/null || true
      systemctl disable "$svc" 2>/dev/null || true
      printf "${TAB}${GN}✔${CL} Disabled: %s\n" "$svc"
    fi
  done
  $wifi_active && msg_warn "WiFi active — wpa_supplicant kept running"

  systemctl --global disable pulseaudio.service pulseaudio.socket 2>/dev/null || true
  pkill -x pulseaudio 2>/dev/null || true
  msg_ok "Pulseaudio disabled (~19MB RAM freed)"

  if command -v xfconf-query >/dev/null 2>&1; then
    DISPLAY=:1 xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
    msg_ok "XFCE compositor disabled"
  fi

  if [[ -n "$BOOT_CFG" ]]; then
    cp "$BOOT_CFG" "${BOOT_CFG}.bak.$(date +%Y%m%d)" 2>/dev/null || true

    if ! grep -q "Van Auken Tech Pi Performance" "$BOOT_CFG" 2>/dev/null; then
      cat >> "$BOOT_CFG" << EOF

# ── Van Auken Tech Pi Performance Tuning ─────────────────────────────────────
# Applied by pi-setup.sh v1.1.1 — $(date '+%Y-%m-%d')
gpu_mem=${GPU_MEM}
camera_auto_detect=0
display_auto_detect=0
dtparam=audio=off
disable_splash=1
boot_delay=0
hdmi_blanking=2
EOF
      [[ $PI_GEN -le 4 ]] && sed -i \
        's/^dtoverlay=vc4-kms-v3d/# dtoverlay=vc4-kms-v3d  # disabled by Van Auken Tech pi-setup/' \
        "$BOOT_CFG" 2>/dev/null || true

      if [[ $SAFE_FREQ -gt 0 ]]; then
        cat >> "$BOOT_CFG" << EOF

# CPU overclock — $(tr -d '\0' < /proc/device-tree/model 2>/dev/null | head -c 40)
arm_freq=${SAFE_FREQ}
over_voltage=${OVER_VOLTAGE}
EOF
        msg_ok "CPU overclock: ${SAFE_FREQ}MHz — active after reboot"
      else
        msg_warn "No overclock applied (Pi Zero or unknown model)"
      fi
      msg_ok "Boot config updated: ${BOOT_CFG}"
    else
      msg_ok "Boot config already tuned (skipping)"
    fi
  else
    msg_warn "Boot config not found — skipping"
  fi
}

# ── Section 15 — ZSH Shell Environment ───────────────────────────────────────
write_zshrc() {
  local dest="$1"
  cat > "$dest" << 'ZSHRCEOF'
# ╔═══════════════════════════════════════════════════════════════════════╗
# ║  ZSH Configuration — Van Auken Tech · Raspberry Pi                   ║
# ╚═══════════════════════════════════════════════════════════════════════╝
HISTFILE=~/.zsh_history; HISTSIZE=50000; SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS SHARE_HISTORY APPEND_HISTORY EXTENDED_HISTORY HIST_IGNORE_SPACE
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT NO_BEEP INTERACTIVE_COMMENTS GLOB_DOTS
setopt PROMPT_SUBST
autoload -Uz compinit && compinit -d ~/.zcompdump
zstyle ':completion:*' menu select=2
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-compctl false; zstyle ':completion:*' verbose true; zstyle ':completion:*' group-name ''
prompt_symbol='㉿'
PROMPT=$'%F{%(#.blue.green)}┌──${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))──}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
RPROMPT=$'%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)'
[ -x /usr/bin/dircolors ] && { test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"; }
alias ls='ls --color=auto' ll='ls -la' la='ls -A' l='ls -CF' lt='ls -latr' lh='ls -lah'
alias ..='cd ..' ...='cd ../..' ....='cd ../../..' cls='clear' h='history' j='jobs -l'
alias grep='grep --color=auto' fgrep='fgrep --color=auto' egrep='egrep --color=auto'
alias diff='diff --color=auto' ip='ip --color=auto'
alias update='sudo apt update && sudo apt upgrade -y' install='sudo apt install -y'
alias ports='ss -tuln' myip='curl -s ifconfig.me && echo' localip='hostname -I | awk "{print \$1}"'
alias psg='ps aux | grep' mem='free -h' disk='df -h' listen='ss -tlnp' conns='ss -tanp'
alias vnc-start='sudo systemctl start vncserver@1' vnc-stop='sudo systemctl stop vncserver@1'
alias vnc-restart='sudo systemctl restart vncserver@1' vnc-status='sudo systemctl status vncserver@1'
alias vnc-log='journalctl -u vncserver@1 -f' vnc-passwd='vncpasswd'
alias nmap-quick='nmap -sV -sC' nmap-full='nmap -sV -sC -p-'
alias nmap-udp='sudo nmap -sU --top-ports 200' nmap-vuln='nmap -sV --script vuln'
alias nmap-sweep='sudo nmap -sn' msf='sudo msfconsole' msfconsole='sudo msfconsole'
alias sqlmap-full='sqlmap --batch --level=5 --risk=3' airmon='sudo airmon-ng'
alias wordlists='ls -lh /usr/share/wordlists/' rockyou='wc -l /usr/share/wordlists/rockyou.txt 2>/dev/null'
alias gs='git status' ga='git add .' gc='git commit -m' gp='git push'
alias gl='git log --oneline --graph --color --decorate' gd='git diff'
function extract() {
  [ -f "$1" ] || { echo "'$1' is not a valid file"; return 1; }
  case "$1" in
    *.tar.bz2) tar xjf "$1";; *.tar.gz) tar xzf "$1";; *.bz2) bunzip2 "$1";;
    *.rar) unrar x "$1" 2>/dev/null || 7z x "$1";; *.gz) gunzip "$1";;
    *.tar) tar xf "$1";; *.tgz|*.tbz2) tar xzf "$1";; *.zip) unzip "$1";;
    *.Z) uncompress "$1";; *.7z) 7z x "$1";; *) echo "Cannot extract: $1";;
  esac
}
function mkcd() { mkdir -p "$1" && cd "$1"; }
function backup() { cp "$1"{,.bak.$(date +%Y%m%d-%H%M%S)} && echo "Backup: $1.bak.*"; }
function piinfo() {
  local BL="\033[36m" BLD="\033[1m" DGN="\033[32m" CL="\033[m"
  printf "\n${BL}${BLD}╔══════════════════════════════════════════════════════╗${CL}\n"
  printf " ${DGN}Model  :${CL} ${BL}%s${CL}\n" "$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
  printf " ${DGN}Host   :${CL} ${BL}%s${CL}\n" "$(hostname -f)"
  printf " ${DGN}IP     :${CL} ${BL}%s${CL}\n" "$(hostname -I | awk '{print $1}')"
  printf " ${DGN}Kernel :${CL} ${BL}%s${CL}\n" "$(uname -r)"
  printf " ${DGN}Uptime :${CL} ${BL}%s${CL}\n" "$(uptime -p)"
  printf " ${DGN}CPU °C :${CL} ${BL}%s°C${CL}\n" "$(awk '{printf "%.1f",$1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
  printf " ${DGN}RAM    :${CL} ${BL}%s${CL}\n" "$(free -h | awk '/^Mem:/ {print $3 " used / " $2}')"
  printf " ${DGN}Disk   :${CL} ${BL}%s${CL}\n" "$(df -h / | awk 'NR==2{print $3" used / "$2" ("$5")"}')"
  printf " ${DGN}VNC    :${CL} ${BL}%s:5901${CL}\n" "$(hostname -I | awk '{print $1}')"
  printf "${BL}${BLD}╚══════════════════════════════════════════════════════╝${CL}\n\n"
}
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c6c6c,bold"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
bindkey -e
bindkey '^[[A' history-beginning-search-backward '^[[B' history-beginning-search-forward
bindkey '^[[H' beginning-of-line '^[[F' end-of-line '^[[3~' delete-char
bindkey '\e[1;5C' forward-word '\e[1;5D' backward-word
bindkey '^R' history-incremental-pattern-search-backward
export EDITOR=nano VISUAL=nano PAGER=less LESS='-R -M'
export TERM=xterm-256color LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export EXPLOIT_DB="/usr/share/exploitdb" WORDLISTS="/usr/share/wordlists"
export PATH="$HOME/.local/bin:$HOME/bin:/opt/security-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ZSHRCEOF
}

setup_shell() {
  section "ZSH Shell Environment"

  cat > /usr/local/bin/kali-pi-banner << 'BANNERSCRIPT'
#!/usr/bin/env bash
RD="\033[01;31m"; YW="\033[33m"; GN="\033[1;92m"
DGN="\033[32m"; BL="\033[36m"; CL="\033[m"; BLD="\033[1m"
echo -e "${BL}${BLD}"
command -v figlet >/dev/null 2>&1 \
  && figlet -f small "$(hostname -s | tr '[:lower:]' '[:upper:]')" 2>/dev/null \
  || echo "  $(hostname -s | tr '[:lower:]' '[:upper:]')"
echo -e "${CL}"
echo -e "${DGN} ── Kali Linux Security Tools — Raspberry Pi ────────────────────────${CL}"
printf " ${DGN}Host  :${CL} ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
printf " ${DGN}IP    :${CL} ${BL}%s${CL}\n" "$(hostname -I 2>/dev/null | awk '{print $1}')"
printf " ${DGN}User  :${CL} ${BL}%s${CL}\n" "${USER:-$(whoami)}"
printf " ${DGN}VNC   :${CL} ${BL}%s:5901${CL}\n" "$(hostname -I 2>/dev/null | awk '{print $1}')"
printf " ${DGN}CPU°C :${CL} ${BL}%s°C${CL}\n" "$(awk '{printf "%.1f",$1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
printf " ${DGN}Up    :${CL} ${BL}%s${CL}\n" "$(uptime -p 2>/dev/null)"
echo ""
echo -e "${DGN}${BLD} ────────────────────────────────────────────────────────────────${CL}"
echo -e "${DGN} Created by : Thomas Van Auken — Van Auken Tech${CL}"
echo -e "${DGN}${BLD} ────────────────────────────────────────────────────────────────${CL}"
echo ""
BANNERSCRIPT
  chmod +x /usr/local/bin/kali-pi-banner
  msg_ok "Login banner: /usr/local/bin/kali-pi-banner"

  mkdir -p /etc/zsh
  cat > /etc/zsh/zshrc << 'SYSZSHRC'
# Van Auken Tech — Raspberry Pi System ZSH
if [[ $- == *i* ]]; then
  command clear
  /usr/local/bin/kali-pi-banner
fi
function clear() {
  command clear
  /usr/local/bin/kali-pi-banner
}
SYSZSHRC
  msg_ok "System ZSH: /etc/zsh/zshrc"

  write_zshrc "${ACTUAL_HOME}/.zshrc"
  chown "${ACTUAL_USER}:${ACTUAL_USER}" "${ACTUAL_HOME}/.zshrc" 2>/dev/null || true
  chmod 644 "${ACTUAL_HOME}/.zshrc"
  msg_ok ".zshrc: ${ACTUAL_USER}"

  write_zshrc /root/.zshrc; chmod 644 /root/.zshrc
  msg_ok ".zshrc: root"

  usermod -s /bin/zsh "$ACTUAL_USER" 2>/dev/null || true
  usermod -s /bin/zsh root           2>/dev/null || true
  msg_ok "Default shell: ZSH for ${ACTUAL_USER} and root"

  [[ -d /etc/update-motd.d ]] && chmod -x /etc/update-motd.d/* 2>/dev/null || true
  cat > /etc/motd << MOTDEOF

  Kali Linux Security Tools + XFCE Remote Desktop
  $(tr -d '\0' < /proc/device-tree/model 2>/dev/null | head -c 60)
  $(hostname -f)  ·  VNC port 5901
  Owner: Thomas Van Auken — Van Auken Tech
  Authorized access only. All sessions are logged.

MOTDEOF
  msg_ok "MOTD configured"

  echo "$(hostname -f) — Authorized access only" > /etc/issue.net
  grep -q '^#Banner' /etc/ssh/sshd_config 2>/dev/null && \
    sed -i 's|^#Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
  grep -q '^Banner' /etc/ssh/sshd_config 2>/dev/null || \
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
  msg_ok "SSH banner configured"
}

# ── Section 16 — Verification ─────────────────────────────────────────────────
verify() {
  section "Verification"

  local entries=(
    "nmap:nmap" "masscan:masscan" "netdiscover:netdiscover" "arp-scan:arp-scan"
    "hping3:hping3" "tcpdump:tcpdump" "tshark:tshark" "mitmproxy:mitmproxy"
    "nikto:nikto" "sqlmap:sqlmap" "gobuster:gobuster" "wfuzz:wfuzz" "ffuf:ffuf"
    "whatweb:whatweb" "wpscan:wpscan" "sslscan:sslscan"
    "hydra:hydra" "medusa:medusa" "john:john" "hashcat:hashcat"
    "aircrack-ng:aircrack-ng" "reaver:reaver" "macchanger:macchanger"
    "msfconsole:msfconsole" "msfvenom:msfvenom" "searchsploit:searchsploit"
    "binwalk:binwalk" "steghide:steghide" "exiftool:exiftool"
    "nuclei:nuclei" "subfinder:subfinder" "httpx:httpx"
    "theHarvester:theHarvester" "recon-ng:recon-ng"
    "rkhunter:rkhunter" "chkrootkit:chkrootkit" "lynis:lynis"
    "vncserver:vncserver" "startxfce4:startxfce4" "zsh:zsh"
  )

  local ok=0 fail=0
  for entry in "${entries[@]}"; do
    local label="${entry%%:*}" cmd="${entry##*:}"
    printf "${TAB} %-36s" "$label"
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "${GN}✔ Verified${CL}\n"; ok=$(( ok+1 ))
    else
      printf "${RD}✘ Not Found${CL}\n"; fail=$(( fail+1 ))
    fi
  done
  echo ""
  printf " ${GN}${BLD}Verified: %d${CL}   ${RD}${BLD}Not Found: %d${CL}\n" "$ok" "$fail"
  echo ""
  systemctl is-enabled vncserver@1.service &>/dev/null \
    && msg_ok "VNC service enabled" \
    || msg_warn "VNC service not enabled — run: sudo systemctl enable vncserver@1"
  apt-cache policy snapd 2>/dev/null | grep -q "Candidate: (none)" \
    && msg_ok "snapd blocked at APT layer" \
    || msg_warn "snapd block unconfirmed — check /etc/apt/preferences.d/99no-snap"
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  local total=$(( ${#INSTALLED[@]} + ${#SKIPPED[@]} ))
  local vnc_ip; vnc_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo ""
  echo -e "${BL}${BLD} ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD} VAN AUKEN TECH RASPBERRY PI SETUP COMPLETE — v1.1.1${CL}"
  echo -e "${BL}${BLD} ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf " ${GN}${BLD}Installed : %d / %d${CL}\n" "${#INSTALLED[@]}" "$total"
  [[ ${#SKIPPED[@]}  -gt 0 ]] && printf " ${YW}${BLD}Skipped   : %d${CL}\n" "${#SKIPPED[@]}"
  [[ ${#WARNINGS[@]} -gt 0 ]] && printf " ${YW}${BLD}Warnings  : %d${CL}\n" "${#WARNINGS[@]}"
  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo ""; echo -e " ${YW}${BLD}Skipped:${CL}"
    for s in "${SKIPPED[@]}"; do echo -e "   ${YW}⚠${CL} $s"; done
  fi
  echo ""
  echo -e " ${GN}${BLD}⚠  REBOOT REQUIRED to activate:${CL}"
  echo -e "   ${BL}·${CL} GPU memory reduction to ${GPU_MEM}MB"
  [[ $SAFE_FREQ -gt 0 ]] && echo -e "   ${BL}·${CL} CPU overclock to ${SAFE_FREQ}MHz"
  echo -e "   ${BL}·${CL} All /boot config.txt changes"
  echo ""
  echo -e " ${GN}${BLD}Next Steps:${CL}"
  echo -e "   ${GN}1.${CL} Reboot:               ${BL}sudo reboot${CL}"
  echo -e "   ${GN}2.${CL} Connect via VNC:      ${BL}${vnc_ip}:5901${CL}  (pw: VanAwsome1)"
  echo -e "   ${GN}3.${CL} Change VNC password:  ${BL}vncpasswd${CL}"
  echo -e "   ${GN}4.${CL} Init Metasploit DB:   ${BL}sudo msfdb init${CL}"
  echo -e "   ${GN}5.${CL} Update nuclei:        ${BL}nuclei -update-templates${CL}"
  echo -e "   ${GN}6.${CL} System info:          ${BL}piinfo${CL}"
  echo ""
  echo -e "${DGN}${BLD} ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN} Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN} OS         : ${OS_PRETTY}${CL}"
  echo -e "${DGN} Model      : $(tr -d '\0' < /proc/device-tree/model 2>/dev/null | head -c 60)${CL}"
  echo -e "${DGN} Host       : $(hostname -f)${CL}"
  echo -e "${DGN} Completed  : $(date '+%Y-%m-%d %H:%M:%S')${CL}"
  echo -e "${DGN} Log        : ${LOGFILE}${CL}"
  echo -e "${DGN}${BLD} ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Entry Point ───────────────────────────────────────────────────────────────
main() {
  header_info
  detect_hardware
  detect_os
  preflight
  prevent_snap
  prevent_reboot
  setup_base
  install_security_tools
  install_python_tools
  install_ruby_tools
  install_go_binaries
  setup_kali_repo
  setup_wordlists
  setup_desktop_and_vnc
  tune_performance
  setup_shell
  verify
  summary
}

main "$@"
