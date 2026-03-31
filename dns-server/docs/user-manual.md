# Technitium DNS Server — User Manual

> Created by: Thomas Van Auken — Van Auken Tech
> Version: 1.1.0
> Date: 2026-03-31

---

## Table of Contents

1. [Overview](#1-overview)
2. [How This Script Works](#2-how-this-script-works)
3. [Prerequisites](#3-prerequisites)
4. [Step 1 — Install the LXC from Community Scripts](#4-step-1--install-the-lxc-from-community-scripts)
5. [Step 2 — Run the Configuration Script](#5-step-2--run-the-configuration-script)
6. [Configuration Prompts Explained](#6-configuration-prompts-explained)
7. [What the Script Configures](#7-what-the-script-configures)
8. [After the Script — Adding DNS Records](#8-after-the-script--adding-dns-records)
9. [Pointing DHCP Clients to Technitium](#9-pointing-dhcp-clients-to-technitium)
10. [Maintenance and Updates](#10-maintenance-and-updates)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This script configures a **Technitium DNS Server** LXC container that has already been deployed on Proxmox VE. It connects to the Technitium HTTP API and performs all post-install setup automatically:

- Creates the admin account
- Enables recursive DNS resolution
- Configures upstream forwarders
- Creates your internal DNS zones
- Enables RFC 2136 dynamic DNS updates

Technitium DNS is a free, open-source, privacy-focused DNS server with a web UI. It is ideal as the internal DNS backbone for a split-horizon home network or enterprise homelab.

---

## 2. How This Script Works

The script communicates with Technitium exclusively through its HTTP REST API. No SSH into the LXC is required. The script runs from any machine with network access to the LXC IP on port 5380 — typically the Proxmox VE host shell.

**API endpoints used:**

| Action | Endpoint |
|--------|----------|
| Create admin account | `POST /api/user/createAccount` |
| Login / get token | `POST /api/user/login` |
| Set recursion + forwarders | `POST /api/settings/set` |
| Create zone | `POST /api/zones/create` |
| Enable RFC 2136 on zone | `POST /api/zones/options/set` |

---

## 3. Prerequisites

| Requirement | Details |
|-------------|----------|
| Proxmox VE | 8.x or 9.x |
| Technitium DNS LXC | Already deployed and running (see Step 1) |
| Port 5380 | Must be reachable from the machine running this script |
| Root access | Script must run as root |
| Internet | Required to auto-install `curl` and `jq` if not present |

---

## 4. Step 1 — Install the LXC from Community Scripts

Before running this script, the Technitium DNS LXC must be deployed.

1. Log in to your Proxmox VE web UI at `https://<PVE-IP>:8006`
2. Navigate to your node → click **Shell**
3. Go to: **https://community-scripts.org/scripts?id=technitiumdns**
4. Copy the install command and run it in the Proxmox shell
5. Follow the prompts — choose **Default** or **Advanced** (Advanced lets you set a static IP, which is recommended)
6. Wait for the LXC to be created and started
7. Note the LXC IP address shown at the end of the community script

**Default LXC specs created by the community script:**

| Setting | Value |
|---------|-------|
| OS | Debian 13 (Trixie) |
| CPU | 1 vCPU |
| RAM | 512 MB |
| Disk | 2 GB |
| Web UI | http://\<LXC-IP\>:5380 |

---

## 5. Step 2 — Run the Configuration Script

Once the LXC is running, execute the following from a root shell with network access to the LXC:

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

The script will walk you through all configuration interactively.

---

## 6. Configuration Prompts Explained

When the script starts, it displays the following prompt section:

```
── Configuration ───────────────────────────────────────────

  About admin credentials:

  [▸]  Fresh install (web UI never opened):
        Enter the username and password you WANT to create.
        This script creates the account via the API automatically.

  [▸]  Already completed the web UI setup wizard:
        Enter the username and password you already set up.
        The script will skip account creation and log in directly.
```

### Prompt Details

**Technitium LXC IP address**
The IP address of the Technitium LXC container. This is shown at the end of the community script installation. Example: `172.16.250.8`

**Admin username** (default: `admin`)
The username for the Technitium administrator account. If this is a fresh install, the script creates this account. If you already went through the web UI, enter the username you set there.

**Admin password**
Entered twice for confirmation. Input is hidden. Used to create the account (fresh install) or to log in (existing account).

**Primary internal zone**
The main DNS zone Technitium will be authoritative for internally. Example: `home.vanauken.tech`

**Additional zones** (optional)
Comma-separated list of extra zones to create. Example: `mgmt.home.vanauken.tech,iot.home.vanauken.tech`
Press Enter to skip.

**Upstream forwarders** (default: `1.1.1.1,9.9.9.9`)
Comma-separated list of upstream DNS resolvers for queries that do not match a local zone. Defaults to Cloudflare and Quad9.

**Enable RFC 2136 dynamic updates** (default: `Y`)
Enables dynamic DNS updates on all zones. Required if you want a DHCP server or sync script to register hostnames automatically.

---

## 7. What the Script Configures

### Admin Account

On a fresh Technitium installation, no accounts exist. The script calls `POST /api/user/createAccount` to create the admin account before any other API calls are possible.

If the account already exists (you completed the web UI wizard), the creation call returns an error. The script detects this, shows `Account already exists — logging in with provided credentials`, and proceeds normally.

### Recursion

Sets `recursion=AllowAll` — Technitium will resolve any domain name for any client, not just those in local zones. This is appropriate for an internal-only DNS server.

### Forwarders

Sets upstream DNS resolvers. When Technitium receives a query for a domain that is not in any local zone (e.g., `google.com`), it forwards the query to these servers. Defaults: `1.1.1.1` (Cloudflare) and `9.9.9.9` (Quad9).

### Zones

Creates Primary zones for your primary zone and any additional zones specified. A Primary zone means Technitium is the authoritative source for that domain internally — it answers queries for hostnames in that zone from its own records.

### RFC 2136 Dynamic Updates

Enables `allowDynamicUpdates=true` on every created zone. This allows external systems (DHCP servers, sync scripts) to push DNS record updates to Technitium automatically without manual intervention.

---

## 8. After the Script — Adding DNS Records

The script creates the zones but does not add individual host records. You add those through the Technitium web UI.

1. Open `http://<LXC-IP>:5380` and log in
2. Click **Zones** in the top menu
3. Click your zone name
4. Click **Add Record**
5. Select record type:
   - **A** — hostname to IPv4 address
   - **CNAME** — hostname alias to another hostname
   - **PTR** — reverse lookup (IP to hostname)
6. Fill in the name and value, click **Add Record**

**Example records:**

| Name | Type | Value |
|------|------|-------|
| zeus | A | 172.16.250.8 |
| hermes | A | 172.16.250.9 |
| npm | CNAME | hermes |
| *.home | CNAME | hermes |

---

## 9. Pointing DHCP Clients to Technitium

For internal clients to use Technitium, they must receive the LXC IP as their DNS server via DHCP.

### UniFi Network

1. Log in to the UniFi Network Application
2. Go to **Settings → Networks**
3. Edit each VLAN/network
4. Under **DHCP**, set DNS Server to **Manual** and enter the Technitium LXC IP
5. Save and apply

Clients will use the new DNS server on their next DHCP lease renewal.

### Other DHCP Servers

Set DHCP option 6 (DNS Server) to the Technitium LXC IP in your DHCP server configuration.

---

## 10. Maintenance and Updates

### Updating Technitium

From the Proxmox shell, enter the LXC console and run the built-in update command:

```bash
pct enter <CTID>
update
```

### Backing Up

Technitium stores all configuration in `/etc/dns/` inside the LXC. Back up this directory:

```bash
tar czf technitium-backup-$(date +%Y%m%d).tar.gz /etc/dns/
```

### Log Files

- Technitium query logs: visible in the web UI under **Logs**
- Configuration script log: `/var/log/dns-server-config-<timestamp>.log` on the host that ran the script

---

## 11. Troubleshooting

### Script Cannot Reach Technitium

- Verify the LXC is running: `pct status <CTID>` on the Proxmox host
- Confirm port 5380 is listening inside the LXC: `pct exec <CTID> -- netstat -tulnp | grep 5380`
- Ensure no firewall rule blocks port 5380 between the script host and LXC

### Authentication Failed

- If you already set up an account via the web UI, make sure you entered exactly those credentials at the prompt
- Passwords are case-sensitive
- Check `/var/log/dns-server-config-<timestamp>.log` for the raw API response

### Zone Creation Warning

- If a zone already exists (e.g., you ran the script twice), the API returns an error but the script continues — existing zones are not modified

### DNS Not Resolving on Clients

- Confirm clients have the LXC IP as their DNS server (check DHCP lease)
- Test directly: `dig @<LXC-IP> <hostname>`
- Check Technitium query logs in the web UI
- Confirm recursion is enabled: **Settings → Recursion**

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
