cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
# We must timeout the command because some physical hosts hang on certain ipmi sub-commands when proxied
timeout 3 /usr/bin/ipmitool.real -I lanplus -H "192.168.200.136" -U "tvanauken" -P "VanAwsome1" "$@"
WRAPPER
chmod +x /usr/bin/ipmitool
