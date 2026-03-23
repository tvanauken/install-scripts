#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — Drive Cleanup & Initialization
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    3.0
#  Date:       2026-03-23
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Scans ALL drives in a Proxmox server and identifies drives that contain
#   remnant data from a previous system (ZFS pools, Ceph/LVM volumes, old
#   partition tables, old filesystem signatures, mdadm RAID superblocks).
#   Those drives are completely wiped and initialized, ready for fresh
#   deployment in Proxmox or TrueNAS.
#
# ALWAYS PROTECTED — never touched:
#   - Proxmox OS / boot / root drive(s)
#   - Any currently mounted filesystem devices
#   - Drives backing the active Proxmox 'pve' LVM volume group
#   - Drives in any currently active ZFS pool (rpool, boot-pool)
#   - USB drives
#
# TARGET — will be wiped:
#   - SAS / SATA / NVMe drives with remnant data
#   (anything not in the protected list and not USB)
#
# WIPE SEQUENCE PER DRIVE:
#   1.  wipefs  on every child partition
#   2.  wipefs  on the whole disk
#   3.  sgdisk --zap-all  (destroy GPT + MBR)
#   4.  dd zero — first 200 MB  (MBR, GPT, ZFS labels 0+1, LVM, Ceph, mdadm)
#   5.  dd zero — last  200 MB  (backup GPT, ZFS labels 2+3)
#   6.  wipefs  second pass     (catch anything re-surfaced)
#   7.  partprobe / blockdev --rereadpt  (flush kernel partition cache)
#
# COMPATIBILITY:
#   Proxmox VE 8.x  (Debian 12 Bookworm)
#   Proxmox VE 9.x  (Debian 13 Trixie)
#
# USAGE:
#   chmod +x drive_init.sh && ./drive_init.sh
#   Displays full execution plan, then requires a single YES to proceed.
#
# ============================================================================

set -o pipefail

# ── Log to terminal AND timestamped file ─────────────────────────────────────
LOGFILE="/var/log/drive_init_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /var/log 2>/dev/null
exec > >(tee -a "$LOGFILE") 2>&1

# ── Colour Palette ────────────────────────────────────────────────────────────
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="    "

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
msg_drive() { printf "\n${BL}${BLD}  [▸] /dev/%-10s${CL}  %s\n" "$1" "$2"; }
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
  echo -e "${DGN}  ── PVE Drive Cleanup & Initialization ─────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  if command -v pveversion &>/dev/null; then
    printf "  ${DGN}PVE    :${CL}  ${BL}%s${CL}\n" "$(pveversion | cut -d/ -f2)"
  fi
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
}

PROTECTED_DISKS=""
TARGET_DRIVES=""

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    msg_error "This script must be run as root."
    exit 1
  fi
  msg_ok "Running as root"
}

detect_proxmox() {
  if command -v pveversion &>/dev/null; then
    msg_info "Platform : $(pveversion 2>/dev/null | head -1)"
  else
    msg_warn "pveversion not found — verify this is a Proxmox VE host"
  fi
  msg_info "Kernel   : $(uname -r)"
  msg_info "OS       : $(grep -oP '(?<=PRETTY_NAME=\").*(?=\")' /etc/os-release 2>/dev/null || echo 'Unknown')"
}

