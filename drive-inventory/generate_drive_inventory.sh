#!/usr/bin/env bash
# ============================================================================
#  Proxmox VE — Drive Inventory Report Generator
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    3.0
#  Date:       2026-03-23
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Scans all storage devices on a Proxmox VE server, collects detailed
#   hardware information, and generates a comprehensive markdown inventory
#   report. Covers NVMe, SAS, SATA, and USB devices.
#
# OUTPUT:
#   - Live colourised terminal progress while scanning
#   - Markdown report saved to the directory where the script is executed
#
# USAGE:
#   chmod +x generate_drive_inventory.sh && ./generate_drive_inventory.sh
#
# ============================================================================

set -o pipefail

RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
DGN="\033[32m"
BL="\033[36m"
CL="\033[m"
BLD="\033[1m"
TAB="    "

cleanup() {
  local code=$?
  tput cnorm 2>/dev/null || true
  [[ $code -ne 0 ]] && echo -e "\n${RD}  Script interrupted (exit ${code})${CL}\n"
}
trap cleanup EXIT

msg_info()  { printf "${TAB}${BL}◆  %s${CL}\n" "$1"; }
msg_ok()    { printf "${TAB}${GN}✔  %s${CL}\n" "$1"; }
msg_warn()  { printf "${TAB}${YW}⚠  %s${CL}\n" "$1"; }
msg_error() { printf "${TAB}${RD}✘  %s${CL}\n" "$1"; }
section()   { printf "\n${BL}${BLD}  ── %s ──────────────────────────────────────────${CL}\n\n" "$1"; }

HOSTNAME_SHORT=$(hostname 2>/dev/null)
FQDN=$(hostname -f 2>/dev/null || echo "$HOSTNAME_SHORT")
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}')
OUTPUT_FILE="./drive_inventory_${HOSTNAME_SHORT}_$(date +%Y%m%d_%H%M%S).md"
LOGFILE="/var/log/drive_inventory_$(date +%Y%m%d_%H%M%S).log"

TOTAL_DRIVES=0
SATA_COUNT=0; SAS_COUNT=0; NVME_COUNT=0; USB_COUNT=0; OTHER_COUNT=0
SATA_CAP=0;   SAS_CAP=0;   NVME_CAP=0;   USB_CAP=0;   OTHER_CAP=0
TOTAL_BYTES=0

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
  echo -e "${DGN}  ── Drive Inventory Report Generator ───────────────────────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$FQDN"
  printf "  ${DGN}IP     :${CL}  ${BL}%s${CL}\n" "$IP_ADDRESS"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$TIMESTAMP"
  command -v pveversion &>/dev/null && printf "  ${DGN}PVE    :${CL}  ${BL}%s${CL}\n" "$(pveversion | cut -d/ -f2)"
  printf "  ${DGN}Report :${CL}  ${BL}%s${CL}\n" "$OUTPUT_FILE"
  echo ""
}

