# Technitium DNS Server — Post-Install Configuration

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Tested on: Proxmox VE 8.x / 9.x · Debian 13 (Trixie)

## Overview

Configures a **Technitium DNS Server** LXC that has already been deployed. This script handles everything after the container is running: admin account creation, recursion, forwarders, zone creation, and RFC 2136 dynamic update setup — all via the Technitium HTTP API.

## How to Use

**Step 1 — Deploy the Technitium DNS LXC**

From your Proxmox VE shell, follow the community-scripts installer:

```
https://community-scripts.org/scripts?id=technitiumdns
```

**Step 2 — Run this script to configure it**

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

## What It Configures

- Creates the admin account via the Technitium API
- Enables recursion (Allow All)
- Sets upstream forwarders (default: `1.1.1.1`, `9.9.9.9`)
- Creates your primary internal zone (e.g. `home.vanauken.tech`)
- Creates any additional zones you specify
- Enables RFC 2136 dynamic DNS updates on all zones

## Inputs Prompted

| Prompt | Default | Description |
|--------|---------|-------------|
| LXC IP | — | IP address of the Technitium LXC |
| Admin username | `admin` | Username for the DNS admin account |
| Admin password | — | Password (confirmed, hidden input) |
| Primary zone | — | Your main internal zone name |
| Additional zones | — | Optional extra zones (comma-separated) |
| Forwarders | `1.1.1.1,9.9.9.9` | Upstream DNS resolvers |
| RFC 2136 | `Y` | Enable dynamic updates on all zones |

---
*Van Auken Tech · Thomas Van Auken*
