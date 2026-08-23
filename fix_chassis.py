import json
import subprocess

try:
    with open('/etc/45drives/server_info/server_info.json', 'r+') as f:
        data = json.load(f)
        
    data['Model'] = 'Storinator-S45-Turbo'
    data['Chassis Size'] = 'S45'

    with open('/etc/45drives/server_info/server_info.json', 'w') as f:
        json.dump(data, f, indent=4)
        
    print("Success")
except Exception as e:
    print("Failed: " + str(e))
