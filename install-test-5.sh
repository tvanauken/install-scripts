HW_CHASSIS="S45"
HW_MODEL="Storinator-S45"
cat << 'INNEREOF' > /tmp/test-spoof.py
import json
with open('/etc/45drives/server_info/server_info.json', 'r+') as f:
    data = json.load(f)
    data['Model'] = 'Storinator-S45'
    data['Chassis Size'] = 'S45'
    data['Alias Style'] = 'STORINATOR'
    data['VM'] = False
    data['Motherboard'] = {"Manufacturer": "45Drives", "Product Name": "Storinator", "Serial Number": "0000000"}
    data['Serial'] = '00000000'
    data['Edit Mode'] = True
    f.seek(0)
    json.dump(data, f, indent=4)
    f.truncate()
INNEREOF
