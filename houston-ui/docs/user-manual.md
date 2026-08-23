# Van Auken Tech Houston UI - User Manual

## Overview
The Van Auken Tech Houston UI is a powerful, centralized management dashboard tailored for 45Drives hardware and virtualized storage environments. It provides a robust, graphical interface for managing ZFS pools, Samba/NFS file shares, networking, and system identities, all wrapped in a custom Van Auken Tech theme.

## Accessing the Dashboard
1. Open a modern web browser (Chrome, Firefox, Safari).
2. Navigate to `https://<YOUR_SERVER_IP>:9090` (e.g., `https://192.168.200.140:9090`).
3. You will be greeted by the Van Auken Tech login screen.
4. Log in using your system credentials (e.g., `root` or `tvanauken`).

## Core Modules & Functionality

### 45Drives Disks
*   **Purpose:** Provides a physical 2D layout of your server chassis (e.g., Storinator S45).
*   **Usage:** Navigate to this tab to see the health and location of your physical drives. Empty bays will appear dark, while populated bays will light up.
*   **Virtual Machines:** When deployed in a Proxmox VM with HBA pass-through and IPMI Proxy enabled, the interface natively reads the bare-metal FRU data to render the full physical chassis layout perfectly un-cropped.

### ZFS Storage Management
*   **Purpose:** Create, manage, and monitor ZFS pools and datasets.
*   **Usage:** 
    *   Click **Create Pool** to select physical drives and stripe/mirror configurations.
    *   Manage snapshots and compression settings natively within the UI.

### File Sharing (Samba & NFS)
*   **Purpose:** Instantly provision network shares.
*   **Usage:**
    *   Navigate to **File Sharing**.
    *   Select an existing ZFS dataset or directory.
    *   Toggle Samba (Windows/macOS) or NFS (Linux/Unix) on or off.
    *   Configure user permissions directly from the interface.

### System Updates
*   **Purpose:** Keep your server secure and up to date.
*   **Usage:** The **Software Updates** tab connects directly to the Ubuntu repositories. Click **Install all updates** to upgrade your system securely. (This relies on the NetworkManager connectivity fix applied during installation).

## Troubleshooting

*   **Software Updates says "Offline":** Ensure that `NetworkManager` is managing your network connection. Run `nmcli networking connectivity check` from the terminal. It should return `portal` or `full`.
*   **Disks tab shows "No drives found":** If you are in a VM, ensure your HBA (e.g., LSI 9305-16i) is passed through entirely via PCIe passthrough, not as individual virtual disks.

---
*Created and maintained by Thomas Van Auken - Van Auken Tech.*
