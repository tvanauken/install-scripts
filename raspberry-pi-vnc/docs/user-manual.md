# Raspberry Pi VNC Multi-Session Installer - User Manual

**Prepared for Thomas Van Auken - Van Auken Tech**
**Revision 6**

<div style="background-color: #e3f2fd; border-left: 6px solid #1976d2; padding: 15px;">
<strong>Overview:</strong> This user manual provides detailed instructions on how to connect to, use, and understand the Raspberry Pi Multi-Session VNC environment. It covers the architecture, connection steps, and visual configurations required for optimal operation.
</div>

## 1. Architectural Overview

The environment diverges from legacy VNC implementations. It uses an advanced XDMCP and systemd socket activation matrix to provide isolated, concurrent desktop sessions on-demand, much like an enterprise RDP server.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#00796b', 'edgeLabelBackground':'#ffffff', 'tertiaryColor': '#e0f7fa', 'primaryTextColor': '#ffffff'}}}%%
flowchart LR
    Client([RealVNC Client]) -->|Port 5900| Socket[[systemd xvnc.socket]]
    Socket -->|Spawns| Xvnc[(Xtigervnc Daemon)]
    Xvnc -->|UDP 177| LightDM([LightDM Greeter])
    LightDM -->|X11 Handoff| Xsession[[Xsession.d Isolation]]
    Xsession -->|Private D-Bus| XFCE([XFCE4 Desktop])
    
    style Client fill:#1976d2,stroke:#0d47a1,stroke-width:2px,color:#fff
    style XFCE fill:#388e3c,stroke:#1b5e20,stroke-width:2px,color:#fff
```

## 2. Establishing a Connection

<div style="background-color: #fff3e0; border-left: 6px solid #f57c00; padding: 15px;">
<strong>Authentication Note:</strong> Security is handled entirely by the native Kali Linux PAM stack. Weak VNC passwords have been bypassed.
</div>

1. Open **RealVNC Viewer** on your client machine.
2. In the address bar, enter the IP address or FQDN of your Raspberry Pi, followed by the VNC port. <br/>
   *Example: `192.168.200.138:5900`*
3. Hit **Enter**. You will immediately be presented with the **LightDM Graphical Login Screen**.
4. Log in using your standard Unix credentials (e.g., `tvanauken` / `VanAwsome1`).

## 3. Optimizing Display Quality

To ensure crystal-clear text, prevent chroma subsampling (color bleeding), and ensure the 96 DPI scaling aligns correctly with your physical monitor:
1. In RealVNC Viewer, right-click your saved connection and select **Properties**.
2. Navigate to the **Options** tab.
3. Change **Picture quality** from "Automatic" to **High**.
4. Click **OK** and reconnect.

## 4. Multi-User and Concurrent Sessions

This architecture natively supports enterprise-grade terminal sessions.
- **Multiple Users:** Different users can connect to `5900` simultaneously and will receive completely independent login screens and desktops.
- **Same User:** A single user (e.g., `tvanauken`) can connect multiple times simultaneously. The global isolation script ensures each connection receives a private `D-Bus` and `XDG_RUNTIME_DIR`, preventing session crashes.

---
<div style="text-align: right; font-size: 12px; color: gray;">Page 1</div>
