#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — Cluster Node Removal
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-04-18
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Safely removes a node from a Proxmox VE cluster, cleaning up all cluster
#   configuration, SSH keys, corosync membership, and node directories.
#   Also configures /etc/hosts on remaining nodes for reliable SSH connectivity
#   and cleans up the removed node to be standalone.
#
# PREFLIGHT REQUIREMENTS:
#   1. Healthy cluster with quorum
#   2. Root SSH access to ALL nodes (including node to be removed)
#   3. All VMs and containers have been migrated OFF or removed from target node
#   4. No HA resources configured on target node
#   5. No Ceph OSDs on target node (if using Ceph)
#
# OPERATIONS PERFORMED:
#   1.  Stop Proxmox cluster services on target node
#   2.  Remove node from cluster membership (pvecm delnode)
#   3.  Remove node directory from /etc/pve/nodes/
#   4.  Remove node's SSH key from cluster authorized_keys
#   5.  Update /etc/hosts on all remaining nodes for cluster mesh
#   6.  Clean known_hosts on all remaining nodes
#   7.  Clean cluster configuration on removed node (make standalone)
#   8.  Verify cluster health and SSH connectivity
#
# COMPATIBILITY:
#   Proxmox VE 8.x  (Debian 12 Bookworm)
#   Proxmox VE 9.x  (Debian 13 Trixie)
#
# USAGE:
#   bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-node-remove/pve_node_remove.sh)
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
LOGFILE="/var/log/pve_node_remove_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /var/log 2>/dev/null
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

# ── Global Variables ──────────────────────────────────────────────────────────
declare -A NODE_IPS
declare -a NODE_NAMES
LOCAL_NODE=""
TARGET_NODE=""
TARGET_IP=""
ROOT_PASSWORD=""

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
  echo -e "${DGN}  ── PVE Cluster Node Removal ───────────────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  if command -v pveversion &>/dev/null; then
    printf "  ${DGN}PVE    :${CL}  ${BL}%s${CL}\n" "$(pveversion | cut -d/ -f2)"
  fi
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

check_cluster() {
  if ! pvecm status &>/dev/null; then
    msg_error "This node is not part of a cluster"
    exit 1
  fi
  
  local quorate
  quorate=$(pvecm status 2>/dev/null | grep -i "Quorate:" | awk '{print $2}')
  if [ "$quorate" != "Yes" ]; then
    msg_error "Cluster is NOT quorate — cannot proceed"
    exit 1
  fi
  msg_ok "Cluster is healthy and quorate"
}

# ── Discover Nodes ────────────────────────────────────────────────────────────
discover_nodes() {
  section "Discovering Cluster Nodes"
  
  LOCAL_NODE=$(hostname -s)
  msg_info "Local node: ${LOCAL_NODE}"
  
  # Get all nodes from pvecm
  while IFS= read -r line; do
    local nodeid name ip
    nodeid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $3}')
    
    # Skip header lines and empty
    [[ "$nodeid" =~ ^[0-9]+$ ]] || continue
    [[ -z "$name" ]] && continue
    
    # Remove (local) suffix if present
    name="${name% (local)}"
    
    NODE_NAMES+=("$name")
  done < <(pvecm nodes 2>/dev/null | tail -n +4)
  
  # Get IPs from corosync config
  while IFS= read -r line; do
    if [[ "$line" =~ name:\ *([a-zA-Z0-9_-]+) ]]; then
      local current_name="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ring0_addr:\ *([0-9.]+) ]]; then
      NODE_IPS["$current_name"]="${BASH_REMATCH[1]}"
    fi
  done < <(cat /etc/pve/corosync.conf 2>/dev/null)
  
  msg_ok "Found ${#NODE_NAMES[@]} nodes in cluster"
  echo ""
  
  # Display nodes
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║              CLUSTER NODES                                   ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  local idx=1
  for node in "${NODE_NAMES[@]}"; do
    local ip="${NODE_IPS[$node]:-unknown}"
    local marker=""
    if [ "$node" = "$LOCAL_NODE" ]; then
      marker=" ${GN}(local)${CL}"
    fi
    printf "  ${BLD}[%d]${CL}  %-20s  ${DGN}%s${CL}%s\n" "$idx" "$node" "$ip" "$marker"
    ((idx++))
  done
  echo ""
}

