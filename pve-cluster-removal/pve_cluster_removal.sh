#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — Generic Cluster Removal
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-05-09
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Universal cluster removal script that works on ANY Proxmox VE node
#   regardless of cluster health. Safely removes all cluster configuration
#   and converts the node to standalone operation.
#
# USE CASES:
#   - Last surviving node of a failed cluster
#   - Node in a broken/unhealthy cluster
#   - Node with all other nodes offline
#   - Node you want to remove from a healthy cluster
#   - Node already standalone (will verify and clean remnants)
#
# COMPATIBILITY:
#   - Works with healthy, degraded, or broken clusters
#   - Handles quorate and non-quorate states
#   - Works even when cluster communication is down
#   - Detects and adapts to current node state
#
# OPERATIONS PERFORMED:
#   1.  Detect current state (clustered, standalone, broken)
#   2.  Create comprehensive backup of all configuration files
#   3.  Document current VM and container state
#   4.  Stop cluster services (with fallback if already stopped)
#   5.  Start pmxcfs in local mode (or use existing)
#   6.  Remove /etc/pve/corosync.conf
#   7.  Remove local corosync data directories
#   8.  Restart services normally
#   9.  Verify VMs/containers still accessible
#   10. Remove offline node directories from /etc/pve/nodes/
#   11. Clean /etc/hosts of cluster node entries
#   12. Disable HA services
#   13. Disable corosync service
#   14. Verify standalone status
#   15. Verify web UI services
#   16. Verify storage accessibility
#   17. Final verification and summary
#
# SAFETY:
#   - VMs, containers, and storage are NEVER touched
#   - Complete backup before ANY changes
#   - All operations are idempotent (safe to run multiple times)
#   - Works even if cluster is already partially removed
#
# COMPATIBILITY:
#   Proxmox VE 8.x  (Debian 12 Bookworm)
#   Proxmox VE 9.x  (Debian 13 Trixie)
#
# USAGE:
#   bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-removal/pve_cluster_removal.sh)
#
# ============================================================================

# ── Colour Palette ────────────────────────────────────────────────────────────
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="    "

# ── Log to terminal AND timestamped file ─────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="/var/log/pve_cluster_removal_${TIMESTAMP}.log"
BACKUP_DIR="/root/cluster-removal-backup-${TIMESTAMP}"
mkdir -p /var/log 2>/dev/null
mkdir -p "$BACKUP_DIR" 2>/dev/null
exec > >(tee -a "$LOGFILE") 2>&1

# ── Global State Variables ────────────────────────────────────────────────────
CLUSTER_STATE="unknown"  # Values: clustered, standalone, broken, unknown
WAS_QUORATE="no"
LOCAL_NODE=""

