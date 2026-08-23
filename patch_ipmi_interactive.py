import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

# Add the IPMI proxy question to the VM prompt section
whiptail_patch = """
    # Set Model name based on chassis
    if [[ "$HW_CHASSIS" == "HL15" || "$HW_CHASSIS" == "HL8" ]]; then
        HW_MODEL="HomeLab-$HW_CHASSIS"
    else
        HW_MODEL="Storinator-$HW_CHASSIS"
    fi
    log "Configured VM Hardware Spoofing: Model=$HW_MODEL, Chassis=$HW_CHASSIS"

    # Ask if we should proxy IPMI
    if whiptail --title "IPMI Configuration" --yesno "Would you like to configure an IPMI Proxy to a physical Proxmox host for this VM? (Allows baremetal sensor passthrough)" 10 70; then
        IPMI_PROXY="YES"
        IPMI_HOST=$(whiptail --title "IPMI Configuration" --inputbox "Enter the IP address of the physical IPMI host:" 10 60 3>&1 1>&2 2>&3)
        IPMI_USER=$(whiptail --title "IPMI Configuration" --inputbox "Enter the IPMI username:" 10 60 3>&1 1>&2 2>&3)
        IPMI_PASS=$(whiptail --title "IPMI Configuration" --passwordbox "Enter the IPMI password:" 10 60 3>&1 1>&2 2>&3)
        log "IPMI Proxy Enabled for $IPMI_HOST"
    else
        IPMI_PROXY="NO"
        log "IPMI Proxy Disabled"
    fi
"""

content = re.sub(r'    # Set Model name based on chassis.*?    log "Configured VM Hardware Spoofing: Model=\$HW_MODEL, Chassis=\$HW_CHASSIS"', whiptail_patch.strip(), content, flags=re.DOTALL)

# Update the execution part of the script to use these new variables conditionally
ipmi_exec_patch = """
    if [[ "$IPMI_PROXY" == "YES" ]]; then
        msg_info "Bridging VM to Physical Host via IPMI Proxy"
        # Install ipmitool to query the bare metal host sensors and FRU
        apt-get install -y -qq ipmitool >> "$LOGFILE" 2>&1
        if [ -f /usr/bin/ipmitool ]; then
            mv /usr/bin/ipmitool /usr/bin/ipmitool.real
            cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
exec /usr/bin/ipmitool.real -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" "\$@"
WRAPPER
            chmod +x /usr/bin/ipmitool
        fi
        msg_ok "Configured IPMI Proxy to Physical Host"
    fi
"""

content = re.sub(r'    msg_info "Bridging VM to Physical Host via IPMI Proxy".*?    msg_ok "Configured IPMI Proxy to Physical Host"', ipmi_exec_patch.strip(), content, flags=re.DOTALL)


with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
