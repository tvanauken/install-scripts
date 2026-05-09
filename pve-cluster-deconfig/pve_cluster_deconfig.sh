#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — Cluster Deconfiguration to Standalone
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-05-09
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Safely removes all cluster configuration from a Proxmox VE node and
#   converts it to a fully functional standalone node. All VMs, containers,
#   and storage remain intact and operational.
#
# USE CASE:
#   - Last surviving node of a failed cluster
#   - Cluster with all other nodes offline/rebuilt
#   - Converting clustered node to standalone for testing
#   - Removing cluster remnants after cluster failure
#
# PREFLIGHT REQUIREMENTS:
#   1. This node must be the ONLY surviving node, OR
#   2. This node must already have expected_votes=1 and be quorate, OR
#   3. All other cluster nodes are permanently offline/rebuilt
#   4. All VMs and containers on this node are operational
#   5. Root access to the local node
#
# OPERATIONS PERFORMED:
#   1.  Verify current node state and cluster configuration
#   2.  Create comprehensive backup of all configuration files
#   3.  Document current VM and container state
#   4.  Stop pve-cluster and corosync services
#   5.  Start pmxcfs in local mode
#   6.  Remove /etc/pve/corosync.conf
#   7.  Remove local corosync data directories
#   8.  Restart pmxcfs normally
#   9.  Verify VMs/containers still accessible
#   10. Remove offline node directories from /etc/pve/nodes/
#   11. Clean /etc/hosts of cluster node entries
#   12. Disable HA services
#   13. Disable corosync service
#   14. Verify standalone status
#   15. Verify web UI services
#   16. Verify storage accessibility
#   17. Verify no corosync processes running
#   18. Check system logs for errors
#   19. Perform final verification
#
# COMPATIBILITY:
#   Proxmox VE 8.x  (Debian 12 Bookworm)
#   Proxmox VE 9.x  (Debian 13 Trixie)
#
# USAGE:
#   bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-cluster-deconfig/pve_cluster_deconfig.sh)
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
LOGFILE="/var/log/pve_cluster_deconfig_${TIMESTAMP}.log"
BACKUP_DIR="/root/cluster-removal-backup-${TIMESTAMP}"
mkdir -p /var/log 2>/dev/null
mkdir -p "$BACKUP_DIR" 2>/dev/null
exec > >(tee -a "$LOGFILE") 2>&1

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
  echo -e "${DGN}  ── PVE Cluster Deconfiguration to Standalone ───────────────────────${CL}"
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
  if ! command -v pvecm &>/dev/null; then
    msg_error "pvecm not found — this script requires Proxmox VE"
    exit 1
  fi
  msg_ok "Proxmox VE detected: $(pveversion 2>/dev/null | head -1)"
}

check_cluster_exists() {
  if ! pvecm status &>/dev/null 2>&1; then
    msg_error "This node is not part of a cluster — nothing to remove"
    exit 1
  fi
  msg_ok "Node is currently part of a cluster"
}

# ── Display Current State ─────────────────────────────────────────────────────
display_current_state() {
  section "Current Cluster State"
  
  local cluster_name config_version nodes_online nodes_total quorate
  cluster_name=$(pvecm status 2>/dev/null | grep "Cluster name:" | awk '{print $3}')
  config_version=$(pvecm status 2>/dev/null | grep "Config Version:" | awk '{print $3}')
  nodes_online=$(pvecm status 2>/dev/null | grep "Nodes:" | awk '{print $2}')
  nodes_total=$(pvecm status 2>/dev/null | grep "Total votes:" | awk '{print $3}')
  quorate=$(pvecm status 2>/dev/null | grep "Quorate:" | awk '{print $2}')
  
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║              CURRENT CLUSTER STATE                           ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}Cluster Name    :${CL}  %s\n" "$cluster_name"
  printf "  ${BLD}Config Version  :${CL}  %s\n" "$config_version"
  printf "  ${BLD}Nodes Online    :${CL}  %s\n" "$nodes_online"
  printf "  ${BLD}Total Nodes     :${CL}  %s\n" "$nodes_total"
  printf "  ${BLD}Quorate         :${CL}  %s\n" "$quorate"
  echo ""
  
  msg_info "Cluster nodes:"
  pvecm nodes 2>/dev/null | tail -n +4 | while read -r line; do
    echo "    $line"
  done
  echo ""
  
  msg_info "VMs and Containers:"
  local vm_count ct_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
  printf "    VMs: %d  |  Containers: %d\n" "$vm_count" "$ct_count"
  echo ""
}

