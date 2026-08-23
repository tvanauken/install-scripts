import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

ipmi_patch = """
    msg_info "Masking OpenIPMI (VM Environment)"
    systemctl disable --now openipmi >> "$LOGFILE" 2>&1 || true
    systemctl mask openipmi >> "$LOGFILE" 2>&1 || true
    systemctl reset-failed >> "$LOGFILE" 2>&1 || true
    msg_ok "Masked OpenIPMI service"

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
    
    # Run dmap first so it discovers the passed-through HBA natively and pulls the real FRU via our proxy
    yes | dmap >> "$LOGFILE" 2>&1 || true
"""

content = re.sub(r'    msg_info "Masking OpenIPMI \(VM Environment\)".*?    yes \| dmap >> "\$LOGFILE" 2>&1 \|\| true', ipmi_patch.strip(), content, flags=re.DOTALL)

# Now we also need to remove the manual 'Edit Mode': true and 'Model': ... jq override, because the IPMI wrapper will now allow dmap to fetch the TRUE model (Storinator-S45-Turbo) natively.
# We just need to ensure VM is False so the UI renders fully.
content = re.sub(r"jq '\.Model =.*?fi", "jq '.VM = false' /etc/45drives/server_info/server_info.json > /tmp/server_info.json && mv /tmp/server_info.json /etc/45drives/server_info/server_info.json", content, flags=re.DOTALL)

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
