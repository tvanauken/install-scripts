import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

# Replace the VM Hardware Spoofing block completely
vm_spoofing = """
    msg_info "Bridging VM to Physical Host via IPMI Proxy"
    # Install ipmitool to query the bare metal host sensors and FRU
    apt-get install -y -qq ipmitool >> "$LOGFILE" 2>&1
    if [ -f /usr/bin/ipmitool ]; then
        mv /usr/bin/ipmitool /usr/bin/ipmitool.real
        cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
exec /usr/bin/ipmitool.real -I lanplus -H 192.168.200.136 -U tvanauken -P VanAwsome1 "\$@"
WRAPPER
        chmod +x /usr/bin/ipmitool
    fi
    msg_ok "Configured IPMI Proxy to Physical Host"
    
    msg_info "Applying VM Hardware Overrides"
    mkdir -p /etc/45drives/server_info/
    
    # Run dmap first so it discovers the passed-through HBA natively and pulls the real FRU via our proxy
    yes | dmap >> "$LOGFILE" 2>&1 || true
    
    if [ -f /etc/45drives/server_info/server_info.json ]; then
        # Set VM to false so the UI renders fully, and strictly enforce the S45 model to avoid UI parsing crashes
        jq '.Model = "Storinator-S45" | .VM = false | ."Edit Mode" = true' /etc/45drives/server_info/server_info.json > /tmp/server_info.json && mv /tmp/server_info.json /etc/45drives/server_info/server_info.json
    fi
    
    # Patch the underlying Python script so it stops aggressively resetting the VM flag
    if [ -f /opt/45drives/tools/server_identifier ]; then
        sed -i 's/server\\["VM"\\] = vm_check(server\\["Motherboard"\\])/server["VM"] = False/' /opt/45drives/tools/server_identifier
        sed -i 's/def vm_passthrough(server):/def vm_passthrough(server):\\n\\tpass\\n\\ndef old_vm_passthrough(server):/' /opt/45drives/tools/server_identifier
    fi
    msg_ok "Applied VM hardware overrides"

    msg_info "Masking OpenIPMI (VM Environment)"
    systemctl disable --now openipmi >> "$LOGFILE" 2>&1 || true
    systemctl mask openipmi >> "$LOGFILE" 2>&1 || true
    systemctl reset-failed >> "$LOGFILE" 2>&1 || true
    msg_ok "Masked OpenIPMI service"
"""

content = re.sub(r'    msg_info "Applying VM Hardware Spoofing".*?    msg_ok "Masked OpenIPMI service"', vm_spoofing.strip(), content, flags=re.DOTALL)

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
