sshpass -p 'VanAwsome1' ssh -o StrictHostKeyChecking=no root@10.1.1.47 << 'INNEREOF'
cd /tmp
wget -qO test_install.sh https://raw.githubusercontent.com/tvanauken/install-scripts/main/houston-ui/install.sh
chmod +x test_install.sh
INNEREOF
