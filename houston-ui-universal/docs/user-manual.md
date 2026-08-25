# Van Auken Tech - Houston / 45Drives - Universal Installer - User Manual

## Overview
The Van Auken Tech - Houston / 45Drives - Universal Installer deploys a powerful, centralized management dashboard tailored for 45Drives hardware and virtualized storage environments. It provides a robust, graphical interface for managing ZFS pools, Samba/NFS file shares, networking, and system identities, all wrapped in a custom Van Auken Tech theme.

## Deployment Environments
When you run the installer, you will be prompted to select your environment type:

1. **BAREMETAL (Physical Hardware)**
   Select this if you are installing directly onto a physical server or 45Drives hardware. This mode installs the full suite of virtualization tools (`cockpit-machines`, `cockpit-podman`, `libvirt`) allowing the machine to host VMs and containers.

2. **VM (Virtual Machine with HBA Passthrough)**
   Select this if you are installing inside a Proxmox or ESXi Virtual Machine, and passing through a physical HBA (e.g., LSI 9305-16i) to manage drives. This mode strips out conflicting nested virtualization layers and applies dynamic hardware spoofing to force the UI to render the correct 45Drives physical chassis.

## Accessing the Dashboard
Once the installation is complete, open your web browser and navigate to:
`https://<YOUR_SERVER_IP>:9090`

Log in using your system's root or sudo user credentials.
