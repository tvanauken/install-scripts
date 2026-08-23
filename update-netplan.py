import yaml
import sys

try:
    with open('/etc/netplan/50-cloud-init.yaml', 'r') as f:
        data = yaml.safe_load(f)
        
    # Apply static IP, gateway, dns, and search domain to enp6s18
    data['network']['ethernets']['enp6s18'] = {
        'dhcp4': False,
        'addresses': ['192.168.200.140/24'],
        'routes': [{'to': 'default', 'via': '192.168.200.1'}],
        'nameservers': {
            'addresses': ['172.16.250.8'],
            'search': ['mgmt.home.vanauken.tech']
        }
    }

    with open('/etc/netplan/50-cloud-init.yaml', 'w') as f:
        yaml.dump(data, f)
        
    print("Success")
except Exception as e:
    print("Failed: " + str(e))