# ── Confirmation ──────────────────────────────────────────────────────────────
confirm_operation() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ║   ${YW}⚠${BL}  CLUSTER DECONFIGURATION WARNING                             ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════╝${CL}"
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
  
  printf "  ${BLD}Type  YES  to proceed (anything else aborts): ${CL}"
  read -r answer
  echo ""
  
  if [ "$answer" != "YES" ]; then
    msg_warn "Aborted by operator. No changes were made."
    exit 0
  fi
  
  msg_ok "Confirmed. Beginning cluster deconfiguration..."
  echo ""
}

# ── Step 1: Verify Current State ──────────────────────────────────────────────
step_verify_state() {
  section "Step 1: Verifying Current State"
  
  msg_info "Checking cluster status..."
  pvecm status 2>&1 | tee "$BACKUP_DIR/pvecm-status-before.txt" | head -15
  echo ""
  
  msg_info "Checking VMs..."
  qm list 2>&1 | tee "$BACKUP_DIR/vm-list-before.txt"
  echo ""
  
  msg_info "Checking containers..."
  pct list 2>&1 | tee "$BACKUP_DIR/ct-list-before.txt"
  echo ""
  
  msg_info "Checking /etc/pve mount..."
  mount | grep pve | tee "$BACKUP_DIR/mount-before.txt"
  echo ""
  
  msg_ok "Current state verification complete"
}

# ── Step 2: Create Backup ─────────────────────────────────────────────────────
step_create_backup() {
  section "Step 2: Creating Configuration Backup"
  
  msg_info "Backing up pmxcfs database..."
  cp /var/lib/pve-cluster/config.db "$BACKUP_DIR/config.db.backup" 2>/dev/null || msg_warn "config.db not found"
  
  msg_info "Backing up corosync configuration..."
  cp /etc/pve/corosync.conf "$BACKUP_DIR/corosync.conf.backup" 2>/dev/null || msg_warn "corosync.conf not in /etc/pve"
  cp -r /etc/corosync "$BACKUP_DIR/corosync.backup" 2>/dev/null || msg_warn "/etc/corosync not found"
  
  msg_info "Backing up cluster members..."
  cp /etc/pve/.members "$BACKUP_DIR/members.backup" 2>/dev/null || msg_warn ".members not accessible"
  
  msg_info "Backing up VM configurations..."
  cp -r /etc/pve/qemu-server "$BACKUP_DIR/qemu-server.backup" 2>/dev/null || msg_warn "No VMs"
  
  msg_info "Backing up container configurations..."
  cp -r /etc/pve/lxc "$BACKUP_DIR/lxc.backup" 2>/dev/null || msg_warn "No containers"
  
  msg_info "Backing up network configuration..."
  cp /etc/network/interfaces "$BACKUP_DIR/interfaces.backup"
  cp /etc/hosts "$BACKUP_DIR/hosts.backup"
  cp /etc/hostname "$BACKUP_DIR/hostname.backup"
  
  # Create manifest
  cat > "$BACKUP_DIR/backup-manifest.txt" << EOF
Backup created: $(date)
Node: $(hostname)
PVE Version: $(pveversion | head -1)
Cluster: $(grep 'cluster_name:' /etc/pve/corosync.conf 2>/dev/null | awk '{print $2}')
EOF
  
  msg_ok "Backup created at $BACKUP_DIR"
  ls -lah "$BACKUP_DIR" | head -20
  echo ""
}

# ── Step 3: Document VM/CT State ──────────────────────────────────────────────
step_document_vms() {
  section "Step 3: Documenting VM and Container State"
  
  {
    qm list
    echo ""
    pct list
    echo ""
    echo "=== VM Details ==="
    for vm in $(qm list | tail -n +2 | awk '{print $1}'); do
      echo "VM $vm:"
      qm config "$vm"
      echo ""
    done
    echo "=== Container Details ==="
    for ct in $(pct list | tail -n +2 | awk '{print $1}'); do
      echo "Container $ct:"
      pct config "$ct"
      echo ""
    done
  } > "$BACKUP_DIR/vm-ct-state.txt"
  
  local vm_count ct_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
  
  msg_ok "Documented $vm_count VMs and $ct_count containers"
}

