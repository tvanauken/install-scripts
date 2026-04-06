# Nginx Proxy Manager — Post-Install Configuration

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0

---

## Overview

Configures a fresh NPM LXC (installed via Proxmox community-scripts) with wildcard SSL certificate for reverse proxying internal services.

## Pre-requisites

1. **Fresh NPM LXC** via community-scripts:
   ```bash
   bash -c "$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts/nginxproxymanager.sh)"
   ```
2. **Cloudflare account** with API token (Zone:DNS:Edit permission)
3. **Root access** to the LXC

## Usage

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-configure.sh)
```

## What It Does

1. **Updates admin credentials** from default
2. **Requests wildcard certificate** via Cloudflare DNS challenge
3. **Imports certificate** to NPM as custom SSL
4. **Configures auto-renewal** (twice daily)

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| Admin email | NPM login | `admin@example.com` |
| Admin password | Min 8 characters | |
| Wildcard domain | Without the `*` | `home.example.com` |
| Cloudflare API token | Zone:DNS:Edit | (from Cloudflare) |

## Adding Proxy Hosts

After configuration, add services via NPM Web UI:

1. **Hosts** → **Proxy Hosts** → **Add**
2. **Domain Names:** `anyname.home.example.com`
3. **Forward Hostname/IP:** backend server IP
4. **Forward Port:** backend service port
5. **SSL tab:** Select your wildcard certificate
6. Enable **Force SSL** and **HTTP/2**
7. **Save**

## DNS Setup

For each service, create a public A record:

```
proxmox.home.example.com  A  <NPM-PUBLIC-IP>
grafana.home.example.com  A  <NPM-PUBLIC-IP>
```

The wildcard certificate covers all `*.home.example.com` subdomains.

## Integration

Use with the [DNS configuration script](../dns-server/) for internal name resolution.

---
*Van Auken Tech · Thomas Van Auken*