preflight() {
  section "Preflight Checks"
  if [[ $EUID -ne 0 ]]; then msg_error "Must be run as root"; exit 1; fi
  msg_ok "Running as root"
  local pkgs=()
  command -v smartctl &>/dev/null || pkgs+=(smartmontools)
  command -v bc       &>/dev/null || pkgs+=(bc)
  command -v lspci    &>/dev/null || pkgs+=(pciutils)
  command -v lsscsi   &>/dev/null || pkgs+=(lsscsi)
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    msg_info "Installing missing tools: ${pkgs[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq >> "$LOGFILE" 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" >> "$LOGFILE" 2>&1
    msg_ok "Tools installed"
  else
    msg_ok "All required tools present"
  fi
  local missing=()
  for cmd in smartctl bc lspci lsblk; do command -v "$cmd" &>/dev/null || missing+=("$cmd"); done
  if [[ ${#missing[@]} -gt 0 ]]; then msg_error "Still missing: ${missing[*]}"; exit 1; fi
  msg_ok "All tools verified"
}

gather_system_info() {
  section "System Information"
  OS_NAME="Unknown"
  [[ -f /etc/os-release ]] && { . /etc/os-release; OS_NAME="$PRETTY_NAME"; }
  msg_info "OS       : $OS_NAME"
  PVE_VERSION="N/A"
  if command -v pveversion &>/dev/null; then
    PVE_VERSION=$(pveversion 2>/dev/null | head -1)
  elif [[ -f /etc/pve/.version ]]; then
    PVE_VERSION="PVE $(cat /etc/pve/.version)"
  fi
  msg_info "PVE      : $PVE_VERSION"
  msg_info "Kernel   : $(uname -r)"
  msg_info "Detecting storage controllers..."
  SATA_CONTROLLERS=$(lspci 2>/dev/null | grep -iE  "SATA|AHCI"                     | wc -l | tr -d ' ')
  SAS_CONTROLLERS=$(lspci  2>/dev/null | grep -iE  "SAS|LSI|Broadcom.*HBA"          | wc -l | tr -d ' ')
  NVME_CONTROLLERS=$(lspci 2>/dev/null | grep -i   "Non-Volatile memory controller" | wc -l | tr -d ' ')
  msg_ok "Controllers — SATA/AHCI: ${SATA_CONTROLLERS}  SAS/HBA: ${SAS_CONTROLLERS}  NVMe: ${NVME_CONTROLLERS}"
}

scan_drives() {
  section "Scanning Drives"
  ALL_DRIVES=$(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' | sort)
  if [[ -z "$ALL_DRIVES" ]]; then msg_error "No block devices detected"; exit 1; fi
  printf "  ${BL}${BLD}%-14s  %-32s  %-8s  %-6s  %-10s  %s${CL}\n" "Device" "Model" "Size" "Type" "Media" "Serial"
  printf "  ${DGN}%-14s  %-32s  %-8s  %-6s  %-10s  %s${CL}\n" \
    "──────────────" "────────────────────────────────" "────────" "──────" "──────────" "──────────────────────"
  for drive in $ALL_DRIVES; do
    local dev="/dev/$drive" size tran model serial media rpm_info
    size=$(lsblk   -d -n -o SIZE   "$dev" 2>/dev/null | xargs)
    tran=$(lsblk   -d -n -o TRAN   "$dev" 2>/dev/null | xargs)
    model=$(lsblk  -d -n -o MODEL  "$dev" 2>/dev/null | xargs)
    serial=$(lsblk -d -n -o SERIAL "$dev" 2>/dev/null | xargs)
    [[ -z "$model"  ]] && model="Unknown"
    [[ -z "$tran"   ]] && tran="??"
    [[ -z "$serial" ]] && serial="N/A"
    media="Unknown"; rpm_info="N/A"
    if [[ "$tran" = "nvme" ]]; then
      media="NVMe SSD"; rpm_info="NVMe"
    elif smartctl -i "$dev" &>/dev/null 2>&1; then
      local rotation
      rotation=$(smartctl -i "$dev" 2>/dev/null | grep "Rotation Rate" | cut -d: -f2 | xargs)
      if echo "$rotation" | grep -qi "Solid State"; then
        media="SSD"; rpm_info="SSD"
      elif echo "$rotation" | grep -qE "[0-9]+ rpm"; then
        media="HDD"; rpm_info="$rotation"
      elif [[ "$tran" = "sas" ]]; then
        local rpm; rpm=$(smartctl -a "$dev" 2>/dev/null | grep -i "rpm" | head -1 | grep -oE "[0-9]+" | head -1)
        [[ -n "$rpm" ]] && { media="HDD"; rpm_info="${rpm} rpm"; }
      fi
    fi
    local size_bytes; size_bytes=$(lsblk -b -d -n -o SIZE "$dev" 2>/dev/null || echo 0)
    TOTAL_BYTES=$(( TOTAL_BYTES + size_bytes ))
    TOTAL_DRIVES=$(( TOTAL_DRIVES + 1 ))
    case "$tran" in
      sata) SATA_COUNT=$(( SATA_COUNT+1 )); SATA_CAP=$(( SATA_CAP+size_bytes )) ;;
      sas)  SAS_COUNT=$(( SAS_COUNT+1 ));   SAS_CAP=$(( SAS_CAP+size_bytes ))   ;;
      nvme) NVME_COUNT=$(( NVME_COUNT+1 )); NVME_CAP=$(( NVME_CAP+size_bytes )) ;;
      usb)  USB_COUNT=$(( USB_COUNT+1 ));   USB_CAP=$(( USB_CAP+size_bytes ))   ;;
      *)    OTHER_COUNT=$(( OTHER_COUNT+1 )); OTHER_CAP=$(( OTHER_CAP+size_bytes )) ;;
    esac
    local tran_color="$CL"
    case "$tran" in nvme) tran_color="$GN";; sas) tran_color="$YW";; sata) tran_color="$BL";; usb) tran_color="$DGN";; esac
    printf "  ${GN}✔${CL}  %-14s  %-32s  %-8s  ${tran_color}%-6s${CL}  %-10s  %s\n" \
      "$dev" "${model:0:32}" "$size" "$tran" "$media" "$serial"
  done
  echo ""
  TOTAL_TB=$(echo  "scale=2; $TOTAL_BYTES / 1099511627776" | bc 2>/dev/null || echo "0.00")
  SATA_TB=$(echo   "scale=2; $SATA_CAP    / 1099511627776" | bc 2>/dev/null || echo "0.00")
  SAS_TB=$(echo    "scale=2; $SAS_CAP     / 1099511627776" | bc 2>/dev/null || echo "0.00")
  NVME_TB=$(echo   "scale=2; $NVME_CAP    / 1099511627776" | bc 2>/dev/null || echo "0.00")
  USB_TB=$(echo    "scale=2; $USB_CAP     / 1099511627776" | bc 2>/dev/null || echo "0.00")
  OTHER_TB=$(echo  "scale=2; $OTHER_CAP   / 1099511627776" | bc 2>/dev/null || echo "0.00")
  msg_ok "${TOTAL_DRIVES} drives found — Total raw capacity: ${TOTAL_TB} TB"
  printf "${TAB}${DGN}NVMe: %d (%.2f TB)  SAS: %d (%.2f TB)  SATA: %d (%.2f TB)  USB: %d  Other: %d${CL}\n" \
    "$NVME_COUNT" "$NVME_TB" "$SAS_COUNT" "$SAS_TB" "$SATA_COUNT" "$SATA_TB" "$USB_COUNT" "$OTHER_COUNT"
}