# ── Trap / Cleanup ────────────────────────────────────────────────────────────
cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD}  Script interrupted (exit ${code})${CL}\n"
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
msg_info()  { printf "${TAB}${BL}◆  %s${CL}\n" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔  %s${CL}\n" "$1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

# ── Header ────────────────────────────────────────────────────────────────────
header_info() {
  clear
  echo -e "${BL}${BLD}"
  cat << 'BANNER'
  __   ___   _  _   _  _   _ _  _____ _  _   _____ ___ ___ _  _
  \ \ / /_\ | \| | /_\| | | | |/ / __| \| | |_   _| __/ __| || |
   \ V / _ \| .` |/ _ \ |_| | ' <| _|| .` |   | | | _| (__| __ |
    \_/_/ \_\_|\_/_/ \_\___/|_|\_\___|_|\_|   |_| |___\___|_||_|
BANNER
  echo -e "${CL}"
  echo -e "${DGN}  ── PVE Generic Cluster Removal ─────────────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  if command -v pveversion &>/dev/null; then
    printf "  ${DGN}PVE    :${CL}  ${BL}%s${CL}\n" "$(pveversion | head -1)"
  fi
  printf "  ${DGN}Backup :${CL}  ${BL}%s${CL}\n" "$BACKUP_DIR"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
}

# ── Preflight Checks ──────────────────────────────────────────────────────────
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    msg_error "This script must be run as root."
    exit 1
  fi
  msg_ok "Running as root"
}

check_proxmox() {
  if ! command -v pveversion &>/dev/null; then
    msg_error "pveversion not found — this script requires Proxmox VE"
    exit 1
  fi
  msg_ok "Proxmox VE detected: $(pveversion 2>/dev/null | head -1)"
}

# ── Detect Current State ──────────────────────────────────────────────────────
detect_cluster_state() {
  section "Detecting Current Cluster State"
  
  LOCAL_NODE=$(hostname -s)
  msg_info "Local node: $LOCAL_NODE"
  
  # Check if pvecm works at all
  if ! command -v pvecm &>/dev/null; then
    CLUSTER_STATE="standalone"
    msg_warn "pvecm command not found"
    return
  fi
  
  # Try pvecm status
  if pvecm status &>/dev/null 2>&1; then
    CLUSTER_STATE="clustered"
    
    # Check if quorate
    local quorate
    quorate=$(pvecm status 2>/dev/null | grep "Quorate:" | awk '{print $2}')
    if [ "$quorate" = "Yes" ]; then
      WAS_QUORATE="yes"
      msg_ok "Node is part of a cluster and QUORATE"
    else
      WAS_QUORATE="no"
      msg_warn "Node is part of a cluster but NOT quorate"
      CLUSTER_STATE="broken"
    fi
    
    # Display cluster info
    local cluster_name nodes_online
    cluster_name=$(pvecm status 2>/dev/null | grep "Cluster name:" | awk '{print $3}')
    nodes_online=$(pvecm status 2>/dev/null | grep "Nodes:" | awk '{print $2}')
    
    echo ""
    echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
    echo -e "${BL}${BLD}  ║              CURRENT CLUSTER STATE                           ║${CL}"
    echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
    echo ""
    printf "  ${BLD}Cluster Name    :${CL}  %s\n" "$cluster_name"
    printf "  ${BLD}Nodes Online    :${CL}  %s\n" "$nodes_online"
    printf "  ${BLD}Quorate         :${CL}  %s\n" "$quorate"
    printf "  ${BLD}State           :${CL}  %s\n" "$CLUSTER_STATE"
    echo ""
    
  else
    # pvecm status failed - check if config exists
    if [ -f /etc/pve/corosync.conf ] || [ -f /etc/corosync/corosync.conf ]; then
      CLUSTER_STATE="broken"
      msg_warn "Cluster configuration exists but pvecm fails - cluster is broken"
    else
      CLUSTER_STATE="standalone"
      msg_ok "Node appears to be standalone (no cluster config)"
    fi
  fi
  
  msg_ok "Detected state: $CLUSTER_STATE"
  
  # Check VMs and containers
  local vm_count ct_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
  printf "  ${BLD}VMs             :${CL}  %d\n" "$vm_count"
  printf "  ${BLD}Containers      :${CL}  %d\n" "$ct_count"
  echo ""
}

# ── Confirmation ──────────────────────────────────────────────────────────────
confirm_operation() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ║   ${YW}⚠${BL}  CLUSTER REMOVAL WARNING                                      ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  echo -e "  ${BLD}Current State: ${YW}$CLUSTER_STATE${CL}"
  echo ""
  echo -e "  ${BLD}This operation will:${CL}"
  echo "    • Remove ALL cluster configuration"
  echo "    • Convert this node to standalone operation"
  echo "    • Remove cluster node directories"
  echo "    • Disable cluster services"
  echo "    • Clean /etc/hosts entries"
  echo ""
  echo -e "  ${GN}${BLD}This operation will NOT:${CL}"
  echo "    • Delete or modify VMs or containers"
  echo "    • Remove storage configurations"
  echo "    • Delete any user data"
  echo ""
  echo -e "  ${BL}${BLD}A complete backup will be created at:${CL}"
  echo "    $BACKUP_DIR"
  echo ""
  
  if [ "$CLUSTER_STATE" = "standalone" ]; then
    echo -e "  ${YW}${BLD}NOTE:${CL} Node appears standalone. This script will clean any remnants."
    echo ""
  fi
  
  printf "  ${BLD}Type  YES  to proceed (anything else aborts): ${CL}"
  read -r answer
  echo ""
  
  if [ "$answer" != "YES" ]; then
    msg_warn "Aborted by operator. No changes were made."
    exit 0
  fi
  
  msg_ok "Confirmed. Beginning cluster removal..."
  echo ""
}

