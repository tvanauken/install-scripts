# Raspberry Pi VNC Multi-Session Installer — Engineering Specifications

**Author: Thomas Van Auken — Van Auken Tech**
**Version: 2.0.2**

<div style="background-color: #e3f2fd; border-left: 6px solid #1976d2; padding: 15px;">
<strong>Purpose:</strong> Complete engineering specification detailing the architecture of the headless RealVNC-compatible server deployed on Raspberry Pi (Kali/Debian/Ubuntu).
</div>

## 1. Core Architecture (Systemd Sockets + XDMCP)
Unlike traditional `vncserver` wrappers that lock a single display to a single port, this deployment utilizes an on-demand socket activator to function identically to a Citrix or RDP Terminal Server.
- Systemd intercepts incoming TCP 5900 traffic via `xvnc.socket` (`Accept=yes`).
- Systemd spawns an isolated `Xtigervnc` (or `Xvnc`) process for every connection.
- `Xtigervnc` is explicitly commanded (`-query localhost`) to route graphics to the local `LightDM` greeter over UDP 177 (XDMCP).
- Authentication is strictly handled by LightDM/PAM, stripping the need for weak VNC-level passwords (`-SecurityTypes=None`).

## 2. Display Manager Configuration
LightDM is deployed as the central session manager. 
- **Headless Optimization:** The local physical display is permanently disabled (`start-default-seat=false`) preventing the X server from crashing on Raspberry Pis with no attached monitors.
- **Greeter Mapping:** The interface is explicitly locked to `lightdm-gtk-greeter` to prevent raw X11 fallback rendering.
- **Session Mapping:** The target desktop is hardcoded (`user-session=xfce`) ensuring successful handoff post-authentication.

```ini
# /etc/lightdm/lightdm.conf.d/50-xdmcp.conf
[LightDM]
start-default-seat=false

[XDMCPServer]
enabled=true
port=177

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
```

## 3. Global Same-User Concurrency
Modern Linux desktop environments natively reject secondary concurrent sessions by the exact same user, as `systemd-logind` and D-Bus lock the active session bus.
To bypass this limitation and allow unlimited simultaneous logins by the identical user, the global X11 initialization pipeline is intercepted.

A script injected into `/etc/X11/Xsession.d/99-isolate-dbus-runtime` mathematically sandboxes the environment per-connection:
- Generates an isolated `XDG_RUNTIME_DIR` using the session's exact Process ID (`$$`).
- Wraps the desktop execution sequence in `dbus-run-session`, creating a private D-Bus instance for every VNC window.
- Eliminates legacy `dbus-x11` dependencies entirely.

## 4. Execution Flow & Validation
The automated script enforces absolute deployment perfection:
1. **Pre-Flight Validation:** Strictly verifies OS derivative (Debian/Ubuntu/Kali) and executes an `apt-get -s` dry-run. If upstream repositories are fractured, the script halts instantly.
2. **Debconf Seeding:** Pre-seeds LightDM to guarantee zero interactive prompts during `apt-get` execution.
3. **Dynamic Binary Mapping:** The systemd `ExecStart` block utilizes a bash wrapper to dynamically execute `/usr/bin/Xtigervnc` or `/usr/bin/Xvnc` based on the specific Debian derivative's filesystem.
4. **Universal Firewall Configuration:** Detects and configures `ufw`, `firewalld`, or `iptables` autonomously.
5. **Post-Flight Validation:** Mathematically verifies `dpkg-query` statuses, executable paths, and `ss -tln` / `ss -uln` listeners before declaring the installation complete.

---
<div style="text-align: right; font-size: 12px; color: gray;">Page 1</div>
