sshpass -p 'VanAwsome1' ssh -o StrictHostKeyChecking=no root@192.168.200.151 << 'INNEREOF'
cd /tmp
wget -qO test_install.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/houston-ui/install.sh
chmod +x test_install.sh
INNEREOF