generate_report() {
  section "Generating Report"
  msg_info "Writing report to ${OUTPUT_FILE}..."
  cat > "$OUTPUT_FILE" << EOF
# Proxmox Server Drive Inventory — $HOSTNAME_SHORT

> Created by: Thomas Van Auken — Van Auken Tech

**Hostname:** $HOSTNAME_SHORT  **FQDN:** $FQDN  **IP:** $IP_ADDRESS  **Generated:** $TIMESTAMP

---

## Executive Summary

| Field | Value |
|-------|-------|
| Operating System | $OS_NAME |
| Proxmox VE | $PVE_VERSION |
| Kernel | $(uname -r) |
| Total Storage Devices | $TOTAL_DRIVES |
| Total Raw Capacity | ${TOTAL_TB} TB |

### Drive Count by Type

| Type | Count | Capacity |
|------|-------|----------|
| NVMe | $NVME_COUNT | ${NVME_TB} TB |
| SAS | $SAS_COUNT | ${SAS_TB} TB |
| SATA | $SATA_COUNT | ${SATA_TB} TB |
| USB | $USB_COUNT | ${USB_TB} TB |
| Other (HBA/unknown) | $OTHER_COUNT | ${OTHER_TB} TB |
| **TOTAL** | **$TOTAL_DRIVES** | **${TOTAL_TB} TB** |

### Storage Controllers

| Controller Type | Count |
|----------------|-------|
| SATA / AHCI | $SATA_CONTROLLERS |
| SAS / HBA | $SAS_CONTROLLERS |
| NVMe | $NVME_CONTROLLERS |

---

## Controller Details

EOF
  lspci 2>/dev/null | grep -iE "SATA|AHCI|SAS|LSI|Broadcom.*HBA|Non-Volatile memory controller" \
    | while read -r line; do echo "- $line" >> "$OUTPUT_FILE"; done
  cat >> "$OUTPUT_FILE" << 'EOF'

---

## Visual Topology

EOF
  if [[ $NVME_COUNT -gt 0 ]]; then
    { echo '### NVMe Devices'; echo '```'; } >> "$OUTPUT_FILE"
    for drive in $ALL_DRIVES; do
      local tran; tran=$(lsblk -d -n -o TRAN "/dev/$drive" 2>/dev/null | xargs)
      [[ "$tran" != "nvme" ]] && continue
      local size model; size=$(lsblk -d -n -o SIZE "/dev/$drive" 2>/dev/null | xargs); model=$(lsblk -d -n -o MODEL "/dev/$drive" 2>/dev/null | xargs)
      echo "[NVMe Controller] ──▶ /dev/$drive  ($size)  $model" >> "$OUTPUT_FILE"
    done
    { echo '```'; echo ''; } >> "$OUTPUT_FILE"
  fi
  if [[ $SAS_COUNT -gt 0 ]]; then
    { echo '### SAS Devices'; echo '```'; } >> "$OUTPUT_FILE"
    for drive in $ALL_DRIVES; do
      local tran; tran=$(lsblk -d -n -o TRAN "/dev/$drive" 2>/dev/null | xargs)
      [[ "$tran" != "sas" ]] && continue
      local size model scsi_addr; size=$(lsblk -d -n -o SIZE "/dev/$drive" 2>/dev/null | xargs); model=$(lsblk -d -n -o MODEL "/dev/$drive" 2>/dev/null | xargs)
      scsi_addr=$(command -v lsscsi &>/dev/null && lsscsi 2>/dev/null | grep "/dev/$drive" | awk '{print $1}' || echo "N/A")
      echo "[$scsi_addr] [SAS HBA] ──▶ /dev/$drive  ($size)  $model" >> "$OUTPUT_FILE"
    done
    { echo '```'; echo ''; } >> "$OUTPUT_FILE"
  fi
  if [[ $SATA_COUNT -gt 0 ]]; then
    { echo '### SATA Devices'; echo '```'; } >> "$OUTPUT_FILE"
    for drive in $ALL_DRIVES; do
      local tran; tran=$(lsblk -d -n -o TRAN "/dev/$drive" 2>/dev/null | xargs)
      [[ "$tran" != "sata" ]] && continue
      local size model; size=$(lsblk -d -n -o SIZE "/dev/$drive" 2>/dev/null | xargs); model=$(lsblk -d -n -o MODEL "/dev/$drive" 2>/dev/null | xargs)
      echo "[SATA Controller] ──▶ /dev/$drive  ($size)  $model" >> "$OUTPUT_FILE"
    done
    { echo '```'; echo ''; } >> "$OUTPUT_FILE"
  fi
  if [[ $USB_COUNT -gt 0 ]]; then
    { echo '### USB Devices'; echo '```'; } >> "$OUTPUT_FILE"
    for drive in $ALL_DRIVES; do
      local tran; tran=$(lsblk -d -n -o TRAN "/dev/$drive" 2>/dev/null | xargs)
      [[ "$tran" != "usb" ]] && continue
      local size model; size=$(lsblk -d -n -o SIZE "/dev/$drive" 2>/dev/null | xargs); model=$(lsblk -d -n -o MODEL "/dev/$drive" 2>/dev/null | xargs)
      echo "[USB Controller] ──▶ /dev/$drive  ($size)  $model" >> "$OUTPUT_FILE"
    done
    { echo '```'; echo ''; } >> "$OUTPUT_FILE"
  fi
  if [[ $OTHER_COUNT -gt 0 ]]; then
    { echo '### Other / HBA-Attached Devices'; echo '```'; } >> "$OUTPUT_FILE"
    for drive in $ALL_DRIVES; do
      local tran; tran=$(lsblk -d -n -o TRAN "/dev/$drive" 2>/dev/null | xargs)
      [[ "$tran" = "nvme" || "$tran" = "sas" || "$tran" = "sata" || "$tran" = "usb" ]] && continue
      local size model; size=$(lsblk -d -n -o SIZE "/dev/$drive" 2>/dev/null | xargs); model=$(lsblk -d -n -o MODEL "/dev/$drive" 2>/dev/null | xargs)
      echo "[HBA / Unknown] ──▶ /dev/$drive  ($size)  $model  (transport: ${tran:-??})" >> "$OUTPUT_FILE"
    done
    { echo '```'; echo ''; } >> "$OUTPUT_FILE"
  fi
  cat >> "$OUTPUT_FILE" << 'EOF'
---

## Detailed Drive Inventory

| Device | Size | Transport | Model | Serial | Media | RPM / Info |
|--------|------|-----------|-------|--------|-------|------------|
EOF
  for drive in $ALL_DRIVES; do
    local dev="/dev/$drive" size tran model serial media rpm_info rotation
    size=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | xargs || echo "N/A")
    tran=$(lsblk -d -n -o TRAN "$dev" 2>/dev/null | xargs || echo "N/A")
    model=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null | xargs || echo "N/A")
    serial=$(lsblk -d -n -o SERIAL "$dev" 2>/dev/null | xargs || echo "N/A")
    media="Unknown"; rpm_info="N/A"
    if [[ "$tran" = "nvme" ]]; then media="NVMe SSD"; rpm_info="NVMe"
    elif smartctl -i "$dev" &>/dev/null 2>&1; then
      rotation=$(smartctl -i "$dev" 2>/dev/null | grep "Rotation Rate" | cut -d: -f2 | xargs)
      if echo "$rotation" | grep -qi "Solid State"; then media="SSD"; rpm_info="SSD"
      elif echo "$rotation" | grep -qE "[0-9]+ rpm"; then media="HDD"; rpm_info="$rotation"
      elif [[ "$tran" = "sas" ]]; then
        local rpm; rpm=$(smartctl -a "$dev" 2>/dev/null | grep -i "rpm" | head -1 | grep -oE "[0-9]+" | head -1)
        [[ -n "$rpm" ]] && { media="HDD"; rpm_info="${rpm} rpm"; }
      fi
    fi
    echo "| $drive | $size | $tran | $model | $serial | $media | $rpm_info |" >> "$OUTPUT_FILE"
  done
  cat >> "$OUTPUT_FILE" << EOF