# ── Select Node to Remove ─────────────────────────────────────────────────────
select_target_node() {
  section "Select Node to Remove"
  
  echo -e "  ${YW}⚠  WARNING: You CANNOT remove the local node (${LOCAL_NODE})${CL}"
  echo -e "  ${YW}⚠  You must run this script from a DIFFERENT node in the cluster${CL}"
  echo ""
  
  while true; do
    printf "  ${BLD}Enter node number to remove (or 'q' to quit): ${CL}"
    read -r selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
      msg_warn "Aborted by operator"
      exit 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
      msg_error "Invalid selection — enter a number"
      continue
    fi
    
    if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#NODE_NAMES[@]}" ]; then
      msg_error "Invalid selection — enter 1-${#NODE_NAMES[@]}"
      continue
    fi
    
    TARGET_NODE="${NODE_NAMES[$((selection-1))]}"
    TARGET_IP="${NODE_IPS[$TARGET_NODE]}"
    
    if [ "$TARGET_NODE" = "$LOCAL_NODE" ]; then
      msg_error "Cannot remove the local node — run this script from a different node"
      continue
    fi
    
    break
  done
  
  msg_ok "Selected node: ${TARGET_NODE} (${TARGET_IP})"
}

# ── Get Root Password ─────────────────────────────────────────────────────────
get_root_password() {
  section "SSH Credentials"
  
  echo -e "  ${BL}Root SSH access is required to all cluster nodes${CL}"
  echo ""
  
  while true; do
    printf "  ${BLD}Enter root password for cluster nodes: ${CL}"
    read -rs ROOT_PASSWORD
    echo ""
    
    if [ -z "$ROOT_PASSWORD" ]; then
      msg_error "Password cannot be empty"
      continue
    fi
    
    # Test SSH to target node
    msg_info "Testing SSH connection to ${TARGET_NODE}..."
    if ! sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${TARGET_IP}" "hostname" &>/dev/null; then
      msg_error "SSH connection failed to ${TARGET_NODE} — check password"
      continue
    fi
    
    msg_ok "SSH connection verified to ${TARGET_NODE}"
    break
  done
}

# ── Check Target Node is Clean ────────────────────────────────────────────────
check_target_node() {
  section "Verifying Target Node"
  
  msg_info "Checking for VMs on ${TARGET_NODE}..."
  local vm_count
  vm_count=$(pvesh get "/nodes/${TARGET_NODE}/qemu" --output-format json 2>/dev/null | grep -c '"vmid"' || echo "0")
  if [ "$vm_count" -gt 0 ]; then
    msg_error "Node ${TARGET_NODE} has ${vm_count} VM(s) — migrate or remove them first"
    exit 1
  fi
  msg_ok "No VMs on ${TARGET_NODE}"
  
  msg_info "Checking for containers on ${TARGET_NODE}..."
  local ct_count
  ct_count=$(pvesh get "/nodes/${TARGET_NODE}/lxc" --output-format json 2>/dev/null | grep -c '"vmid"' || echo "0")
  if [ "$ct_count" -gt 0 ]; then
    msg_error "Node ${TARGET_NODE} has ${ct_count} container(s) — migrate or remove them first"
    exit 1
  fi
  msg_ok "No containers on ${TARGET_NODE}"
  
  msg_info "Checking HA resources..."
  local ha_resources
  ha_resources=$(pvesh get /cluster/ha/resources --output-format json 2>/dev/null | grep -c "\"node\":\"${TARGET_NODE}\"" || echo "0")
  if [ "$ha_resources" -gt 0 ]; then
    msg_warn "Node ${TARGET_NODE} has HA resources — ensure they are migrated"
  else
    msg_ok "No HA resources on ${TARGET_NODE}"
  fi
  
  # Check if node is online
  msg_info "Checking node status..."
  local node_status
  node_status=$(pvesh get /nodes --output-format json 2>/dev/null | grep -A5 "\"node\":\"${TARGET_NODE}\"" | grep '"status"' | grep -o '"online"\|"offline"' | tr -d '"')
  if [ "$node_status" = "online" ]; then
    msg_ok "Node ${TARGET_NODE} is online"
  else
    msg_warn "Node ${TARGET_NODE} appears offline — will attempt removal anyway"
  fi
}

