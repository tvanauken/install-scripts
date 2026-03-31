# Technitium DNS Server — LXC Installer for Proxmox VE

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Tested on: Proxmox VE 8.x / 9.x · Debian 13 (Trixie)

## Overview

Deploys a **Technitium DNS Server** LXC container on Proxmox VE using the [Proxmox VE Community Scripts](https://community-scripts.org/scripts?id=technitiumdns). Wraps the community installer in the Van Auken Tech visual standard — preflight checks, container spec preview, post-install guidance, and a full completion summary.

Technitium DNS is a privacy-focused, open-source DNS server with a web UI. It supports recursive resolution, split-horizon DNS, authoritative zones, DoH/DoT, DNSSEC, blocklists, and RFC 2136 dynamic updates — making it ideal as the internal DNS backbone for a self-hosted homelab or enterprise home network.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

## What It Does

1. **Preflight** — verifies root access, Proxmox VE host, internet connectivity, and curl
2. **Spec preview** — displays LXC default settings before launching the community script
3. **Deploy** — executes the community script which creates and fully configures the LXC container
4. **Post-install guide** — prints first-run configuration steps with web UI access URL
5. **Summary** — prints completion block with log path and timestamp

## Default LXC Specifications

| Setting | Value |
|---------|-------|
| OS | Debian 13 (Trixie) |
| CPU | 1 vCPU |
| RAM | 512 MB |
| Disk | 2 GB |
| Web UI | http://\<LXC-IP\>:5380 |

> Advanced mode is available during the community script prompt to customise CPU, RAM, disk, and network settings.

## Post-Install First Steps

- Open `http://<LXC-IP>:5380` and create the admin account
- Enable recursion: **Settings → Recursion** → Enable + add root hints
- Add internal DNS zones: **Zones → Add Zone**
- Add A / CNAME / PTR records for internal hosts
- Point all DHCP clients to the LXC IP as their DNS server

---
*Van Auken Tech · Thomas Van Auken*
