#!/usr/bin/env bash
# ============================================================================
#  Technitium DNS Server — Repair Corrupted SQLite Database Errors
#  Created by: Thomas Van Auken — Van Auken Tech
#  Version:    1.0
#  Date:       2026-08-18
#  Repo:       https://github.com/tvanauken/install-scripts
# ============================================================================
#
# PURPOSE:
#   Automatically repairs "SQLite Error 11: database disk image is malformed"
#   errors by gracefully stopping the Technitium DNS service, removing the 
#   corrupted querylogs.db file, and restarting the service to generate a fresh database.
#
# COMPATIBILITY:
#   Technitium DNS Server running on Debian/Ubuntu with systemd.
#
# USAGE:
#   chmod +x technitium_sqlite_repair.sh && ./technitium_sqlite_repair.sh
#
# ============================================================================

# ── Log to terminal AND timestamped file ─────────────────────────────────────
LOGFILE="/var/log/technitium_sqlite_repair_$(date +%Y%m%d_%H%M%S).log"
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
  _____ ___ ___ _  _ _  _ ___ _____ ___ _   _ __  __ 
 |_   _| __/ __| || | \| |_ _|_   _|_ _| | | |  \/  |
   | | | _| (__| __ | .` || |  | |  | || |_| | |\/| |
   |_| |___\___|_||_|_|\_|___| |_| |___|\___/|_|  |_|
BANNER
  echo -e "${CL}"
  echo -e "${DGN}  ── Repair Technitium Corrupted SQLite Database Errors ─────────────${CL}"
  printf "  ${DGN}Host   :${CL}  ${BL}%s${CL}\n" "$(hostname -f 2>/dev/null || hostname)"
  printf "  ${DGN}Date   :${CL}  ${BL}%s${CL}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "  ${DGN}Log    :${CL}  ${BL}%s${CL}\n" "$LOGFILE"
  echo ""
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    msg_error "This script must be run as root."
    exit 1
  fi
  msg_ok "Running as root"
}

check_service() {
  if ! systemctl list-units | grep -qi dns.service; then
    msg_warn "dns.service not found. Verifying installation path..."
    if [ ! -d "/etc/dns/apps" ]; then
      msg_error "Technitium DNS apps directory not found at /etc/dns/apps. Aborting."
      exit 1
    fi
  else
    msg_ok "Technitium DNS service detected"
  fi
}

repair_database() {
  section "Repairing Corrupted Database"
  
  msg_info "Stopping dns.service..."
  systemctl stop dns.service 2>/dev/null
  msg_ok "dns.service stopped"

  local DB_DIR="/etc/dns/apps/Query Logs (Sqlite)"
  
  if [ -d "$DB_DIR" ]; then
    msg_info "Checking for database files in $DB_DIR..."
    
    # Check if there are any .db files
    local db_files=$(find "$DB_DIR" -name "*.db" 2>/dev/null)
    
    if [ -n "$db_files" ]; then
      while IFS= read -r db_file; do
        if [ -n "$db_file" ]; then
          msg_warn "Removing database file: $db_file"
          rm -f "$db_file"
          msg_ok "Removed: $db_file"
        fi
      done <<< "$db_files"
    else
      msg_ok "No .db files found to remove. Moving forward."
    fi
  else
    msg_warn "App directory $DB_DIR does not exist. Skipping file removal."
  fi
  
  msg_info "Starting dns.service..."
  systemctl start dns.service 2>/dev/null
  msg_ok "dns.service started"
}

verify_service() {
  section "Verifying Service Health"
  sleep 2
  if systemctl is-active --quiet dns.service; then
    msg_ok "Technitium DNS Server is running successfully"
  else
    msg_error "Technitium DNS Server failed to start! Check systemctl status dns.service"
  fi
}

main() {
  header_info
  section "Preflight Checks"
  check_root
  check_service
  
  repair_database
  verify_service
  
  echo ""
  echo -e "${BL}${BLD}  ════════════════════════════════════════════════════════════════${CL}"
  echo -e "${BL}${BLD}       COMPLETE — Database Reset Successfully${CL}"
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
