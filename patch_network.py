with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

network_fix = """
msg_info "Configuring NetworkManager for Cockpit Updates"
if [[ "$PKG_MGR" == "apt" ]]; then
    cat << 'NCONF' > /etc/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
uri=http://archive.ubuntu.com/ubuntu/
interval=300
NCONF
    
    if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
        sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
    fi
    
    # We leave netplan alone so we don't break network configs, just restarting NM allows it to perform the connectivity check
    systemctl restart NetworkManager >> "$LOGFILE" 2>&1 || true
    # Run pkcon refresh to prime packagekit
    sleep 3
    pkcon refresh >> "$LOGFILE" 2>&1 || true
fi
msg_ok "Configured NetworkManager"

msg_info "Running 45Drives dmap utility"
"""
content = content.replace('msg_info "Running 45Drives dmap utility"', network_fix.strip())

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