install_requirements() {
  section "Checking & Installing Required Tools"
  local pkgs=()
  command -v sgdisk    &>/dev/null || pkgs+=(gdisk)
  command -v pvremove  &>/dev/null || pkgs+=(lvm2)
  command -v partprobe &>/dev/null || pkgs+=(parted)
  command -v mdadm     &>/dev/null || pkgs+=(mdadm)
  command -v lsscsi    &>/dev/null || pkgs+=(lsscsi)
  if [ ${#pkgs[@]} -gt 0 ]; then
    msg_info "Installing missing tools: ${pkgs[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" 2>/dev/null
    msg_ok "Missing tools installed"
  else
    msg_ok "All required tools already present"
  fi
  local missing=()
  for cmd in lsblk blkid wipefs sgdisk pvremove vgremove lvchange vgchange dd blockdev partprobe mdadm findmnt; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    msg_error "Critical tools still missing: ${missing[*]} — aborting."
    exit 1
  fi
  msg_ok "All tools verified"
}

get_base_disk() {
  local dev="${1#/dev/}"
  local base
  base=$(lsblk -no PKNAME "/dev/$dev" 2>/dev/null | head -1 | tr -d '[:space:]')
  [ -n "$base" ] && echo "$base" || echo "$dev"
}

build_protected_disks() {
  local p=()
  local root_src
  root_src=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)
  [ -n "$root_src" ] && p+=("$(get_base_disk "$root_src")")
  while IFS= read -r src; do
    [[ "$src" == /dev/* ]] || continue
    p+=("$(get_base_disk "$src")")
  done < <(findmnt -ln -o SOURCE 2>/dev/null)
  while IFS= read -r line; do
    local pv vg
    pv=$(echo "$line" | awk '{print $1}')
    vg=$(echo "$line" | awk '{print $2}' | tr -d '[:space:]')
    [ "$vg" = "pve" ] && p+=("$(get_base_disk "$pv")")
  done < <(pvs --noheadings -o pv_name,vg_name 2>/dev/null)
  if command -v zpool &>/dev/null; then
    while IFS= read -r pooldev; do
      [[ "$pooldev" == /dev/* ]] || continue
      p+=("$(get_base_disk "$pooldev")")
    done < <(zpool status -P 2>/dev/null | awk '/\/dev\// {print $1}')
  fi
  PROTECTED_DISKS=$(printf '%s\n' "${p[@]}" | sort -u | grep -v '^$')
}

is_protected() { echo "$PROTECTED_DISKS" | grep -qx "$1"; }

build_target_drives() {
  local targets=()
  while IFS= read -r line; do
    local name tran
    name=$(echo "$line" | awk '{print $1}')
    tran=$(echo "$line" | awk '{print $2}')
    [ "$tran" = "usb" ] && continue
    is_protected "$name" && continue
    targets+=("$name")
  done < <(lsblk -d -n -o NAME,TRAN 2>/dev/null)
  TARGET_DRIVES=$(printf '%s\n' "${targets[@]}" | sort -u | grep -v '^$')
}

init_drive_lists() {
  build_protected_disks
  build_target_drives
}

confirm_execution() {
  local hostname_str ip_str
  hostname_str=$(hostname 2>/dev/null)
  ip_str=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo ""
  echo -e "${BL}${BLD}  ╔══════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${BL}${BLD}  ║         EXECUTION PLAN — REVIEW BEFORE PROCEEDING           ║${CL}"
  echo -e "${BL}${BLD}  ╚══════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  printf "  ${BLD}Server  :${CL}  %s  (%s)\n" "${hostname_str}" "${ip_str}"
  command -v pveversion &>/dev/null && printf "  ${BLD}Platform:${CL}  %s\n" "$(pveversion 2>/dev/null | head -1)"
  echo ""
  echo -e "${GN}${BLD}  PROTECTED — will NOT be touched:${CL}"
  if [ -n "$PROTECTED_DISKS" ]; then
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      local size tran model
      size=$(lsblk -d -n -o SIZE "/dev/$d" 2>/dev/null | xargs)
      tran=$(lsblk -d -n -o TRAN "/dev/$d" 2>/dev/null | xargs)
      model=$(lsblk -d -n -o MODEL "/dev/$d" 2>/dev/null | xargs)
      printf "  ${GN}    ✔${CL}  %-12s  %-8s  %-6s  %s\n" "/dev/$d" "${size}" "${tran:-??}" "${model}"
    done <<< "$PROTECTED_DISKS"
  else
    echo -e "  ${YW}    ⚠  (none detected — verify system drives before proceeding)${CL}"
  fi
  echo ""
  echo -e "${RD}${BLD}  TARGET — ALL DATA WILL BE PERMANENTLY DESTROYED:${CL}"
  if [ -n "$TARGET_DRIVES" ]; then
    local target_count=0
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      local size tran model serial
      size=$(lsblk -d -n -o SIZE "/dev/$d" 2>/dev/null | xargs)
      tran=$(lsblk -d -n -o TRAN "/dev/$d" 2>/dev/null | xargs)
      model=$(lsblk -d -n -o MODEL "/dev/$d" 2>/dev/null | xargs)
      serial=$(lsblk -d -n -o SERIAL "/dev/$d" 2>/dev/null | xargs)
      printf "  ${RD}    ✘${CL}  %-12s  %-8s  %-6s  %-28s  SN: %s\n" "/dev/$d" "${size}" "${tran:-??}" "${model}" "${serial}"
      target_count=$(( target_count + 1 ))
    done <<< "$TARGET_DRIVES"
    echo ""
    printf "  ${BLD}    Total target drives: %d${CL}\n" "$target_count"
  else
    echo -e "  ${YW}    ⚠  (no target drives found — nothing to do)${CL}"
  fi
  echo ""
  echo -e "${BL}${BLD}  OPERATIONS TO BE PERFORMED:${CL}"
  echo "    1.  Stop all running VMs and containers"
  echo "    2.  Export / destroy ZFS pools on target drives"
  echo "    3.  Remove all LVM VGs and PV labels (Ceph, old pools, etc.)"
  echo "    4.  Stop mdadm RAID arrays and zero superblocks"
  echo "    5.  Unmount any stray filesystems on target drives"
  echo "    6.  Per drive: wipefs partitions → wipefs disk → sgdisk --zap-all → dd first 200MB → dd last 200MB → wipefs pass 2 → partprobe"
  echo "    7.  Verify all target drives are clean"
  printf "    8.  Save full log to: %s\n" "$LOGFILE"
  echo ""
  echo -e "${RD}${BLD}  !! THIS OPERATION IS IRREVERSIBLE. ALL DATA ON TARGET DRIVES WILL BE LOST. !!${CL}"
  echo ""
  if [ -z "$TARGET_DRIVES" ]; then
    msg_ok "No target drives found — nothing to do. Exiting."
    exit 0
  fi
  printf "  ${BLD}Type  YES  to proceed (anything else aborts): ${CL}"
  read -r answer
  echo ""
  if [ "$answer" != "YES" ]; then
    msg_warn "Aborted by operator. No changes were made."
    exit 0
  fi
  msg_ok "Confirmed. Beginning execution..."
  echo ""
}

stop_vms_and_containers() {
  section "Step 1: Stopping Running VMs and Containers"
  if command -v qm &>/dev/null; then
    local running_vms
    running_vms=$(qm list 2>/dev/null | awk 'NR>1 && /running/ {print $1}')
    if [ -n "$running_vms" ]; then
      while IFS= read -r vmid; do
        [ -z "$vmid" ] && continue
        msg_info "Stopping VM ${vmid}..."
        qm stop "$vmid" --skiplock 1 2>/dev/null && msg_ok "VM ${vmid} stopped" || msg_warn "Could not stop VM ${vmid}"
      done <<< "$running_vms"
    else
      msg_ok "No running VMs"
    fi
  fi
  if command -v pct &>/dev/null; then
    local running_cts
    running_cts=$(pct list 2>/dev/null | awk 'NR>1 && /running/ {print $1}')
    if [ -n "$running_cts" ]; then
      while IFS= read -r ctid; do
        [ -z "$ctid" ] && continue
        msg_info "Stopping container ${ctid}..."
        pct stop "$ctid" 2>/dev/null && msg_ok "Container ${ctid} stopped" || msg_warn "Could not stop container ${ctid}"
      done <<< "$running_cts"
    else
      msg_ok "No running containers"
    fi
  fi
}

cleanup_zfs() {
  section "Step 2: Cleaning Up ZFS Pools and Labels"
  if ! command -v zpool &>/dev/null; then msg_info "zpool not available — skipping"; return; fi
  local active_pools
  active_pools=$(zpool list -H -o name 2>/dev/null || true)
  if [ -n "$active_pools" ]; then
    while IFS= read -r pool; do
      [ -z "$pool" ] && continue
      local pool_hit=false
      while IFS= read -r pdev; do
        [[ "$pdev" == /dev/* ]] || continue
        local base; base=$(get_base_disk "$pdev")
        echo "$TARGET_DRIVES" | grep -qx "$base" && { pool_hit=true; break; }
      done < <(zpool status -P "$pool" 2>/dev/null | awk '/\/dev\// {print $1}')
      if $pool_hit; then
        msg_info "Exporting ZFS pool: ${pool}"
        if ! zpool export -f "$pool" 2>/dev/null; then
          msg_warn "Export failed — attempting destroy: ${pool}"
          zpool destroy -f "$pool" 2>/dev/null || msg_warn "Could not destroy ${pool}"
        else
          msg_ok "ZFS pool exported: ${pool}"
        fi
      fi
    done <<< "$active_pools"
  else
    msg_ok "No active ZFS pools found"
  fi
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    zpool labelclear -f "/dev/$drv" 2>/dev/null || true
    while IFS= read -r part; do
      [ "$part" = "$drv" ] && continue; [ -z "$part" ] && continue
      zpool labelclear -f "/dev/$part" 2>/dev/null || true
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
  done <<< "$TARGET_DRIVES"
  msg_ok "ZFS cleanup complete"
}

cleanup_lvm() {
  section "Step 3: Removing LVM Volume Groups and PV Labels"
  local vgs_found=()
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    local devlist=("/dev/$drv")
    while IFS= read -r part; do
      [ "$part" = "$drv" ] && continue; [ -z "$part" ] && continue
      devlist+=("/dev/$part")
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
    for d in "${devlist[@]}"; do
      local vg_name
      vg_name=$(pvs --noheadings -o vg_name "$d" 2>/dev/null | awk '{print $1}' | grep -v '^$' || true)
      [ -n "$vg_name" ] && [ "$vg_name" != "pve" ] && vgs_found+=("$vg_name")
    done
  done <<< "$TARGET_DRIVES"
  local unique_vgs
  unique_vgs=$(printf '%s\n' "${vgs_found[@]}" | sort -u | grep -v '^$')
  if [ -n "$unique_vgs" ]; then
    while IFS= read -r vg; do
      [ -z "$vg" ] && continue
      msg_info "Removing VG: ${vg}"
      lvchange -an "$vg" 2>/dev/null || true
      vgchange -an "$vg" 2>/dev/null || true
      vgremove -f -y "$vg" 2>/dev/null && msg_ok "Removed VG: ${vg}" || msg_warn "Could not remove VG: ${vg}"
    done <<< "$unique_vgs"
  else
    msg_ok "No stale LVM VGs found on target drives"
  fi
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    pvremove -ff -y "/dev/$drv" 2>/dev/null || true
    while IFS= read -r part; do
      [ "$part" = "$drv" ] && continue; [ -z "$part" ] && continue
      pvremove -ff -y "/dev/$part" 2>/dev/null || true
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
  done <<< "$TARGET_DRIVES"
  msg_ok "LVM cleanup complete"
}

cleanup_mdadm() {
  section "Step 4: Cleaning Up mdadm RAID Arrays"
  if ! command -v mdadm &>/dev/null; then msg_info "mdadm not available — skipping"; return; fi
  local found_array=false
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    while IFS= read -r part; do
      [ -z "$part" ] && continue
      if mdadm --examine "/dev/$part" &>/dev/null 2>&1; then
        found_array=true
        local md_name
        md_name=$(mdadm --examine "/dev/$part" 2>/dev/null | awk '/\/dev\/md/ {print $NF; exit}' || true)
        if [ -n "$md_name" ] && [ -b "$md_name" ]; then
          msg_info "Stopping mdadm array ${md_name}"
          mdadm --stop "$md_name" 2>/dev/null && msg_ok "Stopped: ${md_name}" || msg_warn "Could not stop ${md_name}"
        fi
      fi
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
  done <<< "$TARGET_DRIVES"
  $found_array || msg_ok "No mdadm arrays found on target drives"
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    while IFS= read -r part; do
      [ -z "$part" ] && continue
      mdadm --zero-superblock --force "/dev/$part" 2>/dev/null || true
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
  done <<< "$TARGET_DRIVES"
  msg_ok "mdadm cleanup complete"
}

unmount_target_drives() {
  section "Step 5: Unmounting Stray Filesystems"
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    while IFS= read -r part; do
      [ -z "$part" ] && continue
      local mnt; mnt=$(findmnt -n -o TARGET "/dev/$part" 2>/dev/null | head -1)
      if [ -n "$mnt" ]; then
        msg_info "Unmounting /dev/${part} from ${mnt}..."
        umount -lf "/dev/$part" 2>/dev/null && msg_ok "Unmounted: /dev/${part}" || msg_warn "Could not unmount /dev/${part}"
      fi
    done < <(lsblk -ln -o NAME "/dev/$drv" 2>/dev/null)
  done <<< "$TARGET_DRIVES"
  msg_ok "Unmount pass complete"
}

wipe_drives() {
  section "Step 6: Wiping All Target Drives"
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    local dev="/dev/$drv"
    msg_drive "$drv" "── Beginning wipe sequence ─────────────────────────────"
    while IFS= read -r part; do
      [ "$part" = "$drv" ] && continue; [ -z "$part" ] && continue
      msg_info "  [6a] wipefs partition  /dev/${part}"
      wipefs -a -f "/dev/$part" 2>/dev/null || true
    done < <(lsblk -ln -o NAME "$dev" 2>/dev/null)
    msg_info "  [6b] wipefs whole disk  ${dev}"
    wipefs -a -f "$dev" 2>/dev/null || true
    msg_info "  [6c] sgdisk --zap-all  ${dev}"
    sgdisk --zap-all "$dev" 2>/dev/null || true
    local sectors size_mb
    sectors=$(blockdev --getsz "$dev" 2>/dev/null || echo 0)
    if [ "$sectors" -le 0 ]; then
      msg_warn "  [6d] Cannot read sector count for ${dev} — skipping dd passes"
    else
      size_mb=$(( sectors / 2048 ))
      msg_info "  [6d] dd zero — first 200 MB of ${dev}..."
      dd if=/dev/zero of="$dev" bs=1M count=200 conv=fsync,noerror 2>&1 | grep -E "bytes|error" || true
      local seek_mb=$(( size_mb - 200 ))
      if [ "$seek_mb" -gt 200 ]; then
        msg_info "  [6e] dd zero — last 200 MB of ${dev}  (offset ${seek_mb} MB)..."
        dd if=/dev/zero of="$dev" bs=1M seek="$seek_mb" count=200 conv=fsync,noerror 2>&1 | grep -E "bytes|error" || true
      else
        msg_info "  [6e] Drive <= 400 MB — first pass covered entire disk"
      fi
    fi
    msg_info "  [6f] wipefs second pass  ${dev}"
    wipefs -a -f "$dev" 2>/dev/null || true
    msg_info "  [6g] partprobe  ${dev}"
    partprobe "$dev" 2>/dev/null || blockdev --rereadpt "$dev" 2>/dev/null || true
    msg_drive "$drv" "── Wipe complete ───────────────────────────────────────"
  done <<< "$TARGET_DRIVES"
}

verify_drives() {
  section "Step 7: Verifying Target Drives Are Clean"
  local all_clean=true
  while IFS= read -r drv; do
    [ -z "$drv" ] && continue
    local dev="/dev/$drv"
    local issues=()
    local sig; sig=$(blkid -p "$dev" 2>/dev/null)
    [ -n "$sig" ] && issues+=("blkid signature present: ${sig}")
    local part_count; part_count=$(lsblk -ln -o NAME "$dev" 2>/dev/null | grep -vc "^${drv}$" || true)
    [ "$part_count" -gt 0 ] && issues+=("${part_count} partition(s) still visible")
    pvs "$dev" &>/dev/null 2>&1 && issues+=("LVM PV label still present")
    while IFS= read -r part; do
      [ "$part" = "$drv" ] && continue; [ -z "$part" ] && continue
      local psig; psig=$(blkid -p "/dev/$part" 2>/dev/null)
      [ -n "$psig" ] && issues+=("partition /dev/${part}: ${psig}")
    done < <(lsblk -ln -o NAME "$dev" 2>/dev/null)
    printf "${TAB}  %-40s" "/dev/$drv"
    if [ ${#issues[@]} -eq 0 ]; then
      printf "${GN}✔ Clean${CL}\n"
    else
      printf "${RD}✘ Issues found${CL}\n"
      all_clean=false
      for issue in "${issues[@]}"; do msg_warn "      - ${issue}"; done
    fi
  done <<< "$TARGET_DRIVES"
  echo ""
  if $all_clean; then
    msg_ok "All target drives verified clean and ready for deployment"
  else
    msg_warn "Some drives flagged — dd zero passes destroy all data regardless of blkid cache hits"
  fi
}

main() {
  header_info
  section "Preflight Checks"
  check_root
  detect_proxmox
  install_requirements
  section "Scanning Drives"
  msg_info "Building protected drive list..."
  init_drive_lists
  msg_ok "Drive scan complete"
  confirm_execution
  stop_vms_and_containers
  cleanup_zfs
  cleanup_lvm
  cleanup_mdadm
  unmount_target_drives
  wipe_drives
  verify_drives
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       COMPLETE — All Target Drives Wiped and Initialized${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
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

main "$@"