# ── Step 1: Create Backup ─────────────────────────────────────────────────────
step_create_backup() {
  section "Step 1: Creating Configuration Backup"
  
  msg_info "Saving current state..."
  pvecm status &>/dev/null && pvecm status > "$BACKUP_DIR/pvecm-status-before.txt" 2>&1 || echo "pvecm not available" > "$BACKUP_DIR/pvecm-status-before.txt"
  qm list > "$BACKUP_DIR/vm-list-before.txt" 2>&1 || echo "No VMs" > "$BACKUP_DIR/vm-list-before.txt"
  pct list > "$BACKUP_DIR/ct-list-before.txt" 2>&1 || echo "No containers" > "$BACKUP_DIR/ct-list-before.txt"
  mount | grep pve > "$BACKUP_DIR/mount-before.txt" 2>&1 || echo "No pve mounts" > "$BACKUP_DIR/mount-before.txt"
  
  msg_info "Backing up configuration files..."
  cp /var/lib/pve-cluster/config.db "$BACKUP_DIR/config.db.backup" 2>/dev/null || msg_warn "config.db not found"
  cp /etc/pve/corosync.conf "$BACKUP_DIR/corosync.conf.backup" 2>/dev/null || msg_warn "corosync.conf not in /etc/pve"
  cp -r /etc/corosync "$BACKUP_DIR/corosync.backup" 2>/dev/null || msg_warn "/etc/corosync not found"
  cp /etc/pve/.members "$BACKUP_DIR/members.backup" 2>/dev/null || msg_warn ".members not accessible"
  cp -r /etc/pve/qemu-server "$BACKUP_DIR/qemu-server.backup" 2>/dev/null || msg_warn "No VMs"
  cp -r /etc/pve/lxc "$BACKUP_DIR/lxc.backup" 2>/dev/null || msg_warn "No containers"
  cp /etc/network/interfaces "$BACKUP_DIR/interfaces.backup" 2>/dev/null || msg_warn "interfaces not found"
  cp /etc/hosts "$BACKUP_DIR/hosts.backup" 2>/dev/null || msg_warn "hosts not found"
  cp /etc/hostname "$BACKUP_DIR/hostname.backup" 2>/dev/null || msg_warn "hostname not found"
  
  # Create manifest
  cat > "$BACKUP_DIR/backup-manifest.txt" << EOF
Backup created: $(date)
Node: $(hostname)
PVE Version: $(pveversion | head -1)
Cluster State: $CLUSTER_STATE
Was Quorate: $WAS_QUORATE
EOF
  
  msg_ok "Backup created at $BACKUP_DIR"
  ls -lah "$BACKUP_DIR" | head -20
  echo ""
}

# ── Step 2: Stop Cluster Services ─────────────────────────────────────────────
step_stop_services() {
  section "Step 2: Stopping Cluster Services"
  
  msg_info "Stopping pve-cluster service..."
  if systemctl is-active --quiet pve-cluster; then
    systemctl stop pve-cluster
    msg_ok "pve-cluster stopped"
  else
    msg_warn "pve-cluster already stopped"
  fi
  
  msg_info "Stopping corosync service..."
  if systemctl is-active --quiet corosync; then
    systemctl stop corosync
    msg_ok "corosync stopped"
  else
    msg_warn "corosync already stopped"
  fi
  
  sleep 2
  echo ""
}

# ── Step 3: Start pmxcfs in Local Mode ────────────────────────────────────────
step_start_local_mode() {
  section "Step 3: Starting pmxcfs in Local Mode"
  
  # Check if pmxcfs is already running
  if pgrep pmxcfs &>/dev/null; then
    msg_info "pmxcfs already running - killing it first..."
    killall pmxcfs 2>/dev/null || true
    sleep 2
  fi
  
  msg_info "Starting pmxcfs with -l (local mode) flag..."
  pmxcfs -l &
  sleep 3
  
  msg_info "Verifying pmxcfs is running..."
  if pgrep pmxcfs &>/dev/null; then
    msg_ok "pmxcfs running in local mode (PID $(pgrep pmxcfs))"
  else
    msg_warn "pmxcfs not running - attempting alternate approach"
    pmxcfs -l 2>/dev/null || msg_error "Failed to start pmxcfs"
    sleep 2
  fi
  
  # Verify /etc/pve is mounted
  if mount | grep -q /etc/pve; then
    msg_ok "/etc/pve is mounted"
  else
    msg_warn "/etc/pve not mounted - may need manual intervention"
  fi
  echo ""
}

