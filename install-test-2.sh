HW_MODEL="Storinator-AV15"
HW_CHASSIS="AV15"

cat > /tmp/server_info.json <<INNEREOF
{
    "Motherboard": {
        "Manufacturer": "45Drives",
        "Product Name": "Storinator",
        "Serial Number": "00000000"
    },
    "HBA": [],
    "Hybrid": false,
    "Serial": "00000000",
    "Model": "${HW_MODEL}",
    "Alias Style": "STORINATOR",
    "Chassis Size": "${HW_CHASSIS}",
    "VM": false,
    "Edit Mode": true,
    "OS NAME": "Linux",
    "OS VERSION_ID": "",
    "Auto Alias": false,
    "HWRAID": false
}
INNEREOF
