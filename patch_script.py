import json

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

# We need to replace the VM Hardware Spoofing section to dynamically adjust based on testing
import re
new_vm_spoofing = """
    msg_info "Applying VM Hardware Spoofing"
    mkdir -p /etc/45drives/server_info/
    
    # Run dmap first so it discovers the passed-through HBA natively
    yes | dmap >> "$LOGFILE" 2>&1 || true
    
    # Inject the chosen chassis size and model using jq
    # NOTE: To render the full chassis uncropped in the UI, we force the spoof to NOT be a VM.
    if [ -f /etc/45drives/server_info/server_info.json ]; then
        jq '.Model = "'$HW_MODEL'" | ."Chassis Size" = "'$HW_CHASSIS'" | ."Edit Mode" = true | .VM = false | .Motherboard.Manufacturer = "45Drives" | .Motherboard."Product Name" = "Storinator" | .Motherboard."Serial Number" = "00000000" | .Serial = "00000000"' /etc/45drives/server_info/server_info.json > /tmp/server_info.json && mv /tmp/server_info.json /etc/45drives/server_info/server_info.json
    fi
    
    # Patch the underlying Python script so it stops aggressively resetting the VM flag and overwriting our spoofing
    if [ -f /opt/45drives/tools/server_identifier ]; then
        sed -i 's/server\\["VM"\\] = vm_check(server\\["Motherboard"\\])/server["VM"] = False/' /opt/45drives/tools/server_identifier
        sed -i 's/def vm_passthrough(server):/def vm_passthrough(server):\\n\\tpass\\n\\ndef old_vm_passthrough(server):/' /opt/45drives/tools/server_identifier
    fi
    msg_ok "Applied VM hardware overrides"
"""

content = re.sub(r'msg_info "Applying VM Hardware Spoofing".*?msg_ok "Applied VM hardware overrides"', new_vm_spoofing.strip(), content, flags=re.DOTALL)

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
