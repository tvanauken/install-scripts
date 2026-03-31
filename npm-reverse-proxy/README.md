# Nginx Proxy Manager — LXC Installer for Proxmox VE

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Tested on: Proxmox VE 8.x / 9.x · Debian 12 (Bookworm)

## Overview

Deploys an **Nginx Proxy Manager** LXC container on Proxmox VE using the [Proxmox VE Community Scripts](https://community-scripts.org/scripts?id=nginxproxymanager). Wraps the community installer in the Van Auken Tech visual standard — preflight checks, container spec preview, post-install guidance, and a full completion summary.

Nginx Proxy Manager (NPM) is a web-based reverse proxy manager backed by OpenResty/Nginx. It provides SSL certificate management (Let's Encrypt, wildcard, and custom certs), domain-to-service routing, access control lists, and HTTP/2 support — all managed through an intuitive web interface. No manual Nginx config editing required.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

## What It Does

1. **Preflight** — verifies root access, Proxmox VE host, internet connectivity, and curl
2. **Spec preview** — displays LXC default settings before launching the community script
3. **Deploy** — executes the community script which creates and fully configures the LXC container
4. **Post-install guide** — prints setup wizard steps and certbot plugin info
5. **Summary** — prints completion block with log path and timestamp

## Default LXC Specifications

| Setting | Value |
|---------|-------|
| OS | Debian 12 (Bookworm) |
| CPU | 2 vCPU |
| RAM | 2048 MB |
| Disk | 8 GB |
| Web UI | http://\<LXC-IP\>:81 |

> Advanced mode is available during the community script prompt to customise CPU, RAM, disk, and network settings.

## Post-Install First Steps

- Open `http://<LXC-IP>:81` and complete the admin account setup wizard
- Add **Proxy Hosts** to route domain names to backend services
- Request an **SSL certificate** via Let's Encrypt or upload a wildcard cert
- Enable **Force SSL** and **HTTP/2** on each proxy host
- Optionally install certbot DNS plugins: run `/app/scripts/install-certbot-plugins` inside the LXC

---
*Van Auken Tech · Thomas Van Auken*
