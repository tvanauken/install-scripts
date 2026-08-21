# 45Drives Houston UI & Cockpit Installer - User Manual
**Created by:** Thomas Van Auken — Van Auken Tech

## 1. Introduction
The **45Drives Houston UI & Cockpit Installer** is an interactive, cross-platform installation utility designed to standardize the deployment of the 45Drives software stack. 

It handles the complex edge-cases involved in virtualized storage environments (such as running TrueNAS/Ubuntu as a VM inside Proxmox with an HBA passed through), ensuring the physical disks and chassis layout map correctly into the web interface.

## 2. Prerequisites
*   The target machine must be running a supported Linux distribution (Ubuntu 20.04/22.04/24.04, Debian, Rocky Linux, AlmaLinux, CentOS, or RHEL).
*   The script must be executed with `root` privileges.
*   The target machine must have internet access to reach the `repo.45drives.com` endpoint.

## 3. Installation
To execute the installer, run the following command directly on your storage server:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/houston-ui/install.sh)"
```

## 4. Execution Workflow

### Step 1: Initialization and OS Detection
The script will clear the terminal, display the Van Auken Tech banner, and automatically detect your operating system and package manager (`apt` or `dnf`). It will automatically install `whiptail` if it is missing, which is required for the interactive UI.

### Step 2: Environment Selection
You will be prompted with a visual menu asking for the Deployment Environment:
*   **Physical 45Drives Hardware (BAREMETAL):** Select this if you are running the OS directly on the physical motherboard of the Storinator/HomeLab server. The script will rely on standard IPMI and SMBIOS queries to discover the chassis.
*   **Virtual Machine with HBA Passthrough (VM):** Select this if you are running the OS inside a hypervisor (like Proxmox or ESXi) and passing the SAS HBA controller directly to the VM.

### Step 3: VM Hardware Spoofing (VM Mode Only)
If you selected the **VM** option, the `dmap` utility natively fails to map disks because it cannot read the physical motherboard's IPMI sensors through the hypervisor abstraction layer. 

The script resolves this by prompting you for the physical chassis size:
*   Storinator S45
*   Storinator Q30
*   Storinator AV15
*   Storinator XL60
*   45HomeLab HL15
*   45HomeLab HL8

The script will then inject a customized `/etc/45drives/server_info/server_info.json` file. It sets `"Edit Mode": true` to permanently lock the chassis definition, bypassing the broken automated hardware scan.

### Step 4: Installation & Configuration
The script proceeds automatically to:
1.  Download and execute the official 45Drives repository setup script.
2.  Install the required packages (`cockpit`, `cockpit-45drives-hardware`, `cockpit-zfs`, `45drives-tools`, etc.).
3.  Mask and disable the `openipmi` systemd service (if running as a VM) to prevent boot delays and failed service states.
4.  Execute `dmap` to generate the `/etc/vdev_id.conf` ZFS aliases.
5.  Enable and restart the Cockpit socket and daemon.

## 5. Post-Installation Verification
Upon completion, the script will output the exact URL to access your new Houston UI:
`https://<SERVER-IP>:9090`

Log in using your standard root or administrator credentials. Navigate to the **45Drives Disks** and **Hardware** tabs to verify that the physical chassis map has rendered correctly and all disks are visible.