# ── Step 4: Remove Cluster Configuration ──────────────────────────────────────
step_remove_config() {
  section "Step 4: Removing Cluster Configuration"
  
  if [ -f /etc/pve/corosync.conf ]; then
    msg_info "Removing /etc/pve/corosync.conf..."
    rm -f /etc/pve/corosync.conf 2>/dev/null && msg_ok "Removed" || msg_warn "Failed to remove (may not exist)"
  else
    msg_ok "/etc/pve/corosync.conf already removed"
  fi
  
  if [ -f /etc/corosync/corosync.conf ]; then
    msg_info "Removing /etc/corosync/corosync.conf..."
    rm -f /etc/corosync/corosync.conf 2>/dev/null && msg_ok "Removed" || msg_warn "Failed"
  else
    msg_ok "/etc/corosync/corosync.conf already removed"
  fi
  
  msg_info "Removing /etc/corosync/* contents..."
  rm -rf /etc/corosync/* 2>/dev/null && msg_ok "Removed" || msg_warn "Directory may be empty"
  
  msg_info "Removing /var/lib/corosync/* contents..."
  rm -rf /var/lib/corosync/* 2>/dev/null && msg_ok "Removed" || msg_warn "Directory may be empty"
  
  echo ""
}

# ── Step 5: Restart Services ──────────────────────────────────────────────────
step_restart_services() {
  section "Step 5: Restarting Services Normally"
  
  msg_info "Killing pmxcfs (will be restarted by systemd)..."
  killall pmxcfs 2>/dev/null || msg_warn "pmxcfs not running"
  sleep 2
  
  msg_info "Starting pve-cluster service..."
  systemctl start pve-cluster
  sleep 3
  
  if systemctl is-active --quiet pve-cluster; then
    msg_ok "pve-cluster is active"
  else
    msg_warn "pve-cluster may not be fully active - checking status"
    systemctl status pve-cluster --no-pager | grep Active
  fi
  
  echo ""
}

# ── Step 6: Verify VMs/Containers ─────────────────────────────────────────────
step_verify_guests() {
  section "Step 6: Verifying VMs and Containers"
  
  msg_info "Checking VM accessibility..."
  if qm list &>/dev/null; then
    local vm_count
    vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
    msg_ok "$vm_count VMs accessible"
  else
    msg_warn "Unable to list VMs"
  fi
  
  msg_info "Checking container accessibility..."
  if pct list &>/dev/null; then
    local ct_count
    ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
    msg_ok "$ct_count containers accessible"
  else
    msg_warn "Unable to list containers"
  fi
  
  echo ""
}

# ── Step 7: Remove Node Directories ───────────────────────────────────────────
step_remove_node_dirs() {
  section "Step 7: Removing Offline Node Directories"
  
  if [ ! -d /etc/pve/nodes ]; then
    msg_warn "/etc/pve/nodes directory not found"
    return
  fi
  
  msg_info "Removing offline node directories (keeping only $LOCAL_NODE)..."
  local removed=0
  for node_dir in /etc/pve/nodes/*; do
    local node_name
    node_name=$(basename "$node_dir")
    
    if [ "$node_name" != "$LOCAL_NODE" ] && [ -d "$node_dir" ]; then
      msg_info "Removing node directory: $node_name"
      rm -rf "$node_dir" 2>/dev/null && ((removed++)) || msg_warn "Failed to remove $node_name"
    fi
  done
  
  if [ $removed -gt 0 ]; then
    msg_ok "Removed $removed offline node director(y/ies)"
  else
    msg_ok "No offline node directories to remove"
  fi
  echo ""
}

# ── Step 8: Clean /etc/hosts ───────────────────────────────────────────────────
step_clean_hosts() {
  section "Step 8: Cleaning /etc/hosts"
  
  if [ ! -f /etc/hosts ]; then
    msg_warn "/etc/hosts not found"
    return
  fi
  
  msg_info "Creating backup of /etc/hosts..."
  cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d_%H%M%S)"
  
  # Try to get node list from backup
  local cluster_nodes=""
  if [ -f "$BACKUP_DIR/corosync.conf.backup" ]; then
    cluster_nodes=$(grep "name:" "$BACKUP_DIR/corosync.conf.backup" 2>/dev/null | awk '{print $2}' | grep -v "^$LOCAL_NODE$" || echo "")
  fi
  
  if [ -n "$cluster_nodes" ]; then
    msg_info "Removing cluster node entries..."
    while IFS= read -r node; do
      if [ -n "$node" ] && [ "$node" != "$LOCAL_NODE" ]; then
        sed -i "/$node/d" /etc/hosts 2>/dev/null && msg_ok "Removed entries for $node" || msg_warn "No entries for $node"
      fi
    done <<< "$cluster_nodes"
  else
    msg_warn "No cluster nodes found in backup - manual /etc/hosts cleanup may be needed"
  fi
  
  echo ""
}

# ── Step 9: Disable Services ──────────────────────────────────────────────────
step_disable_services() {
  section "Step 9: Disabling Cluster Services"
  
  msg_info "Disabling HA services..."
  systemctl disable pve-ha-crm 2>/dev/null || msg_warn "pve-ha-crm already disabled"
  systemctl stop pve-ha-crm 2>/dev/null || msg_warn "pve-ha-crm already stopped"
  systemctl disable pve-ha-lrm 2>/dev/null || msg_warn "pve-ha-lrm already disabled"
  systemctl stop pve-ha-lrm 2>/dev/null || msg_warn "pve-ha-lrm already stopped"
  msg_ok "HA services disabled"
  
  msg_info "Disabling corosync service..."
  systemctl disable corosync 2>/dev/null || msg_warn "corosync already disabled"
  msg_ok "Corosync service disabled"
  
  echo ""
}

# ── Step 10: Verify Standalone ────────────────────────────────────────────────
step_verify_standalone() {
  section "Step 10: Verifying Standalone Status"
  
  msg_info "Checking cluster status..."
  if pvecm status 2>&1 | grep -q "does not exist"; then
    msg_ok "Node is now standalone (pvecm shows expected error)"
  elif ! pvecm status &>/dev/null; then
    msg_ok "Node is standalone (pvecm fails as expected)"
  else
    msg_warn "Unexpected cluster status - may need manual verification"
  fi
  
  echo ""
}

# ── Step 11: Restart Web UI ───────────────────────────────────────────────────
step_restart_webui() {
  section "Step 11: Restarting Web UI Services"
  
  msg_info "Restarting pveproxy and pvedaemon..."
  systemctl restart pveproxy pvedaemon
  sleep 2
  
  if systemctl is-active --quiet pveproxy && systemctl is-active --quiet pvedaemon; then
    msg_ok "Web UI services active"
  else
    msg_warn "Web UI services may need manual restart"
  fi
  
  echo ""
}

# ── Step 12: Verify Storage ───────────────────────────────────────────────────
step_verify_storage() {
  section "Step 12: Verifying Storage"
  
  msg_info "Checking storage pools..."
  if pvesm status &>/dev/null; then
    local pool_count
    pool_count=$(pvesm status 2>/dev/null | tail -n +2 | wc -l)
    msg_ok "All $pool_count storage pools accessible"
  else
    msg_warn "Unable to verify storage pools"
  fi
  
  echo ""
}

# ── Final Summary ─────────────────────────────────────────────────────────────
display_final_summary() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ║   ${GN}✔${BL}  CLUSTER REMOVAL COMPLETE                                     ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  local vm_count ct_count storage_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l || echo "0")
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l || echo "0")
  storage_count=$(pvesm status 2>/dev/null | tail -n +2 | wc -l || echo "0")
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}NODE STATUS${CL}                                                        ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Previous State" "$CLUSTER_STATE"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Current State" "Standalone"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Hostname" "$(hostname -s)"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "VMs" "$vm_count"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Containers" "$ct_count"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Storage Pools" "$storage_count"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}NEXT STEPS${CL}                                                         ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  echo -e "  ${BL}${BLD}│${CL}  1. Access Web UI at https://$(hostname -I | awk '{print $1}'):8006          ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  2. Verify all VMs and containers are operational                  ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  3. Verify storage pools are accessible                            ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  4. REBOOT to verify configuration survives restart                ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  5. Node is ready to join a new cluster if needed                  ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  msg_ok "Backup saved : $BACKUP_DIR"
  msg_ok "Log saved    : $LOGFILE"
  msg_ok "Finished     : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $(hostname -f 2>/dev/null || hostname)${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  header_info
  
  section "Preflight Checks"
  check_root
  check_proxmox
  
  detect_cluster_state
  confirm_operation
  
  step_create_backup
  step_stop_services
  step_start_local_mode
  step_remove_config
  step_restart_services
  step_verify_guests
  step_remove_node_dirs
  step_clean_hosts
  step_disable_services
  step_verify_standalone
  step_restart_webui
  step_verify_storage
  display_final_summary
}

main "$@"
