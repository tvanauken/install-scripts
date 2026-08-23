cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
if [ "$#" -eq 0 ]; then
    exec /usr/bin/ipmitool.real
else
    exec /usr/bin/ipmitool.real -I lanplus -H "192.168.200.136" -U "tvanauken" -P "VanAwsome1" "$@"
fi
WRAPPER
chmod +x /usr/bin/ipmitool
