import re

with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

bad_sed = """        sed -i 's/def vm_passthrough(server):/def vm_passthrough(server):
\tpass

def old_vm_passthrough(server):/' /opt/45drives/tools/server_identifier"""

good_sed = """        sed -i 's/def vm_passthrough(server):/def vm_passthrough(server):\\n\\tpass\\n\\ndef old_vm_passthrough(server):/' /opt/45drives/tools/server_identifier"""

content = content.replace(bad_sed, good_sed)

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
