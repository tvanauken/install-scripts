# Nginx Proxy Manager — Installation Scripts

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 3.0.0  
> Tested on: Ubuntu 22.04+, Debian 12+, Proxmox VE 8.x/9.x

---

## Scripts Available

### 1. Full Installation Script (Recommended)
**Script:** [`nginx-proxy-manager-install.sh`](nginx-proxy-manager-install.sh)

Installs NPM natively (no Docker) with wildcard SSL certificate.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/nginx-proxy-manager-install.sh)
```

**Features:**
- **Native installation** using OpenResty (no Docker)
- Requests wildcard Let's Encrypt certificate (Cloudflare DNS challenge)
- Imports certificate to NPM automatically
- Configures firewall (UFW/firewalld)

### 2. Post-Install Configuration Script
**Script:** [`npm-reverse-proxy-install.sh`](npm-reverse-proxy-install.sh)

For use when NPM is already installed (e.g., via community-scripts.org).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

---

## How It Works

1. External user requests `https://anyname.home.example.com`
2. Public DNS resolves to NPM server IP
3. NPM matches the hostname to a configured proxy host
4. Wildcard certificate validates the connection
5. Request is proxied to the backend server

---

## Adding a Proxy Host

1. Open NPM Web UI → **Hosts** → **Proxy Hosts** → **Add**
2. **Domain Names:** `anyname.home.example.com`
3. **Forward Hostname/IP:** backend server IP
4. **Forward Port:** backend service port
5. **SSL tab:** Select the wildcard certificate
6. Enable **Force SSL** and **HTTP/2 Support**
7. **Save**

---

## Configuration Prompts

| Setting | Description | Example |
|---------|-------------|--------|
| Server IP | This server's IP | `172.16.250.9` |
| Admin email | NPM login email | `admin@example.com` |
| Admin password | Min 8 characters | (secure) |
| Wildcard domain | For SSL cert | `home.example.com` |
| Cloudflare API token | Zone:DNS:Edit | (token) |

---

## DNS Setup

Create an A record for each service you want to proxy:

```
anyname.home.example.com  A  <NPM-PUBLIC-IP>
```

The wildcard certificate covers `*.home.example.com`, so any subdomain works.

---

## Integration

Use with the [Technitium DNS installer](../dns-server/) for internal DNS resolution.

---
*Van Auken Tech · Thomas Van Auken*
