import yaml
import sys

try:
    with open('/etc/netplan/50-cloud-init.yaml', 'r') as f:
        data = yaml.safe_load(f)
        
    # Remove the conflicting default route from enp6s19 since it's a storage network, 
    # keeping the default route purely on enp6s18 (the management/public network).
    if 'routes' in data['network']['ethernets']['enp6s19']:
        del data['network']['ethernets']['enp6s19']['routes']

    with open('/etc/netplan/50-cloud-init.yaml', 'w') as f:
        yaml.dump(data, f)
        
    print("Success")
except Exception as e:
    print("Failed: " + str(e))
