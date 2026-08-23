import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

bad_wrapper = """
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
exec /usr/bin/ipmitool.real -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" "\\$@"
"""

good_wrapper = """
#!/bin/bash
# Natively route all IPMI calls from the VM to the physical Proxmox host
# We must timeout the command because some physical hosts hang on certain ipmi sub-commands when proxied
timeout 3 /usr/bin/ipmitool.real -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" "\\$@"
"""

content = content.replace(bad_wrapper.strip(), good_wrapper.strip())

# We also need to strip out the dmap command from the IPMI proxy section because dmap completely hangs 
# when ipmitool takes more than a few seconds, breaking the install script.
content = re.sub(r'    # Run dmap first so it discovers the passed-through HBA natively and pulls the real FRU via our proxy\n    yes \| dmap >> "\$LOGFILE" 2>&1 \|\| true', '', content, flags=re.DOTALL)

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
