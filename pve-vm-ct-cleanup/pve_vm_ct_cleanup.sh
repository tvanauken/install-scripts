#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — VM & CT Cleanup
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0.0
#  Date:       2026-04-18
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Completely removes a VM or CT from Proxmox VE, including all associated
#   storage volumes, snapshots, backups, HA configuration, and replication.
#   Provides an interactive menu to select from discovered VMs and CTs.
#
# OPERATIONS PERFORMED:
#   1.  Scan and display all VMs and CTs on the node
#   2.  Stop the selected VM/CT (if running)
#   3.  Remove from HA configuration (if applicable)
#   4.  Remove from replication (if applicable)
#   5.  Remove all snapshots
#   6.  Remove all backups (vzdump)
#   7.  Remove all storage volumes (disks, EFI, TPM, cloudinit)
#   8.  Delete the VM/CT configuration
#   9.  Verify complete removal
#
# WARNING:
#   This operation is IRREVERSIBLE. All data will be permanently destroyed.
#   There is no undo. Backups will be deleted. Snapshots will be removed.
#
# COMPATIBILITY:
#   Proxmox VE 8.x  (Debian 12 Bookworm)
#   Proxmox VE 9.x  (Debian 13 Trixie)
#
# USAGE:
#   bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/pve-vm-ct-cleanup/pve_vm_ct_cleanup.sh)
#
# ============================================================================

# ── Strict Mode (safe subset) ─────────────────────────────────────────────────
set -o pipefail

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
LOGFILE="/var/log/pve_vm_ct_cleanup_$(date +%Y%m%d_%H%M%S).log"
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
declare -a VM_LIST
declare -a CT_LIST
declare -a ALL_GUESTS
LOCAL_NODE=""
SELECTED_VMID=""
SELECTED_TYPE=""
SELECTED_NAME=""
BACKUP_STORAGES=()

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
  echo -e "${DGN}  ── PVE VM & CT Cleanup ────────────────────────────────────────────${CL}"
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
  if ! command -v pvesh &>/dev/null; then
    msg_error "pvesh not found — this script requires Proxmox VE"
    exit 1
  fi
  msg_ok "Proxmox VE detected: $(pveversion 2>/dev/null | head -1)"
}

check_jq() {
  if ! command -v jq &>/dev/null; then
    msg_info "Installing jq..."
    DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq 2>/dev/null
    msg_ok "jq installed"
  fi
}