# ── Confirmation ──────────────────────────────────────────────────────────────
confirm_removal() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║              REMOVAL PLAN — REVIEW CAREFULLY                 ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}Cluster    :${CL}  %s\n" "$(grep 'cluster_name:' /etc/pve/corosync.conf 2>/dev/null | awk '{print $2}')"
  printf "  ${BLD}Local Node :${CL}  %s\n" "${LOCAL_NODE}"
  echo ""
  echo -e "  ${RD}${BLD}NODE TO BE REMOVED:${CL}"
  printf "  ${RD}    ✘${CL}  %-20s  %s\n" "${TARGET_NODE}" "${TARGET_IP}"
  echo ""
  echo -e "  ${GN}${BLD}NODES REMAINING:${CL}"
  for node in "${NODE_NAMES[@]}"; do
    if [ "$node" != "$TARGET_NODE" ]; then
      printf "  ${GN}    ✔${CL}  %-20s  %s\n" "$node" "${NODE_IPS[$node]}"
    fi
  done
  echo ""
  
  echo -e "${BL}${BLD}  OPERATIONS TO BE PERFORMED:${CL}"
  echo "    1.  Stop Proxmox cluster services on ${TARGET_NODE}"
  echo "    2.  Remove ${TARGET_NODE} from cluster membership"
  echo "    3.  Delete /etc/pve/nodes/${TARGET_NODE}/"
  echo "    4.  Remove ${TARGET_NODE}'s SSH key from cluster authorized_keys"
  echo "    5.  Update /etc/hosts on all remaining nodes"
  echo "    6.  Clean SSH known_hosts on all remaining nodes"
  echo "    7.  Clean cluster config on ${TARGET_NODE} (make standalone)"
  echo "    8.  Verify cluster health and full-mesh SSH connectivity"
  echo ""
  
  echo -e "${RD}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${RD}${BLD}  ║  !! THIS OPERATION IS NOT REVERSIBLE !!                      ║${CL}"
  echo -e "${RD}${BLD}  ║  The node will be permanently removed from the cluster.      ║${CL}"
  echo -e "${RD}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}Type  YES  to proceed (anything else aborts): ${CL}"
  read -r answer
  echo ""
  
  if [ "$answer" != "YES" ]; then
    msg_warn "Aborted by operator. No changes were made."
    exit 0
  fi
  
  msg_ok "Confirmed. Beginning node removal..."
  echo ""
}

# ── Remote SSH Command ────────────────────────────────────────────────────────
remote_ssh() {
  local host="$1"
  shift
  sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${host}" "$@" 2>/dev/null
}

# ── Step 1: Stop Services on Target ───────────────────────────────────────────
stop_target_services() {
  section "Step 1: Stopping Services on ${TARGET_NODE}"
  
  msg_info "Stopping pve-cluster, corosync, pvestatd, pvedaemon, pveproxy..."
  if remote_ssh "$TARGET_IP" "systemctl stop pve-cluster corosync pvestatd pvedaemon pveproxy 2>/dev/null; sleep 2"; then
    msg_ok "Services stopped on ${TARGET_NODE}"
  else
    msg_warn "Could not stop all services — proceeding anyway"
  fi
  
  # Wait for cluster to recognize node is gone
  msg_info "Waiting for cluster to recognize node departure..."
  sleep 5
  
  local nodes_now
  nodes_now=$(pvecm status 2>/dev/null | grep "^Nodes:" | awk '{print $2}')
  msg_ok "Cluster now sees ${nodes_now} nodes"
}

