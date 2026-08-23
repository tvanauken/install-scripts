sshpass -p 'VanAwsome1' ssh -o StrictHostKeyChecking=no root@10.1.1.47 << 'INNEREOF'
sed -i 's/p5.min.js//g' /usr/share/cockpit/45drives-disks/manifest.json || true
INNEREOF
