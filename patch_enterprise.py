with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

# Replace APT pinning to be dynamic based on Ubuntu version
old_pinning = """
msg_info "Setting apt preferences for 45Drives repo"
cat <<PREF > /etc/apt/preferences.d/45drives.pref
Package: cockpit* 45drives-tools
Pin: origin "repo.45drives.com"
Pin-Priority: 1000

Package: *
Pin: origin "repo.45drives.com"
Pin-Priority: -1
PREF
"""

new_pinning = """
msg_info "Setting apt preferences for 45Drives repo"
if [[ "$OS_ID" == "ubuntu" && "$VERSION_ID" == "24.04" ]]; then
    # Strict pinning for 24.04 to force OS-native ZFS and Samba
    cat <<PREF > /etc/apt/preferences.d/45drives.pref
Package: cockpit* 45drives-tools
Pin: origin "repo.45drives.com"
Pin-Priority: 1000

Package: *
Pin: origin "repo.45drives.com"
Pin-Priority: -1
PREF
else
    # 22.04 and 20.04 require the 45Drives forks of ZFS (zfs-dkms/zfs-zed)
    rm -f /etc/apt/preferences.d/45drives.pref
fi
"""

content = content.replace(old_pinning.strip(), new_pinning.strip())

# Replace Packages array to dynamically add cockpit-super-simple-setup ONLY on 24.04+ (due to nodejs 18 dependency)
old_packages = 'PACKAGES="zfsutils-linux samba winbind realmd nfs-kernel-server podman cockpit cockpit-bridge cockpit-ws cockpit-system cockpit-45drives-hardware cockpit-file-sharing cockpit-navigator cockpit-identities cockpit-benchmark cockpit-zfs cockpit-ceph cockpit-s3-browser cockpit-super-simple-setup cockpit-machines cockpit-podman 45drives-tools"'

new_packages = """
PACKAGES="zfsutils-linux samba winbind realmd nfs-kernel-server podman cockpit cockpit-bridge cockpit-ws cockpit-system cockpit-45drives-hardware cockpit-file-sharing cockpit-navigator cockpit-identities cockpit-benchmark cockpit-zfs cockpit-ceph cockpit-s3-browser cockpit-machines cockpit-podman 45drives-tools"
if [[ "$VERSION_ID" == "24.04" ]]; then
    PACKAGES="$PACKAGES cockpit-super-simple-setup"
fi
"""

content = content.replace(old_packages.strip(), new_packages.strip())

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
