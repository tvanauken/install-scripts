apt install -y ipmitool
mv /usr/bin/ipmitool /usr/bin/ipmitool.real
cat << 'WRAPPER' > /usr/bin/ipmitool
#!/bin/bash
exec /usr/bin/ipmitool.real -I lanplus -H 192.168.200.136 -U tvanauken -P VanAwsome1 "\$@"
WRAPPER
chmod +x /usr/bin/ipmitool