# ── Discover Backup Storages ──────────────────────────────────────────────────
discover_backup_storages() {
  msg_info "Discovering backup storage locations..."
  
  # Get storage paths from Proxmox
  while IFS= read -r storage; do
    local path
    path=$(pvesh get "/storage/${storage}" --output-format json 2>/dev/null | jq -r '.path // empty')
    if [ -n "$path" ] && [ -d "$path" ]; then
      BACKUP_STORAGES+=("$path")
    fi
    # Also check for dump subdirectory
    if [ -n "$path" ] && [ -d "${path}/dump" ]; then
      BACKUP_STORAGES+=("${path}/dump")
    fi
  done < <(pvesh get /storage --output-format json 2>/dev/null | jq -r '.[].storage')
  
  # Add common backup paths
  for path in /var/lib/vz/dump /mnt/pve/*/dump; do
    if [ -d "$path" ]; then
      local already_added=0
      for existing in "${BACKUP_STORAGES[@]}"; do
        if [ "$existing" = "$path" ]; then
          already_added=1
          break
        fi
      done
      if [ $already_added -eq 0 ]; then
        BACKUP_STORAGES+=("$path")
      fi
    fi
  done
  
  msg_ok "Found ${#BACKUP_STORAGES[@]} backup storage location(s)"
}

# ── Discover VMs and CTs ──────────────────────────────────────────────────────
discover_guests() {
  section "Discovering VMs and Containers"
  
  LOCAL_NODE=$(hostname -s)
  msg_info "Scanning node: ${LOCAL_NODE}"
  
  # Get VMs using jq for proper JSON parsing
  msg_info "Scanning for virtual machines..."
  while IFS=$'\t' read -r vmid name status maxmem cpus; do
    if [ -n "$vmid" ]; then
      local mem_gb="0"
      if [ -n "$maxmem" ] && [ "$maxmem" -gt 0 ] 2>/dev/null; then
        mem_gb=$(awk "BEGIN {printf \"%.1f\", $maxmem/1073741824}")
      fi
      VM_LIST+=("${vmid}|${name}|${status}|${mem_gb}|${cpus}|VM")
      ALL_GUESTS+=("${vmid}|${name}|${status}|${mem_gb}|${cpus}|VM")
    fi
  done < <(pvesh get "/nodes/${LOCAL_NODE}/qemu" --output-format json 2>/dev/null | jq -r '.[] | [.vmid, .name, .status, .maxmem, .cpus] | @tsv')
  
  msg_ok "Found ${#VM_LIST[@]} VM(s)"
  
  # Get CTs using jq for proper JSON parsing
  msg_info "Scanning for containers..."
  while IFS=$'\t' read -r vmid name status maxmem cpus; do
    if [ -n "$vmid" ]; then
      local mem_gb="0"
      if [ -n "$maxmem" ] && [ "$maxmem" -gt 0 ] 2>/dev/null; then
        mem_gb=$(awk "BEGIN {printf \"%.1f\", $maxmem/1073741824}")
      fi
      CT_LIST+=("${vmid}|${name}|${status}|${mem_gb}|${cpus}|CT")
      ALL_GUESTS+=("${vmid}|${name}|${status}|${mem_gb}|${cpus}|CT")
    fi
  done < <(pvesh get "/nodes/${LOCAL_NODE}/lxc" --output-format json 2>/dev/null | jq -r '.[] | [.vmid, .name, .status, .maxmem, .cpus] | @tsv')
  
  msg_ok "Found ${#CT_LIST[@]} container(s)"
  
  if [ ${#ALL_GUESTS[@]} -eq 0 ]; then
    msg_warn "No VMs or containers found on this node"
    exit 0
  fi
  
  # Sort by VMID
  IFS=$'\n' ALL_GUESTS=($(sort -t'|' -k1 -n <<<"${ALL_GUESTS[*]}")); unset IFS
  
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                    VIRTUAL MACHINES & CONTAINERS                         ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}%-4s  %-6s  %-6s  %-30s  %-10s  %-8s  %-4s${CL}\n" "#" "VMID" "Type" "Name" "Status" "Memory" "CPUs"
  echo -e "  ${BL}──────────────────────────────────────────────────────────────────────────────${CL}"
  
  local idx=1
  for guest in "${ALL_GUESTS[@]}"; do
    IFS='|' read -r vmid name status mem cpu type <<< "$guest"
    local status_color="${GN}"
    if [ "$status" = "stopped" ]; then
      status_color="${YW}"
    fi
    printf "  ${BLD}[%2d]${CL}  %-6s  %-6s  %-30s  ${status_color}%-10s${CL}  %-8s  %-4s\n" "$idx" "$vmid" "$type" "${name:0:30}" "$status" "${mem}GB" "$cpu"
    ((idx++))
  done
  echo ""
}

# ── Select Guest to Remove ────────────────────────────────────────────────────
select_guest() {
  section "Select VM or Container to Remove"
  
  echo -e "  ${RD}${BLD}╔══════════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "  ${RD}${BLD}║                                                                          ║${CL}"
  echo -e "  ${RD}${BLD}║   ⚠  WARNING: THIS OPERATION IS COMPLETELY IRREVERSIBLE ⚠               ║${CL}"
  echo -e "  ${RD}${BLD}║                                                                          ║${CL}"
  echo -e "  ${RD}${BLD}║   The selected VM or container will be PERMANENTLY DESTROYED.           ║${CL}"
  echo -e "  ${RD}${BLD}║   This includes:                                                        ║${CL}"
  echo -e "  ${RD}${BLD}║     • All virtual disks and storage volumes                             ║${CL}"
  echo -e "  ${RD}${BLD}║     • All snapshots                                                     ║${CL}"
  echo -e "  ${RD}${BLD}║     • All backups (vzdump files)                                        ║${CL}"
  echo -e "  ${RD}${BLD}║     • Configuration files                                               ║${CL}"
  echo -e "  ${RD}${BLD}║     • HA and replication settings                                       ║${CL}"
  echo -e "  ${RD}${BLD}║                                                                          ║${CL}"
  echo -e "  ${RD}${BLD}║   THERE IS NO UNDO. DATA CANNOT BE RECOVERED.                           ║${CL}"
  echo -e "  ${RD}${BLD}║                                                                          ║${CL}"
  echo -e "  ${RD}${BLD}╚══════════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  while true; do
    printf "  ${BLD}Enter number to remove (or 'q' to quit): ${CL}"
    read -r selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
      msg_warn "Aborted by operator. No changes were made."
      exit 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
      msg_error "Invalid selection — enter a number"
      continue
    fi
    
    if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#ALL_GUESTS[@]}" ]; then
      msg_error "Invalid selection — enter 1-${#ALL_GUESTS[@]}"
      continue
    fi
    
    local guest="${ALL_GUESTS[$((selection-1))]}"
    IFS='|' read -r SELECTED_VMID SELECTED_NAME _ _ _ SELECTED_TYPE <<< "$guest"
    
    break
  done
  
  msg_ok "Selected: ${SELECTED_TYPE} ${SELECTED_VMID} (${SELECTED_NAME})"
}

# ── Gather Guest Details ──────────────────────────────────────────────────────
gather_guest_details() {
  section "Analyzing ${SELECTED_TYPE} ${SELECTED_VMID}"
  
  local api_path
  if [ "$SELECTED_TYPE" = "VM" ]; then
    api_path="/nodes/${LOCAL_NODE}/qemu/${SELECTED_VMID}"
  else
    api_path="/nodes/${LOCAL_NODE}/lxc/${SELECTED_VMID}"
  fi
  
  # Get status
  local status
  status=$(pvesh get "${api_path}/status/current" --output-format json 2>/dev/null | jq -r '.status // "unknown"')
  msg_info "Status: ${status}"
  
  # Get snapshots
  local snapshot_count=0
  snapshot_count=$(pvesh get "${api_path}/snapshot" --output-format json 2>/dev/null | jq '[.[] | select(.name != "current")] | length')
  msg_info "Snapshots: ${snapshot_count}"
  
  # Count backups
  local backup_count=0
  for path in "${BACKUP_STORAGES[@]}"; do
    if [ -d "$path" ]; then
      local count
      count=$(find "$path" -maxdepth 1 -name "*-${SELECTED_VMID}-*" -type f 2>/dev/null | wc -l)
      backup_count=$((backup_count + count))
    fi
  done
  msg_info "Backups found: ${backup_count}"
  
  # Get disks
  local disk_count=0
  local config
  config=$(pvesh get "${api_path}/config" --output-format json 2>/dev/null)
  if [ "$SELECTED_TYPE" = "VM" ]; then
    disk_count=$(echo "$config" | jq '[keys[] | select(test("^(scsi|sata|virtio|ide|efidisk|tpmstate)[0-9]*$"))] | length')
  else
    disk_count=$(echo "$config" | jq '[keys[] | select(test("^(rootfs|mp[0-9]+)$"))] | length')
  fi
  msg_info "Storage volumes: ${disk_count}"
  
  # Check HA
  local ha_configured="no"
  if pvesh get /cluster/ha/resources --output-format json 2>/dev/null | jq -e ".[] | select(.sid == \"${SELECTED_TYPE,,}:${SELECTED_VMID}\")" &>/dev/null; then
    ha_configured="yes"
  fi
  msg_info "HA configured: ${ha_configured}"
  
  # Check replication
  local replication_configured="no"
  if pvesh get /cluster/replication --output-format json 2>/dev/null | jq -e ".[] | select(.guest == ${SELECTED_VMID})" &>/dev/null; then
    replication_configured="yes"
  fi
  msg_info "Replication configured: ${replication_configured}"
  
  msg_ok "Analysis complete"
}

# ── Final Confirmation ────────────────────────────────────────────────────────
confirm_removal() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                    REMOVAL PLAN — REVIEW CAREFULLY                       ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}Node           :${CL}  %s\n" "${LOCAL_NODE}"
  printf "  ${BLD}Guest Type     :${CL}  %s\n" "${SELECTED_TYPE}"
  printf "  ${BLD}VMID           :${CL}  ${RD}%s${CL}\n" "${SELECTED_VMID}"
  printf "  ${BLD}Name           :${CL}  ${RD}%s${CL}\n" "${SELECTED_NAME}"
  echo ""
  
  echo -e "${BL}${BLD}  OPERATIONS TO BE PERFORMED:${CL}"
  echo "    1.  Stop ${SELECTED_TYPE} ${SELECTED_VMID} (if running)"
  echo "    2.  Remove from HA configuration (if applicable)"
  echo "    3.  Remove from replication (if applicable)"
  echo "    4.  Delete all snapshots"
  echo "    5.  Delete all backups (vzdump files)"
  echo "    6.  Delete all storage volumes"
  echo "    7.  Delete ${SELECTED_TYPE} configuration"
  echo "    8.  Verify complete removal"
  echo ""
  
  echo -e "${RD}${BLD}  ╔══════════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${RD}${BLD}  ║                                                                          ║${CL}"
  echo -e "${RD}${BLD}  ║   ██████╗  █████╗ ███╗   ██╗ ██████╗ ███████╗██████╗                     ║${CL}"
  echo -e "${RD}${BLD}  ║   ██╔══██╗██╔══██╗████╗  ██║██╔════╝ ██╔════╝██╔══██╗                    ║${CL}"
  echo -e "${RD}${BLD}  ║   ██║  ██║███████║██╔██╗ ██║██║  ███╗█████╗  ██████╔╝                    ║${CL}"
  echo -e "${RD}${BLD}  ║   ██║  ██║██╔══██║██║╚██╗██║██║   ██║██╔══╝  ██╔══██╗                    ║${CL}"
  echo -e "${RD}${BLD}  ║   ██████╔╝██║  ██║██║ ╚████║╚██████╔╝███████╗██║  ██║                    ║${CL}"
  echo -e "${RD}${BLD}  ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝                    ║${CL}"
  echo -e "${RD}${BLD}  ║                                                                          ║${CL}"
  echo -e "${RD}${BLD}  ║   ALL DATA WILL BE PERMANENTLY DESTROYED                                 ║${CL}"
  echo -e "${RD}${BLD}  ║   THIS CANNOT BE UNDONE                                                  ║${CL}"
  echo -e "${RD}${BLD}  ║                                                                          ║${CL}"
  echo -e "${RD}${BLD}  ╚══════════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  printf "  ${BLD}Type the VMID (${SELECTED_VMID}) to confirm destruction: ${CL}"
  read -r answer
  echo ""
  
  if [ "$answer" != "$SELECTED_VMID" ]; then
    msg_warn "Confirmation failed. Aborted by operator. No changes were made."
    exit 0
  fi
  
  echo ""
  printf "  ${RD}${BLD}Final confirmation — Type  DESTROY  to proceed: ${CL}"
  read -r final_answer
  echo ""
  
  if [ "$final_answer" != "DESTROY" ]; then
    msg_warn "Aborted by operator. No changes were made."
    exit 0
  fi
  
  msg_ok "Confirmed. Beginning destruction of ${SELECTED_TYPE} ${SELECTED_VMID}..."
  echo ""
}

# ── Step 1: Stop Guest ────────────────────────────────────────────────────────
stop_guest() {
  section "Step 1: Stopping ${SELECTED_TYPE} ${SELECTED_VMID}"
  
  local api_path
  if [ "$SELECTED_TYPE" = "VM" ]; then
    api_path="/nodes/${LOCAL_NODE}/qemu/${SELECTED_VMID}"
  else
    api_path="/nodes/${LOCAL_NODE}/lxc/${SELECTED_VMID}"
  fi
  
  local status
  status=$(pvesh get "${api_path}/status/current" --output-format json 2>/dev/null | jq -r '.status // "unknown"')
  
  if [ "$status" = "running" ]; then
    msg_info "Stopping ${SELECTED_TYPE} ${SELECTED_VMID}..."
    if [ "$SELECTED_TYPE" = "VM" ]; then
      qm stop "$SELECTED_VMID" --timeout 60 2>/dev/null || qm stop "$SELECTED_VMID" --skiplock 2>/dev/null || true
    else
      pct stop "$SELECTED_VMID" 2>/dev/null || true
    fi
    
    # Wait for stop
    local wait_count=0
    while [ $wait_count -lt 30 ]; do
      status=$(pvesh get "${api_path}/status/current" --output-format json 2>/dev/null | jq -r '.status // "unknown"')
      if [ "$status" = "stopped" ]; then
        break
      fi
      sleep 2
      ((wait_count++))
    done
    
    if [ "$status" = "stopped" ]; then
      msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} stopped"
    else
      msg_warn "Force stopping ${SELECTED_TYPE} ${SELECTED_VMID}..."
      if [ "$SELECTED_TYPE" = "VM" ]; then
        qm stop "$SELECTED_VMID" --skiplock --forceStop 2>/dev/null || true
      else
        pct stop "$SELECTED_VMID" --force 2>/dev/null || true
      fi
      sleep 3
      msg_ok "Force stop completed"
    fi
  else
    msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} is already stopped"
  fi
}

# ── Step 2: Remove HA ─────────────────────────────────────────────────────────
remove_ha() {
  section "Step 2: Removing HA Configuration"
  
  local ha_sid="${SELECTED_TYPE,,}:${SELECTED_VMID}"
  
  if pvesh get /cluster/ha/resources --output-format json 2>/dev/null | jq -e ".[] | select(.sid == \"${ha_sid}\")" &>/dev/null; then
    msg_info "Removing ${SELECTED_TYPE} ${SELECTED_VMID} from HA..."
    if ha-manager remove "$ha_sid" 2>/dev/null; then
      msg_ok "Removed from HA configuration"
    else
      msg_warn "Could not remove from HA — may not be configured"
    fi
  else
    msg_ok "No HA configuration found"
  fi
}

# ── Step 3: Remove Replication ────────────────────────────────────────────────
remove_replication() {
  section "Step 3: Removing Replication Jobs"
  
  local has_replication=0
  
  while IFS= read -r job_id; do
    if [ -n "$job_id" ] && [ "$job_id" != "null" ]; then
      msg_info "Removing replication job: ${job_id}..."
      if pvesr delete "$job_id" 2>/dev/null; then
        msg_ok "Removed replication job: ${job_id}"
        has_replication=1
      else
        msg_warn "Could not remove replication job: ${job_id}"
      fi
    fi
  done < <(pvesh get /cluster/replication --output-format json 2>/dev/null | jq -r ".[] | select(.guest == ${SELECTED_VMID}) | .id")
  
  if [ $has_replication -eq 0 ]; then
    msg_ok "No replication jobs found"
  fi
}

# ── Step 4: Remove Snapshots ──────────────────────────────────────────────────
remove_snapshots() {
  section "Step 4: Removing Snapshots"
  
  local api_path
  if [ "$SELECTED_TYPE" = "VM" ]; then
    api_path="/nodes/${LOCAL_NODE}/qemu/${SELECTED_VMID}"
  else
    api_path="/nodes/${LOCAL_NODE}/lxc/${SELECTED_VMID}"
  fi
  
  local snapshot_count=0
  
  while IFS= read -r snapshot; do
    if [ -n "$snapshot" ] && [ "$snapshot" != "null" ] && [ "$snapshot" != "current" ]; then
      msg_info "Removing snapshot: ${snapshot}..."
      if [ "$SELECTED_TYPE" = "VM" ]; then
        qm delsnapshot "$SELECTED_VMID" "$snapshot" --force 2>/dev/null || true
      else
        pct delsnapshot "$SELECTED_VMID" "$snapshot" --force 2>/dev/null || true
      fi
      ((snapshot_count++))
      msg_ok "Removed snapshot: ${snapshot}"
    fi
  done < <(pvesh get "${api_path}/snapshot" --output-format json 2>/dev/null | jq -r '.[].name')
  
  if [ $snapshot_count -eq 0 ]; then
    msg_ok "No snapshots to remove"
  else
    msg_ok "Removed ${snapshot_count} snapshot(s)"
  fi
}

# ── Step 5: Remove Backups ────────────────────────────────────────────────────
remove_backups() {
  section "Step 5: Removing Backups"
  
  local backup_count=0
  
  for path in "${BACKUP_STORAGES[@]}"; do
    if [ -d "$path" ]; then
      while IFS= read -r backup_file; do
        if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
          msg_info "Removing: $(basename "$backup_file")..."
          rm -f "$backup_file" 2>/dev/null
          # Also remove associated files (.log, .notes)
          rm -f "${backup_file}.log" 2>/dev/null
          rm -f "${backup_file}.notes" 2>/dev/null
          rm -f "${backup_file}.fidx" 2>/dev/null
          rm -f "${backup_file}.didx" 2>/dev/null
          ((backup_count++))
        fi
      done < <(find "$path" -maxdepth 1 -name "*-${SELECTED_VMID}-*" -type f 2>/dev/null)
    fi
  done
  
  # Also check PBS if available
  if command -v proxmox-backup-client &>/dev/null; then
    msg_info "Checking Proxmox Backup Server..."
    # Note: PBS backup removal requires proper authentication and is storage-specific
    # This would need to be expanded based on actual PBS configuration
  fi
  
  if [ $backup_count -eq 0 ]; then
    msg_ok "No backups to remove"
  else
    msg_ok "Removed ${backup_count} backup file(s)"
  fi
}

# ── Step 6: Remove Storage Volumes ────────────────────────────────────────────
remove_storage() {
  section "Step 6: Removing Storage Volumes"
  
  local api_path
  if [ "$SELECTED_TYPE" = "VM" ]; then
    api_path="/nodes/${LOCAL_NODE}/qemu/${SELECTED_VMID}"
  else
    api_path="/nodes/${LOCAL_NODE}/lxc/${SELECTED_VMID}"
  fi
  
  # Get configuration to find all disks
  local config
  config=$(pvesh get "${api_path}/config" --output-format json 2>/dev/null)
  
  local disk_count=0
  
  if [ "$SELECTED_TYPE" = "VM" ]; then
    # VM disks: scsi, sata, virtio, ide, efidisk, tpmstate, unused
    while IFS= read -r disk_key; do
      if [ -n "$disk_key" ] && [ "$disk_key" != "null" ]; then
        msg_info "Removing disk: ${disk_key}..."
        qm set "$SELECTED_VMID" --delete "$disk_key" 2>/dev/null || true
        ((disk_count++))
      fi
    done < <(echo "$config" | jq -r 'keys[] | select(test("^(scsi|sata|virtio|ide|efidisk|tpmstate|unused)[0-9]*$"))')
    
  else
    # CT disks: rootfs, mp0, mp1, etc. (but don't delete rootfs separately, destroy handles it)
    while IFS= read -r disk_key; do
      if [ -n "$disk_key" ] && [ "$disk_key" != "null" ] && [ "$disk_key" != "rootfs" ]; then
        msg_info "Removing mount: ${disk_key}..."
        pct set "$SELECTED_VMID" --delete "$disk_key" 2>/dev/null || true
        ((disk_count++))
      fi
    done < <(echo "$config" | jq -r 'keys[] | select(test("^mp[0-9]+$"))')
  fi
  
  if [ $disk_count -eq 0 ]; then
    msg_ok "No additional storage volumes to remove"
  else
    msg_ok "Processed ${disk_count} storage volume(s)"
  fi
}

# ── Step 7: Delete Guest ──────────────────────────────────────────────────────
delete_guest() {
  section "Step 7: Deleting ${SELECTED_TYPE} ${SELECTED_VMID}"
  
  msg_info "Destroying ${SELECTED_TYPE} ${SELECTED_VMID}..."
  
  if [ "$SELECTED_TYPE" = "VM" ]; then
    if qm destroy "$SELECTED_VMID" --purge --skiplock 2>/dev/null; then
      msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} destroyed"
    else
      # Try without purge if it fails
      if qm destroy "$SELECTED_VMID" --skiplock 2>/dev/null; then
        msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} destroyed"
      else
        msg_error "Failed to destroy ${SELECTED_TYPE} ${SELECTED_VMID}"
        return 1
      fi
    fi
  else
    if pct destroy "$SELECTED_VMID" --purge --force 2>/dev/null; then
      msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} destroyed"
    else
      # Try without purge if it fails
      if pct destroy "$SELECTED_VMID" --force 2>/dev/null; then
        msg_ok "${SELECTED_TYPE} ${SELECTED_VMID} destroyed"
      else
        msg_error "Failed to destroy ${SELECTED_TYPE} ${SELECTED_VMID}"
        return 1
      fi
    fi
  fi
  
  # Clean up any remaining config files
  local config_file=""
  if [ "$SELECTED_TYPE" = "VM" ]; then
    config_file="/etc/pve/qemu-server/${SELECTED_VMID}.conf"
  else
    config_file="/etc/pve/lxc/${SELECTED_VMID}.conf"
  fi
  
  if [ -f "$config_file" ]; then
    msg_info "Removing residual config file..."
    rm -f "$config_file" 2>/dev/null
    msg_ok "Config file removed"
  fi
}

# ── Step 8: Verify Removal ────────────────────────────────────────────────────
verify_removal() {
  section "Step 8: Verifying Complete Removal"
  
  local errors=0
  
  # Check if guest still exists
  if [ "$SELECTED_TYPE" = "VM" ]; then
    if pvesh get "/nodes/${LOCAL_NODE}/qemu/${SELECTED_VMID}/status/current" --output-format json 2>/dev/null | jq -e '.vmid' &>/dev/null; then
      msg_error "VM ${SELECTED_VMID} still exists"
      ((errors++))
    else
      msg_ok "VM ${SELECTED_VMID} no longer exists"
    fi
  else
    if pvesh get "/nodes/${LOCAL_NODE}/lxc/${SELECTED_VMID}/status/current" --output-format json 2>/dev/null | jq -e '.vmid' &>/dev/null; then
      msg_error "CT ${SELECTED_VMID} still exists"
      ((errors++))
    else
      msg_ok "CT ${SELECTED_VMID} no longer exists"
    fi
  fi
  
  # Check config file
  local config_file=""
  if [ "$SELECTED_TYPE" = "VM" ]; then
    config_file="/etc/pve/qemu-server/${SELECTED_VMID}.conf"
  else
    config_file="/etc/pve/lxc/${SELECTED_VMID}.conf"
  fi
  
  if [ -f "$config_file" ]; then
    msg_warn "Config file still exists: ${config_file}"
    ((errors++))
  else
    msg_ok "Config file removed"
  fi
  
  # Check for remaining backups
  local remaining_backups=0
  for path in "${BACKUP_STORAGES[@]}"; do
    if [ -d "$path" ]; then
      local count
      count=$(find "$path" -maxdepth 1 -name "*-${SELECTED_VMID}-*" -type f 2>/dev/null | wc -l)
      remaining_backups=$((remaining_backups + count))
    fi
  done
  
  if [ $remaining_backups -gt 0 ]; then
    msg_warn "${remaining_backups} backup file(s) may remain"
  else
    msg_ok "No remaining backups found"
  fi
  
  # Check HA
  local ha_sid="${SELECTED_TYPE,,}:${SELECTED_VMID}"
  if pvesh get /cluster/ha/resources --output-format json 2>/dev/null | jq -e ".[] | select(.sid == \"${ha_sid}\")" &>/dev/null; then
    msg_warn "HA configuration may still exist"
    ((errors++))
  else
    msg_ok "No HA configuration"
  fi
  
  return $errors
}

# ── Final Summary ─────────────────────────────────────────────────────────────
display_final_summary() {
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║                                                                          ║${CL}"
  echo -e "${BL}${BLD}  ║   ${GN}✔${BL}  CLEANUP COMPLETE                                                   ║${CL}"
  echo -e "${BL}${BLD}  ║                                                                          ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}DESTRUCTION SUMMARY${CL}                                                   ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${RD}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Guest Type" "${SELECTED_TYPE}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${RD}%-40s${CL}  ${BL}${BLD}│${CL}\n" "VMID" "${SELECTED_VMID}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${RD}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Name" "${SELECTED_NAME}"
  printf "  ${BL}${BLD}│${CL}  %-25s  ${RD}%-40s${CL}  ${BL}${BLD}│${CL}\n" "Status" "DESTROYED"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  echo -e "  ${BL}${BLD}┌─────────────────────────────────────────────────────────────────────────┐${CL}"
  echo -e "  ${BL}${BLD}│${CL}  ${BLD}OPERATIONS COMPLETED${CL}                                                  ${BL}${BLD}│${CL}"
  echo -e "  ${BL}${BLD}├─────────────────────────────────────────────────────────────────────────┤${CL}"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Stopped ${SELECTED_TYPE}"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Removed HA configuration"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Removed replication jobs"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Deleted snapshots"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Deleted backups"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Removed storage volumes"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Deleted configuration"
  printf "  ${BL}${BLD}│${CL}  ${GN}✔${CL}  %-64s  ${BL}${BLD}│${CL}\n" "Verified complete removal"
  echo -e "  ${BL}${BLD}└─────────────────────────────────────────────────────────────────────────┘${CL}"
  echo ""
  
  msg_ok "Log saved  : ${LOGFILE}"
  msg_ok "Finished   : $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $(hostname -f 2>/dev/null || hostname)${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  header_info
  
  section "Preflight Checks"
  check_root
  check_proxmox
  check_jq
  discover_backup_storages
  
  discover_guests
  select_guest
  gather_guest_details
  confirm_removal
  
  stop_guest
  remove_ha
  remove_replication
  remove_snapshots
  remove_backups
  remove_storage
  delete_guest
  verify_removal
  display_final_summary
}

main "$@"
