import json

with open('/etc/45drives/server_info/server_info.json', 'r') as f:
    data = json.load(f)
    
data['Motherboard']['Manufacturer'] = "Supermicro"
data['Motherboard']['Product Name'] = "X11DPL-i"

with open('/etc/45drives/server_info/server_info.json', 'w') as f:
    json.dump(data, f, indent=4)