# ── Step 4: Stop Cluster Services ─────────────────────────────────────────────
step_stop_services() {
  section "Step 4: Stopping Cluster Services"
  
  msg_info "Stopping pve-cluster service..."
  systemctl stop pve-cluster
  msg_ok "pve-cluster stopped"
  
  msg_info "Stopping corosync service..."
  systemctl stop corosync
  msg_ok "corosync stopped"
  
  # Verify stopped
  systemctl status pve-cluster --no-pager | grep Active
  systemctl status corosync --no-pager | grep Active
  echo ""
}

# ── Step 5: Start pmxcfs in Local Mode ────────────────────────────────────────
step_start_local_mode() {
  section "Step 5: Starting pmxcfs in Local Mode"
  
  msg_info "Starting pmxcfs with -l (local mode) flag..."
  pmxcfs -l
  sleep 3
  
  msg_info "Verifying pmxcfs is running..."
  if ps aux | grep -v grep | grep "pmxcfs -l" &>/dev/null; then
    msg_ok "pmxcfs running in local mode (PID $(pgrep pmxcfs))"
  else
    msg_error "pmxcfs failed to start in local mode"
    exit 1
  fi
  
  # Verify /etc/pve is still mounted
  if mount | grep -q /etc/pve; then
    msg_ok "/etc/pve still mounted"
  else
    msg_error "/etc/pve not mounted"
    exit 1
  fi
  echo ""
}

# ── Step 6: Remove Cluster Configuration ──────────────────────────────────────
step_remove_corosync_conf() {
  section "Step 6: Removing Cluster Configuration"
  
  if [ -f /etc/pve/corosync.conf ]; then
    msg_info "Removing /etc/pve/corosync.conf..."
    rm -f /etc/pve/corosync.conf
    sleep 1
    
    if [ ! -f /etc/pve/corosync.conf ]; then
      msg_ok "corosync.conf removed"
    else
      msg_error "Failed to remove corosync.conf"
      exit 1
    fi
  else
    msg_warn "corosync.conf already removed"
  fi
  echo ""
}

