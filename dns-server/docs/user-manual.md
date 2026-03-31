# Technitium DNS Server — User Manual

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Date: 2026-03-31

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Running the Installer](#4-running-the-installer)
5. [Initial Web UI Configuration](#5-initial-web-ui-configuration)
6. [Enabling Recursive Resolution](#6-enabling-recursive-resolution)
7. [Creating Authoritative Zones](#7-creating-authoritative-zones)
8. [Split-Horizon DNS](#8-split-horizon-dns)
9. [RFC 2136 Dynamic DNS Updates](#9-rfc-2136-dynamic-dns-updates)
10. [Blocklists and Filtering](#10-blocklists-and-filtering)
11. [DNS over HTTPS and TLS](#11-dns-over-https-and-tls)
12. [Pointing Clients to Technitium DNS](#12-pointing-clients-to-technitium-dns)
13. [Maintenance and Updates](#13-maintenance-and-updates)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Overview

Technitium DNS Server is a free, open-source, privacy-focused DNS server that runs on Linux, Windows, and macOS. This installer deploys it as a lightweight Proxmox VE LXC container using the official [Proxmox VE Community Scripts](https://community-scripts.org/scripts?id=technitiumdns).

Key capabilities relevant to a Van Auken Tech homelab deployment:

- **Recursive resolver** — forwards queries to root servers or upstream resolvers (e.g., Cloudflare, Quad9)
- **Authoritative zones** — hosts internal zones (e.g., `home.vanauken.tech`) with full record control
- **Split-horizon DNS** — resolves the same domain to different IPs depending on whether the client is internal or external
- **RFC 2136 dynamic updates** — accepts DNS updates from DHCP servers dynamically
- **Blocklists** — network-wide ad and malware domain blocking
- **DoH / DoT** — encrypted upstream resolution
- **DNSSEC validation** — cryptographic zone integrity verification
- **Web UI** — full management via browser at port 5380

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Proxmox VE Host                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Technitium DNS LXC Container               │    │
│  │                                                         │    │
│  │   • Listens on UDP/TCP 53 (DNS)                         │    │
│  │   • Listens on TCP 5380 (Web UI)                        │    │
│  │   • Authoritative for internal zones                    │    │
│  │   • Recursive resolver for external queries             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

  Internal clients  ──►  LXC:53 (DNS)  ──►  Internal zones (authoritative)
                                        ──►  Root / Upstream (recursive)

  Admin browser     ──►  LXC:5380 (Web UI)
```

**DNS Query Flow:**

1. Client sends DNS query to Technitium LXC IP
2. Technitium checks if the query matches a locally authoritative zone
   - Match → returns the authoritative answer from the local zone
   - No match → forwards to configured upstream resolver or root servers
3. Result is cached and returned to the client

---

## 3. Prerequisites

| Requirement | Details |
|-------------|----------|
| Proxmox VE | Version 8.x or 9.x, running on the host |
| Root access | Script must run as root in the Proxmox VE shell |
| Internet | Required during install to pull the community script and container image |
| LXC storage | At least 2 GB available on your Proxmox storage pool |
| IP address | A static IP reserved for the DNS LXC (recommended) |

---

## 4. Running the Installer

### Step 1 — Open the Proxmox VE Shell

Log in to your Proxmox VE web UI at `https://<PVE-IP>:8006`. Navigate to your node in the left panel, then click **Shell**.

### Step 2 — Run the Script

Paste and execute the following command in the Proxmox shell:

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/dns-server/dns-server-install.sh)
```

### Step 3 — Preflight Phase

The script will:
- Verify it is running as root
- Confirm it is on a Proxmox VE host
- Check internet connectivity
- Ensure `curl` is available

### Step 4 — Spec Preview

Before launching the community script, the installer displays the default LXC specifications:

| Setting | Default |
|---------|----------|
| OS | Debian 13 (Trixie) |
| CPU | 1 vCPU |
| RAM | 512 MB |
| Disk | 2 GB |
| Web UI Port | 5380 |

### Step 5 — Community Script Prompt

The community script launches and presents an interactive menu:

- **Default** — accepts all defaults, creates the container immediately
- **Advanced** — allows you to customise CPU, RAM, disk size, container ID, storage pool, bridge, hostname, and IP assignment (DHCP or static)

> **Recommendation:** Use **Advanced** mode and assign a static IP for the DNS container so DHCP clients always have a stable DNS target.

### Step 6 — Container Creation

The community script will:
1. Download the Debian 13 LXC template
2. Create and start the LXC container
3. Install .NET runtime and Technitium DNS inside the container
4. Enable and start the `technitium-dns` systemd service
5. Print the container IP address and web UI URL

### Step 7 — Post-Install Summary

After the community script completes, the Van Auken Tech wrapper prints:
- Post-install configuration steps
- Web UI access URL
- Log file location
- Completion summary block

---

## 5. Initial Web UI Configuration

### Accessing the Web UI

Open a browser and navigate to:

```
http://<Technitium-LXC-IP>:5380
```

### First Login

On first access, Technitium prompts you to create an administrator account:

1. Enter a **username** (e.g., `admin`)
2. Enter a strong **password**
3. Click **Create Account**

You will be logged in to the Technitium web dashboard.

### Dashboard Overview

The dashboard provides:
- **Query Logs** — real-time DNS query monitoring
- **Statistics** — query counts, block rates, top domains
- **Zones** — authoritative zone management
- **Settings** — server configuration
- **Blocklists** — domain blocking lists
- **Apps** — DNS app plugins (DoH, blocklist sources, etc.)

---

## 6. Enabling Recursive Resolution

For Technitium to resolve external domains (anything not in a local zone), recursion must be configured.

### Steps

1. In the web UI, navigate to **Settings**
2. Click the **Recursion** tab
3. Set **Recursion** to **Allow All** (for internal use) or configure allowed networks
4. Under **Forwarders**, add upstream resolvers if you prefer forwarding over full recursion:
   - `1.1.1.1` — Cloudflare
   - `9.9.9.9` — Quad9 (malware blocking)
   - `8.8.8.8` — Google
5. To use **full root recursion** (no forwarders), leave Forwarders empty and enable **Use Root Servers**
6. Click **Save Settings**

> For a split-horizon setup, full root recursion is recommended so external DNS answers are never influenced by a third-party forwarder for your own domain.

---

## 7. Creating Authoritative Zones

Authoritative zones allow Technitium to be the definitive source of DNS answers for your internal domain names.

### Adding a Zone

1. Navigate to **Zones** in the top menu
2. Click **Add Zone**
3. Enter the zone name (e.g., `home.vanauken.tech`)
4. Select **Primary Zone** as the zone type
5. Click **Add**

### Adding Records to a Zone

1. Click the zone name to open it
2. Click **Add Record**
3. Select the record type:
   - **A** — IPv4 address record (hostname → IP)
   - **AAAA** — IPv6 address record
   - **CNAME** — canonical name alias (hostname → hostname)
   - **PTR** — reverse lookup (IP → hostname)
   - **MX** — mail exchanger
   - **TXT** — text records (SPF, DKIM, ACME challenges)
4. Fill in the record name and value
5. Click **Add Record**

### Example Records

| Name | Type | Value | Purpose |
|------|------|-------|---------|
| zeus | A | 172.16.250.8 | DNS server |
| hermes | A | 172.16.250.9 | Reverse proxy |
| npm | CNAME | hermes | Alias for NPM UI |
| *.home | CNAME | hermes | Wildcard to reverse proxy |

---

## 8. Split-Horizon DNS

Split-horizon DNS returns different answers for the same domain depending on the client's network location:

- **Internal clients** → resolve `service.home.vanauken.tech` to the private IP of the reverse proxy
- **External clients** → resolve the same name to the public IP (via GoDaddy/No-IP)

### How It Works in This Setup

1. Technitium is authoritative for `home.vanauken.tech` internally
2. Records in the local zone point to private IPs (e.g., `172.16.x.x`)
3. Internal clients query Technitium → get private IP answers
4. External clients never reach Technitium; they query GoDaddy's public DNS → get CNAME to No-IP DDNS

### Configuration

No special Technitium configuration is required beyond:
- Creating the internal zone with private IP records
- Ensuring all internal DHCP clients use Technitium as their DNS server
- Ensuring the external DNS (GoDaddy) has the correct CNAME records pointing to your dynamic DNS hostname

---

## 9. RFC 2136 Dynamic DNS Updates

RFC 2136 allows DHCP servers and other clients to push DNS record updates directly to Technitium without manual intervention.

### Enabling RFC 2136 on a Zone

1. Open the zone in the Zones view
2. Click **Zone Options** (gear icon)
3. Enable **Allow Dynamic Updates**
4. Optionally restrict which IPs may send updates using a TSIG key or IP allowlist
5. Save

### Use Case

If your DHCP server (e.g., UniFi) supports RFC 2136 dynamic DNS, it will automatically register client hostnames in your Technitium zones when leases are granted. This eliminates the need for manual A record management as devices join the network.

> As of 2026, UniFi does not natively support RFC 2136. A polling script can be used as an alternative — see the Van Auken Tech infrastructure documentation.

---

## 10. Blocklists and Filtering

Technitium supports network-wide DNS-based ad and malware blocking via blocklist subscriptions.

### Adding a Blocklist

1. Navigate to **Blocklists** in the top menu
2. Click **Add Blocklist**
3. Enter the URL of a blocklist source, for example:
   - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
   - `https://blocklistproject.github.io/Lists/malware.txt`
4. Set the update interval (e.g., `1 day`)
5. Click **Save**

### Enabling Blocking

1. Navigate to **Settings → Blocking**
2. Enable **Blocking**
3. Select your blocking type (NxDomain, No Data, or Custom IP)
4. Click **Save Settings**

---

## 11. DNS over HTTPS and TLS

For encrypted upstream resolution (recommended for privacy):

1. Navigate to **Settings → Forwarders**
2. Enable **Use Forwarders**
3. Add DoH forwarders using the `https://` prefix:
   - `https://cloudflare-dns.com/dns-query` (Cloudflare)
   - `https://dns.quad9.net/dns-query` (Quad9)
4. Click **Save Settings**

For DoT (DNS over TLS):
- Enter forwarder addresses prefixed with `tls://`:
  - `tls://1.1.1.1`
  - `tls://9.9.9.9`

---

## 12. Pointing Clients to Technitium DNS

For internal clients to use Technitium, they must receive the LXC IP as their DNS server via DHCP.

### UniFi Network — VLAN DHCP DNS

1. Log in to the UniFi Network Application
2. Navigate to **Settings → Networks**
3. For each VLAN, click **Edit**
4. Under **DHCP**, set **DNS Server** to **Manual**
5. Enter the Technitium LXC IP (e.g., `172.16.250.8`)
6. Save and apply

Clients will receive the new DNS server on their next DHCP renewal. To force immediate update, clients can run `ipconfig /renew` (Windows) or `sudo dhclient -r && sudo dhclient` (Linux).

### Other DHCP Servers

Look for the **DNS Server** option (DHCP option 6) in your DHCP server configuration and set it to the Technitium LXC IP.

---

## 13. Maintenance and Updates

### Updating Technitium DNS

To update Technitium inside the LXC:

1. In the Proxmox VE shell, enter the LXC console:
   ```bash
   pct enter <CTID>
   ```
2. Run the update command:
   ```bash
   update
   ```
   This executes the community script's built-in update mechanism.

### Backing Up

Technitium stores all configuration and zone data in `/etc/dns/`. Back up this directory regularly:

```bash
tar czf technitium-backup-$(date +%Y%m%d).tar.gz /etc/dns/
```

### Log Files

- Technitium logs: accessible via the web UI under **Logs**
- Install script log: `/var/log/dns-server-install-<timestamp>.log` on the Proxmox host

---

## 14. Troubleshooting

### DNS Not Resolving

- Verify the Technitium service is running: `systemctl status technitium-dns` inside the LXC
- Check that port 53 is not blocked: `netstat -tulnp | grep :53`
- Confirm clients have the correct DNS IP assigned via DHCP

### Web UI Not Accessible

- Verify port 5380 is listening: `netstat -tulnp | grep :5380`
- Check firewall rules on the Proxmox host and VLAN
- Ensure the LXC IP is reachable from the client

### Zone Not Resolving Correctly

- Verify the zone exists: **Zones** in the web UI
- Confirm the record names and values are correct
- Use `dig @<LXC-IP> <hostname>` from a client to test directly against Technitium
- Check the **Query Logs** in the web UI to see if queries are being received

### Recursive Resolution Failing

- Confirm recursion is enabled: **Settings → Recursion**
- Test external resolution: `dig @<LXC-IP> google.com`
- Verify the LXC has outbound internet connectivity

---

*Created by: Thomas Van Auken — Van Auken Tech*  
*Repository: https://github.com/tvanauken/install-scripts*
