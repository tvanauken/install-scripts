# Nginx Proxy Manager — Post-Install Configuration

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Tested on: Proxmox VE 8.x / 9.x · Debian 12 (Bookworm)

## Overview

Configures an **Nginx Proxy Manager** LXC that has already been deployed. This script handles everything after the container is running: admin account creation, authentication, and wildcard SSL certificate import — all via the NPM HTTP API.

## How to Use

**Step 1 — Deploy the Nginx Proxy Manager LXC**

From your Proxmox VE shell, follow the community-scripts installer:

```
https://community-scripts.org/scripts?id=nginxproxymanager
```

**Step 2 — Run this script to configure it**

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

## What It Configures

- Creates the admin account via the NPM API
- Authenticates and acquires an API token
- Imports a wildcard SSL certificate (optional — provide `.crt` and `.key` file paths)

## Inputs Prompted

| Prompt | Default | Description |
|--------|---------|-------------|
| LXC IP | — | IP address of the NPM LXC |
| Admin full name | `Administrator` | Display name for the admin account |
| Admin email | — | Email address for login |
| Admin password | — | Password (confirmed, hidden input) |
| Path to .crt | — | Wildcard cert file path (optional) |
| Path to .key | — | Private key file path (optional) |
| Cert name | `Wildcard Certificate` | Friendly label for the cert in NPM |

---
*Van Auken Tech · Thomas Van Auken*