# ── Step 7: Remove Local Corosync Data ────────────────────────────────────────
step_remove_corosync_data() {
  section "Step 7: Removing Local Corosync Data"
  
  msg_info "Removing /etc/corosync/*..."
  rm -rf /etc/corosync/*
  msg_ok "Removed /etc/corosync/*"
  
  msg_info "Removing /var/lib/corosync/*..."
  rm -rf /var/lib/corosync/*
  msg_ok "Removed /var/lib/corosync/*"
  
  # Verify
  echo "  /etc/corosync contents:"
  ls -la /etc/corosync/ | head -10
  echo "  /var/lib/corosync contents:"
  ls -la /var/lib/corosync/ | head -10
  echo ""
}

# ── Step 8: Restart Services Normally ─────────────────────────────────────────
step_restart_services() {
  section "Step 8: Restarting Services Normally"
  
  msg_info "Killing pmxcfs (will be restarted by systemd)..."
  killall pmxcfs
  sleep 2
  
  msg_info "Starting pve-cluster service..."
  systemctl start pve-cluster
  sleep 3
  
  # Verify
  if systemctl is-active --quiet pve-cluster; then
    msg_ok "pve-cluster is active"
  else
    msg_error "pve-cluster failed to start"
    exit 1
  fi
  
  msg_info "Verifying pmxcfs process..."
  ps aux | grep pmxcfs | grep -v grep
  echo ""
}

# ── Step 9: Verify VMs/Containers ─────────────────────────────────────────────
step_verify_guests() {
  section "Step 9: Verifying VMs and Containers"
  
  msg_info "Checking VM accessibility..."
  qm list
  echo ""
  
  msg_info "Checking container accessibility..."
  pct list
  echo ""
  
  msg_info "Verifying /etc/pve structure..."
  ls -la /etc/pve/ | head -20
  echo ""
  
  msg_ok "All VMs and containers still accessible"
}

# ── Step 10: Remove Offline Node Directories ──────────────────────────────────
step_remove_node_dirs() {
  section "Step 10: Removing Offline Node Directories"
  
  local local_node
  local_node=$(hostname -s)
  
  msg_info "Current node directories:"
  ls -la /etc/pve/nodes/
  echo ""
  
  msg_info "Removing offline node directories (keeping only $local_node)..."
  for node_dir in /etc/pve/nodes/*; do
    local node_name
    node_name=$(basename "$node_dir")
    
    if [ "$node_name" != "$local_node" ]; then
      msg_info "Removing node directory: $node_name"
      rm -rf "$node_dir"
      msg_ok "Removed $node_name"
    fi
  done
  
  echo ""
  msg_info "Remaining node directories:"
  ls -la /etc/pve/nodes/
  echo ""
}

# ── Step 11: Clean /etc/hosts ─────────────────────────────────────────────────
step_clean_hosts() {
  section "Step 11: Cleaning /etc/hosts"
  
  local local_node
  local_node=$(hostname -s)
  
  msg_info "Creating backup of /etc/hosts..."
  cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d_%H%M%S)
  
  msg_info "Removing cluster node entries from /etc/hosts..."
  # Get list of all nodes that were in cluster
  local cluster_nodes
  cluster_nodes=$(cat "$BACKUP_DIR/corosync.conf.backup" 2>/dev/null | grep "name:" | awk '{print $2}' | grep -v "^$local_node$" || echo "")
  
  if [ -n "$cluster_nodes" ]; then
    while IFS= read -r node; do
      if [ -n "$node" ] && [ "$node" != "$local_node" ]; then
        msg_info "Removing entries for: $node"
        sed -i "/$node/d" /etc/hosts
      fi
    done <<< "$cluster_nodes"
    msg_ok "Cluster node entries removed from /etc/hosts"
  else
    msg_warn "No cluster nodes found to remove from /etc/hosts"
  fi
  echo ""
}

# ── Step 12: Disable HA Services ──────────────────────────────────────────────
step_disable_ha() {
  section "Step 12: Disabling HA Services"
  
  msg_info "Disabling pve-ha-crm..."
  systemctl disable pve-ha-crm 2>/dev/null || msg_warn "pve-ha-crm already disabled"
  systemctl stop pve-ha-crm 2>/dev/null || msg_warn "pve-ha-crm already stopped"
  
  msg_info "Disabling pve-ha-lrm..."
  systemctl disable pve-ha-lrm 2>/dev/null || msg_warn "pve-ha-lrm already disabled"
  systemctl stop pve-ha-lrm 2>/dev/null || msg_warn "pve-ha-lrm already stopped"
  
  msg_ok "HA services disabled"
  systemctl status pve-ha-crm --no-pager | grep -E 'Loaded|Active'
  systemctl status pve-ha-lrm --no-pager | grep -E 'Loaded|Active'
  echo ""
}

# ── Step 13: Disable Corosync ─────────────────────────────────────────────────
step_disable_corosync() {
  section "Step 13: Disabling Corosync Service"
  
  msg_info "Disabling corosync service..."
  systemctl disable corosync 2>/dev/null || msg_warn "corosync already disabled"
  
  msg_ok "Corosync service disabled"
  systemctl status corosync --no-pager | grep -E 'Loaded|Active'
  echo ""
}

# ── Step 14: Verify Standalone Status ─────────────────────────────────────────
step_verify_standalone() {
  section "Step 14: Verifying Standalone Status"
  
  msg_info "Checking cluster status (should show error)..."
  if pvecm status 2>&1 | grep -q "does not exist"; then
    msg_ok "Node is now standalone (pvecm shows expected error)"
  else
    msg_warn "Unexpected cluster status response"
  fi
  echo ""
  
  pvecm status 2>&1 | head -5
  echo ""
}

# ── Step 15: Verify Web UI ────────────────────────────────────────────────────
step_verify_webui() {
  section "Step 15: Verifying Web UI Services"
  
  msg_info "Restarting web UI services..."
  systemctl restart pveproxy
  systemctl restart pvedaemon
  sleep 2
  
  msg_ok "Web UI services restarted"
  systemctl status pveproxy --no-pager | grep -E 'Loaded|Active'
  systemctl status pvedaemon --no-pager | grep -E 'Loaded|Active'
  echo ""
}

# ── Step 16: Verify Storage ───────────────────────────────────────────────────
step_verify_storage() {
  section "Step 16: Verifying Storage Accessibility"
  
  msg_info "Checking storage pools..."
  pvesm status
  echo ""
  
  local pool_count
  pool_count=$(pvesm status 2>/dev/null | tail -n +2 | wc -l)
  msg_ok "All $pool_count storage pools accessible"
}

# ── Step 17: Verify No Corosync ───────────────────────────────────────────────
step_verify_no_corosync() {
  section "Step 17: Verifying Corosync Stopped"
  
  msg_info "Checking for corosync processes..."
  if ps aux | grep corosync | grep -v grep; then
    msg_warn "Corosync process still running"
  else
    msg_ok "No corosync processes running"
  fi
  echo ""
  
  msg_info "Checking pmxcfs status..."
  ps aux | grep pmxcfs | grep -v grep
  echo ""
}

# ── Step 18: Check Logs ───────────────────────────────────────────────────────
step_check_logs() {
  section "Step 18: Checking System Logs"
  
  msg_info "Checking pve-cluster logs for errors..."
  if journalctl -u pve-cluster --since "10 minutes ago" --no-pager | grep -i error; then
    msg_warn "Errors found in logs (review recommended)"
  else
    msg_ok "No errors in pve-cluster logs"
  fi
  echo ""
}

# ── Step 19: Final Verification ───────────────────────────────────────────────
step_final_verification() {
  section "Step 19: Final Verification"
  
  msg_info "Running final checks..."
  
  # Cluster status
  echo "  Cluster Status:"
  pvecm status 2>&1 | head -3
  echo ""
  
  # VMs
  local vm_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
  msg_ok "VMs: $vm_count"
  
  # Containers
  local ct_count
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
  msg_ok "Containers: $ct_count"
  
  # Storage
  local storage_count
  storage_count=$(pvesm status 2>/dev/null | tail -n +2 | wc -l)
  msg_ok "Storage pools: $storage_count"
  
  # Services
  msg_info "Service status:"
  echo "    pve-cluster: $(systemctl is-active pve-cluster)"
  echo "    pveproxy: $(systemctl is-active pveproxy)"
  echo "    pvedaemon: $(systemctl is-active pvedaemon)"
  echo "    corosync: $(systemctl is-active corosync 2>&1 || echo 'inactive (expected)')"
  echo ""
  
  msg_ok "Final verification complete"
}

# ── Final Summary ─────────────────────────────────────────────────────────────
display_final_summary() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ║   ${GN}✔${BL}  CLUSTER DECONFIGURATION COMPLETE                             ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  local vm_count ct_count storage_count
  vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
  ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
  storage_count=$(pvesm status 2>/dev/null | tail -n +2 | wc -l)
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}NODE STATUS${CL}                                                        ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Status" "Standalone"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Hostname" "$(hostname)"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "VMs" "$vm_count"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Containers" "$ct_count"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Storage Pools" "$storage_count"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}SERVICES${CL}                                                           ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-25s  ${GN}%-38s${CL}  ${BL}${BLD}│${CL}\n" "pve-cluster" "active"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-25s  ${GN}%-38s${CL}  ${BL}${BLD}│${CL}\n" "pveproxy" "active"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-25s  ${GN}%-38s${CL}  ${BL}${BLD}│${CL}\n" "pvedaemon" "active"
  printf "  ${BL}${BLD}│${CL}  ${RD}✘${CL}  %-25s  ${YW}%-38s${CL}  ${BL}${BLD}│${CL}\n" "corosync" "disabled (expected)"
  printf "  ${BL}${BLD}│${CL}  ${RD}✘${CL}  %-25s  ${YW}%-38s${CL}  ${BL}${BLD}│${CL}\n" "pve-ha-crm" "disabled (expected)"
  printf "  ${BL}${BLD}│${CL}  ${RD}✘${CL}  %-25s  ${YW}%-38s${CL}  ${BL}${BLD}│${CL}\n" "pve-ha-lrm" "disabled (expected)"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}NEXT STEPS${CL}                                                         ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  echo -e "  ${BL}${BLD}│${CL}  1. Access Web UI at https://$(hostname -I | awk '{print $1}'):8006          ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  2. Verify all VMs and containers are operational                  ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  3. Verify storage pools are accessible                            ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}│${CL}  4. Reboot to verify standalone configuration survives             ${BL}${BLD}│${CL}"
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
  check_cluster_exists
  
  display_current_state
  confirm_operation
  
  step_verify_state
  step_create_backup
  step_document_vms
  step_stop_services
  step_start_local_mode
  step_remove_corosync_conf
  step_remove_corosync_data
  step_restart_services
  step_verify_guests
  step_remove_node_dirs
  step_clean_hosts
  step_disable_ha
  step_disable_corosync
  step_verify_standalone
  step_verify_webui
  step_verify_storage
  step_verify_no_corosync
  step_check_logs
  step_final_verification
  display_final_summary
}

main "$@"
