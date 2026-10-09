# VNC Setup on Germanium (Kali Linux Raspberry Pi 4)

**Author: Thomas Van Auken — Van Auken Tech**
**Revision 6**

<div style="background-color: #e3f2fd; border-left: 6px solid #1976d2; padding: 15px;">
<strong>Purpose:</strong> Detailed log of actions taken to setup a robust, headless RealVNC-compatible VNC server on the new Raspberry Pi 4 running Kali Linux. This revision upgrades the multi-session conflict fix to be applied <strong>globally to all users</strong> on the system instead of just a single user account.
</div>

## 1. The Multi-Session Architecture (XDMCP + systemd sockets)
To fulfill the requirement of spawning independent desktop environments for every single connection—even for the identical user—we use **systemd socket activation** intercepting incoming VNC traffic to instantly spawn an independent `Xvnc` process tied directly to the display manager's **XDMCP** service.

## 2. Display Manager Configuration (LightDM)
Enabled the XDMCP server inside LightDM so it can serve login screens to the dynamic Xvnc processes.
```bash
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo bash -c "cat << 'CONF' > /etc/lightdm/lightdm.conf.d/50-xdmcp.conf
[XDMCPServer]
enabled=true
port=177
CONF"
sudo systemctl restart lightdm
```

## 3. Global Concurrent Session Isolation (Xsession.d)
Linux desktop environments natively crash when the same user attempts to initialize a second concurrent graphical session due to `systemd --user` and `dbus` conflicting over active session buses. To fix this comprehensively for **all current and future users**, we intercept the global X11 session initialization. 

We created `/etc/X11/Xsession.d/99-isolate-dbus-runtime` to forcefully generate an isolated runtime directory and a discrete D-Bus instance for every new login session.

```bash
# /etc/X11/Xsession.d/99-isolate-dbus-runtime
# Isolate D-Bus and runtime directories so the same user can run multiple concurrent XFCE sessions
export XDG_RUNTIME_DIR=/tmp/xdg-runtime-$(id -u)-$$
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
eval $(dbus-launch --sh-syntax)
```
*(Note: This replaces the user-specific `~/.xsessionrc` fix from Revision 5).*

## 4. Systemd Socket & Service Configuration
Created a socket listening on VNC ports (5900 and 5901) with `Accept=yes` to spawn discrete connections.
```ini
# /etc/systemd/system/xvnc.socket
[Unit]
Description=XVNC Server Socket
[Socket]
ListenStream=5900
ListenStream=5901
Accept=yes
[Install]
WantedBy=sockets.target
```

Created the templated service that the socket launches to route the graphics back over the active socket from the LightDM greeter.
```ini
# /etc/systemd/system/xvnc@.service
[Unit]
Description=XVNC Per-Connection Daemon
[Service]
ExecStart=-/usr/bin/Xvnc -inetd -query localhost -geometry 1920x1080 -once -SecurityTypes=None
User=nobody
StandardInput=socket
StandardError=syslog
```

## 5. Deployment & Verification
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now xvnc.socket
sudo iptables -F
sudo iptables -P INPUT ACCEPT
```

## 6. Client Configuration (Mac RealVNC Viewer)
*   **Connecting:** Connect to `192.168.200.138:5900` or `192.168.200.138:5901`. 
*   **Visual Quality:** To prevent color bleeding and chroma subsampling artifacts (blurriness), open connection **Properties** -> **Options** -> Change **Picture quality** from "Automatic" to **High**.

---
<div style="text-align: right; font-size: 12px; color: gray;">Page 1</div>
*   **Update 12:** Major architectural redesign (Version 2.0.0). Eliminated the legacy `dbus-x11` package completely to mathematically bypass fractured upstream repositories (like Kali/Ubuntu Noble). The script now intercepts the X11 pipeline globally using `dbus-run-session` built into the core OS.