---

## Current Storage Usage

### Block Device Overview
\`\`\`
$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS 2>/dev/null)
\`\`\`

### LVM Physical Volumes
\`\`\`
$(pvs 2>/dev/null || echo "No LVM physical volumes detected")
\`\`\`

### LVM Volume Groups
\`\`\`
$(vgs 2>/dev/null || echo "No LVM volume groups detected")
\`\`\`

### ZFS Pools
\`\`\`
$(zpool list 2>/dev/null || echo "No ZFS pools detected")
\`\`\`

---

*Generated by Proxmox Drive Inventory v3.0 — Van Auken Tech*  
*$HOSTNAME_SHORT ($FQDN) · $TIMESTAMP*
EOF
  msg_ok "Report written successfully"
}

summary() {
  local report_size; report_size=$(du -h "$OUTPUT_FILE" 2>/dev/null | awk '{print $1}')
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       INVENTORY COMPLETE — Van Auken Tech${CL}"
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo ""
  printf "  ${GN}${BLD}Total Drives    :${CL}  %d\n"    "$TOTAL_DRIVES"
  printf "  ${GN}${BLD}Total Capacity  :${CL}  %s TB\n" "$TOTAL_TB"
  echo ""
  printf "  ${BL}%-10s${CL}  %2d drives  %s TB\n"  "NVMe"  "$NVME_COUNT"  "$NVME_TB"
  printf "  ${YW}%-10s${CL}  %2d drives  %s TB\n"  "SAS"   "$SAS_COUNT"   "$SAS_TB"
  printf "  ${DGN}%-10s${CL}  %2d drives  %s TB\n" "SATA"  "$SATA_COUNT"  "$SATA_TB"
  [[ $USB_COUNT   -gt 0 ]] && printf "  ${CL}%-10s  %2d drives  %s TB\n" "USB"   "$USB_COUNT"   "$USB_TB"
  [[ $OTHER_COUNT -gt 0 ]] && printf "  ${CL}%-10s  %2d drives  %s TB\n" "Other" "$OTHER_COUNT" "$OTHER_TB"
  echo ""
  printf "  ${GN}Report File     :${CL}  %s  ${DGN}(%s)${CL}\n" "$OUTPUT_FILE" "$report_size"
  echo ""
  echo -e "  ${YW}To download to your local machine:${CL}"
  printf "  ${DGN}scp root@%s:%s/%s ~/Downloads/${CL}\n" "$IP_ADDRESS" "$(pwd)" "$(basename "$OUTPUT_FILE")"
  echo ""
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo -e "${DGN}  Created by : Thomas Van Auken — Van Auken Tech${CL}"
  echo -e "${DGN}  Host       : $FQDN${CL}"
  echo -e "${DGN}  Completed  : $(date '+%Y-%m-%d %H:%M:%S')${CL}"
  echo -e "${DGN}${BLD}  ────────────────────────────────────────────────────────────────${CL}"
  echo ""
}

main() {
  header_info
  preflight
  gather_system_info
  scan_drives
  generate_report
  summary
}

main "$@"