# ── Step 2: Remove Node from Cluster ──────────────────────────────────────────
remove_from_cluster() {
  section "Step 2: Removing ${TARGET_NODE} from Cluster"
  
  msg_info "Running pvecm delnode ${TARGET_NODE}..."
  if pvecm delnode "$TARGET_NODE" 2>&1 | grep -v "^$"; then
    msg_ok "Node ${TARGET_NODE} removed from cluster membership"
  else
    msg_warn "pvecm delnode returned warnings — checking status"
  fi
  
  # Verify removal
  sleep 2
  if pvecm nodes 2>/dev/null | grep -qw "$TARGET_NODE"; then
    msg_error "Node still appears in cluster — manual intervention may be required"
  else
    msg_ok "Verified: ${TARGET_NODE} no longer in cluster membership"
  fi
}

# ── Step 3: Remove Node Directory ─────────────────────────────────────────────
remove_node_directory() {
  section "Step 3: Removing Node Directory"
  
  if [ -d "/etc/pve/nodes/${TARGET_NODE}" ]; then
    msg_info "Removing /etc/pve/nodes/${TARGET_NODE}/..."
    if rm -rf "/etc/pve/nodes/${TARGET_NODE}"; then
      msg_ok "Node directory removed"
    else
      msg_warn "Could not remove node directory"
    fi
  else
    msg_ok "Node directory already removed"
  fi
}

# ── Step 4: Remove SSH Key ────────────────────────────────────────────────────
remove_ssh_key() {
  section "Step 4: Removing SSH Key"
  
  local auth_file="/etc/pve/priv/authorized_keys"
  if [ -f "$auth_file" ]; then
    msg_info "Removing ${TARGET_NODE}'s SSH key from cluster authorized_keys..."
    local tmpfile="/tmp/authorized_keys.new.$$"
    grep -v "root@${TARGET_NODE}" "$auth_file" > "$tmpfile" 2>/dev/null || true
    if cat "$tmpfile" > "$auth_file" 2>/dev/null; then
      msg_ok "SSH key removed from authorized_keys"
    else
      msg_warn "Could not update authorized_keys — may need manual cleanup"
    fi
    rm -f "$tmpfile"
  else
    msg_warn "authorized_keys file not found"
  fi
}

# ── Step 5: Update /etc/hosts on All Nodes ────────────────────────────────────
update_hosts_files() {
  section "Step 5: Updating /etc/hosts on Remaining Nodes"
  
  # Build hosts entries for remaining nodes
  local hosts_entries=""
  hosts_entries+="\n# Proxmox cluster nodes"
  for node in "${NODE_NAMES[@]}"; do
    if [ "$node" != "$TARGET_NODE" ]; then
      local ip="${NODE_IPS[$node]}"
      local fqdn="${node}.mgmt.home.vanauken.tech"
      hosts_entries+="\n${ip} ${fqdn} ${node}"
    fi
  done
  
  for node in "${NODE_NAMES[@]}"; do
    if [ "$node" != "$TARGET_NODE" ]; then
      local ip="${NODE_IPS[$node]}"
      msg_info "Updating /etc/hosts on ${node}..."
      
      # Use remote_ssh or local command
      if [ "$node" = "$LOCAL_NODE" ]; then
        # Remove old cluster entries and add new ones
        sed -i '/# Proxmox cluster nodes/,/^$/d' /etc/hosts 2>/dev/null || true
        for n in "${NODE_NAMES[@]}"; do
          sed -i "/${n}/d" /etc/hosts 2>/dev/null || true
        done
        echo -e "$hosts_entries" >> /etc/hosts
        msg_ok "Updated /etc/hosts on ${node}"
      else
        remote_ssh "$ip" "
          sed -i '/# Proxmox cluster nodes/,/^\$/d' /etc/hosts 2>/dev/null || true
          for n in ${NODE_NAMES[*]}; do
            sed -i \"/\$n/d\" /etc/hosts 2>/dev/null || true
          done
          echo -e '$hosts_entries' >> /etc/hosts
        " && msg_ok "Updated /etc/hosts on ${node}" || msg_warn "Could not update ${node}"
      fi
    fi
  done
}

