# Raspberry Pi VNC Multi-Session Installer

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 2.0.1  

## Overview
A fully automated, production-ready installer that configures a true multi-session, headless VNC server on Raspberry Pi hardware (Kali Linux, Debian, or Ubuntu). Unlike traditional VNC setups that share a single desktop, this script uses **systemd socket activation** combined with **LightDM XDMCP** to spawn a completely independent graphical session for every connection.

Includes a critical global D-Bus and runtime directory isolation patch (`/etc/X11/Xsession.d/99-isolate-dbus-runtime`) to natively support concurrent, simultaneous connections from the **exact same user account** without crashing.

## Usage

Run the following command directly on your Raspberry Pi:

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/raspberry-pi-vnc/raspberry-pi-vnc-install.sh)
```

## Features
-   **Zero Configuration for Users:** Installs TigerVNC, XFCE4, and LightDM automatically.
-   **OS Validation:** Safely checks for Debian/Kali/Ubuntu derivatives before execution.
-   **Universal Firewall:** Dynamically detects and configures UFW, firewalld, or iptables automatically.
-   **Functional Validation:** Mathematically verifies all listening sockets (5900, 177) and active services before declaring success.
-   **RealVNC Compatible:** Bypasses TLS incompatibilities automatically; connect natively via RealVNC Viewer on macOS/Windows.
-   **True Independent Desktops:** Acts like an RDP server. 10 connections = 10 unique desktops.
-   **Native Login Screen:** Routes connections securely through the standard LightDM graphical greeter.

## Documentation
*   [User Manual](docs/user-manual.md)
*   [Build Log](docs/build-log.md)

---
*Van Auken Tech*
