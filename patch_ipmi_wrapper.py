import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

# The wrapper is hanging because we passed "$@" into it, but it was evaluated in the original script rather than being written literally. 
# We also need to fix how it's executed so it doesn't cause bash to infinitely loop or hang when called without arguments.

good_wrapper = r"""
        cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
exec /usr/bin/ipmitool.real -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" "\$@"
WRAPPER
"""

old_wrapper = r"""
        cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
exec /usr/bin/ipmitool.real -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" "\$@"
WRAPPER
"""

content = content.replace(old_wrapper.strip(), good_wrapper.strip())

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