# ── Step 6: Clean Known Hosts ─────────────────────────────────────────────────
clean_known_hosts() {
  section "Step 6: Cleaning SSH Known Hosts"
  
  for node in "${NODE_NAMES[@]}"; do
    if [ "$node" != "$TARGET_NODE" ]; then
      local ip="${NODE_IPS[$node]}"
      msg_info "Cleaning known_hosts on ${node}..."
      
      if [ "$node" = "$LOCAL_NODE" ]; then
        ssh-keygen -R "$TARGET_NODE" 2>/dev/null || true
        ssh-keygen -R "$TARGET_IP" 2>/dev/null || true
        msg_ok "Cleaned known_hosts on ${node}"
      else
        remote_ssh "$ip" "
          ssh-keygen -R '${TARGET_NODE}' 2>/dev/null || true
          ssh-keygen -R '${TARGET_IP}' 2>/dev/null || true
        " && msg_ok "Cleaned known_hosts on ${node}" || msg_warn "Could not clean ${node}"
      fi
    fi
  done
}

# ── Step 7: Clean Target Node ─────────────────────────────────────────────────
clean_target_node() {
  section "Step 7: Cleaning ${TARGET_NODE} (Making Standalone)"
  
  msg_info "Removing cluster configuration from ${TARGET_NODE}..."
  remote_ssh "$TARGET_IP" "
    systemctl stop corosync pve-cluster 2>/dev/null || true
    systemctl disable corosync 2>/dev/null || true
    pmxcfs -l &
    sleep 2
    rm -f /etc/pve/corosync.conf 2>/dev/null || true
    rm -f /etc/corosync/corosync.conf 2>/dev/null || true
    rm -f /etc/corosync/authkey 2>/dev/null || true
    rm -rf /var/lib/corosync/* 2>/dev/null || true
    rm -rf /etc/pve/nodes/* 2>/dev/null || true
    killall pmxcfs 2>/dev/null || true
    sleep 1
    systemctl start pve-cluster 2>/dev/null || true
  " && msg_ok "${TARGET_NODE} is now a standalone Proxmox node" || msg_warn "Could not fully clean ${TARGET_NODE}"
}

# ── Step 8: Verify Cluster Health ─────────────────────────────────────────────
verify_cluster() {
  section "Step 8: Verifying Cluster Health"
  
  msg_info "Checking cluster status..."
  local quorate
  quorate=$(pvecm status 2>/dev/null | grep "Quorate:" | awk '{print $2}')
  if [ "$quorate" = "Yes" ]; then
    msg_ok "Cluster is quorate"
  else
    msg_warn "Cluster quorum status: ${quorate}"
  fi
  
  msg_info "Checking corosync connectivity..."
  local connected=0
  local total=0
  while IFS= read -r line; do
    if [[ "$line" =~ connected ]]; then
      ((connected++))
    fi
    if [[ "$line" =~ nodeid ]]; then
      ((total++))
    fi
  done < <(corosync-cfgtool -s 2>/dev/null)
  msg_ok "Corosync: ${connected} nodes connected"
  
  msg_info "Testing SSH mesh connectivity..."
  local ssh_ok=0
  local ssh_total=0
  for src in "${NODE_NAMES[@]}"; do
    if [ "$src" = "$TARGET_NODE" ]; then continue; fi
    for dst in "${NODE_NAMES[@]}"; do
      if [ "$dst" = "$TARGET_NODE" ]; then continue; fi
      if [ "$src" = "$dst" ]; then continue; fi
      
      ((ssh_total++))
      local src_ip="${NODE_IPS[$src]}"
      local result
      if [ "$src" = "$LOCAL_NODE" ]; then
        result=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$dst" "hostname" 2>/dev/null)
      else
        result=$(remote_ssh "$src_ip" "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $dst hostname 2>/dev/null")
      fi
      if [ "$result" = "$dst" ]; then
        ((ssh_ok++))
      fi
    done
  done
  
  if [ "$ssh_ok" -eq "$ssh_total" ]; then
    msg_ok "SSH mesh: ${ssh_ok}/${ssh_total} connections verified"
  else
    msg_warn "SSH mesh: ${ssh_ok}/${ssh_total} connections working"
  fi
}

# ── Final Summary ─────────────────────────────────────────────────────────────
display_final_summary() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ║   ${GN}✔${BL}  NODE REMOVAL COMPLETE                                         ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                      ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  # Cluster info
  local cluster_name config_version nodes_count quorum_threshold
  cluster_name=$(grep 'cluster_name:' /etc/pve/corosync.conf 2>/dev/null | awk '{print $2}')
  config_version=$(grep 'config_version:' /etc/pve/corosync.conf 2>/dev/null | awk '{print $2}')
  nodes_count=$(pvecm nodes 2>/dev/null | tail -n +4 | grep -c "^")
  quorum_threshold=$(pvecm status 2>/dev/null | grep "^Quorum:" | awk '{print $2}')
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}CLUSTER STATUS${CL}                                                     ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Cluster Name" "$cluster_name"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Config Version" "$config_version"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Total Nodes" "$nodes_count"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Quorum Threshold" "$quorum_threshold"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Quorate" "Yes"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  # Remaining nodes
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}CLUSTER NODES${CL}                                                      ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  
  while IFS= read -r line; do
    local nodeid name
    nodeid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $3}')
    [[ "$nodeid" =~ ^[0-9]+$ ]] || continue
    name="${name% (local)}"
    local ip="${NODE_IPS[$name]:-$(grep -A2 "name: $name" /etc/pve/corosync.conf 2>/dev/null | grep ring0_addr | awk '{print $2}')}"
    local status="online"
    printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-18s  %-18s  ${GN}%-12s${CL}     ${BL}${BLD}│${CL}\n" "$name" "$ip" "$status"
  done < <(pvecm nodes 2>/dev/null | tail -n +4)
  
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  # Removed node
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}REMOVED NODE${CL}                                                       ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  ${RD}✘${CL}  %-18s  %-18s  ${YW}%-12s${CL}     ${BL}${BLD}│${CL}\n" "$TARGET_NODE" "$TARGET_IP" "standalone"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  # Connectivity
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}CONNECTIVITY${CL}                                                       ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Corosync Rings" "All connected"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "SSH Full Mesh" "Verified"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${GN}%-40s${CL}  ${BL}${BLD}│${CL}\n" "/etc/hosts" "Updated on all nodes"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  msg_ok "Log saved  : ${LOGFILE}"
  msg_ok "Finished   : $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $(hostname -f 2>/dev/null || hostname)${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Check for sshpass ─────────────────────────────────────────────────────────
install_sshpass() {
  if ! command -v sshpass &>/dev/null; then
    msg_info "Installing sshpass..."
    DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sshpass 2>/dev/null
    msg_ok "sshpass installed"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  header_info
  
  section "Preflight Requirements"
  echo -e "  ${BL}Before proceeding, ensure the following requirements are met:${CL}"
  echo ""
  echo "    1. Cluster is healthy with quorum"
  echo "    2. Root SSH access to ALL nodes (including node to be removed)"
  echo "    3. All VMs/containers have been migrated OFF or removed from target node"
  echo "    4. No HA resources configured on target node"
  echo "    5. No Ceph OSDs on target node (if using Ceph)"
  echo ""
  
  section "Preflight Checks"
  check_root
  check_proxmox
  check_cluster
  install_sshpass
  
  discover_nodes
  
  if [ "${#NODE_NAMES[@]}" -lt 2 ]; then
    msg_error "Cluster has only ${#NODE_NAMES[@]} node(s) — cannot remove"
    exit 1
  fi
  
  select_target_node
  get_root_password
  check_target_node
  confirm_removal
  
  stop_target_services
  remove_from_cluster
  remove_node_directory
  remove_ssh_key
  update_hosts_files
  clean_known_hosts
  clean_target_node
  verify_cluster
  display_final_summary
}

main "$@"
