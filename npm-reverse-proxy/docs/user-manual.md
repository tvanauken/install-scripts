# Nginx Proxy Manager — User Manual

> Created by: Thomas Van Auken — Van Auken Tech  
> Version: 1.0.0  
> Date: 2026-03-31

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Running the Installer](#4-running-the-installer)
5. [Initial Web UI Setup](#5-initial-web-ui-setup)
6. [Adding a Proxy Host](#6-adding-a-proxy-host)
7. [SSL Certificate Management](#7-ssl-certificate-management)
8. [Wildcard Certificates](#8-wildcard-certificates)
9. [Access Lists](#9-access-lists)
10. [Streams (TCP/UDP Proxying)](#10-streams-tcpudp-proxying)
11. [Certbot DNS Plugins](#11-certbot-dns-plugins)
12. [Maintenance and Updates](#12-maintenance-and-updates)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Overview

Nginx Proxy Manager (NPM) is a web-based GUI for managing Nginx reverse proxy rules without writing Nginx configuration files manually. It uses **OpenResty** (Nginx + Lua) as its engine and provides:

- **Proxy Hosts** — route domain names to backend services (HTTP/HTTPS)
- **SSL Certificates** — automated Let's Encrypt issuance and renewal, plus custom cert uploads
- **Wildcard certificates** — single certificate covering all subdomains (e.g., `*.home.vanauken.tech`)
- **Access Lists** — IP or password-based access control per proxy host
- **Redirection Hosts** — HTTP → HTTPS redirects and domain forwarding
- **Streams** — raw TCP/UDP port proxying
- **404 Hosts** — catch-all for unmatched domains

This installer deploys NPM as a lightweight Proxmox VE LXC container using the [Proxmox VE Community Scripts](https://community-scripts.org/scripts?id=nginxproxymanager).

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Proxmox VE Host                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Nginx Proxy Manager LXC Container          │    │
│  │                                                         │    │
│  │   • OpenResty (Nginx) — HTTP :80 / HTTPS :443           │    │
│  │   • NPM Web UI — TCP :81                                │    │
│  │   • Certbot — Let's Encrypt certificate management      │    │
│  │   • SQLite — proxy host / cert / user database          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

  External client  ──►  :443 HTTPS  ──►  NPM  ──►  Backend service
  Internal client  ──►  :443 HTTPS  ──►  NPM  ──►  Backend service
  Admin browser    ──►  :81  HTTP   ──►  NPM Web UI
```

**Request Flow:**

1. Client sends HTTPS request for `service.home.vanauken.tech:443`
2. NPM receives the request and matches the hostname to a configured Proxy Host
3. NPM forwards the request to the backend service (e.g., `192.168.10.5:8080`)
4. Response is returned to the client with the NPM SSL certificate

The backend service never needs to handle SSL — NPM terminates all TLS connections.

---

## 3. Prerequisites

| Requirement | Details |
|-------------|----------|
| Proxmox VE | Version 8.x or 9.x, running on the host |
| Root access | Script must run as root in the Proxmox VE shell |
| Internet | Required during install for community script and container image |
| LXC storage | At least 8 GB available on your Proxmox storage pool |
| IP address | A static IP reserved for the NPM LXC (recommended) |
| DNS | A wildcard or specific DNS record pointing to the NPM LXC IP |
| Ports 80/443 | Must be reachable by clients (and forwarded from router if external access needed) |

---

## 4. Running the Installer

### Step 1 — Open the Proxmox VE Shell

Log in to your Proxmox VE web UI at `https://<PVE-IP>:8006`. Navigate to your node in the left panel, then click **Shell**.

### Step 2 — Run the Script

Paste and execute the following command in the Proxmox shell:

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
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
| OS | Debian 12 (Bookworm) |
| CPU | 2 vCPU |
| RAM | 2048 MB |
| Disk | 8 GB |
| Web UI Port | 81 |

### Step 5 — Community Script Prompt

The community script presents an interactive menu:

- **Default** — accepts all defaults, creates the container immediately
- **Advanced** — customise CPU, RAM, disk, container ID, storage pool, bridge, hostname, and IP assignment

> **Recommendation:** Use **Advanced** to assign a static IP to the NPM LXC. This is the IP your DNS wildcard record and port forwarding rules must point to.

### Step 6 — Container Creation

The community script will:
1. Download the Debian 12 LXC template
2. Create and start the LXC container
3. Build OpenResty from source inside the container
4. Install Node.js 22, Yarn, and NPM backend dependencies
5. Build the NPM frontend
6. Enable and start the `npm` and `openresty` systemd services
7. Print the container IP and web UI URL

### Step 7 — Post-Install Summary

After the community script completes, the Van Auken Tech wrapper prints:
- First-launch setup wizard steps
- Certbot plugin installation note
- Web UI access URL
- Log file location
- Completion summary block

---

## 5. Initial Web UI Setup

### Accessing the Web UI

Open a browser and navigate to:

```
http://<NPM-LXC-IP>:81
```

### Account Creation Wizard

On first launch, NPM guides you through creating the administrator account:

1. Enter your **full name**
2. Enter your **email address** (used for Let's Encrypt certificate notifications)
3. Enter a strong **password** and confirm it
4. Click **Save**

There are no default credentials — you create the admin account on first run.

### Dashboard Overview

After logging in, the NPM dashboard shows:

- **Proxy Hosts** — all configured reverse proxy rules
- **Redirection Hosts** — domain forwarding rules
- **Streams** — TCP/UDP port proxy rules
- **404 Hosts** — catch-all error host
- **SSL Certificates** — all managed certificates
- **Access Lists** — IP/password access control rules
- **Users** — NPM user accounts

---

## 6. Adding a Proxy Host

A Proxy Host maps an incoming domain name to a backend service.

### Steps

1. Click **Proxy Hosts** → **Add Proxy Host**
2. **Details tab:**
   - **Domain Names** — enter the fully qualified domain name (e.g., `npm.home.vanauken.tech`)
   - **Scheme** — `http` or `https` (the scheme to the backend, not the client)
   - **Forward Hostname / IP** — the backend service IP or hostname
   - **Forward Port** — the backend service port (e.g., `81`, `8080`, `3000`)
   - **Cache Assets** — enable for static content sites
   - **Block Common Exploits** — enable for all hosts
   - **Websockets Support** — enable if the backend uses websockets (e.g., Home Assistant)
3. **SSL tab:**
   - Select an existing certificate or request a new Let's Encrypt cert
   - Enable **Force SSL** — redirects HTTP to HTTPS
   - Enable **HTTP/2 Support** — improves performance
   - Enable **HSTS** — optional, enforces HTTPS in browsers
4. **Access List tab** (optional):
   - Attach an Access List to restrict who can reach this proxy host
5. Click **Save**

---

## 7. SSL Certificate Management

### Requesting a Let's Encrypt Certificate

1. Navigate to **SSL Certificates** → **Add SSL Certificate** → **Let's Encrypt**
2. Enter the domain name(s) — use a comma-separated list for multiple SANs
3. Enter the email address for expiry notifications
4. Select the challenge type:
   - **HTTP Challenge** — NPM must be reachable on port 80 from the internet
   - **DNS Challenge** — requires a DNS provider plugin (see Section 11)
5. Agree to the Let's Encrypt Terms of Service
6. Click **Save** — NPM requests the certificate and stores it automatically

### Certificate Auto-Renewal

NPM automatically renews Let's Encrypt certificates before they expire. No manual intervention is required. Renewal logs are visible in the NPM web UI under the certificate details.

### Uploading a Custom Certificate

1. Navigate to **SSL Certificates** → **Add SSL Certificate** → **Custom**
2. Enter a friendly name
3. Upload your certificate (`.crt` or `.pem`) and private key (`.key`)
4. If using a certificate chain, upload the intermediate certificate
5. Click **Save**

---

## 8. Wildcard Certificates

A wildcard certificate (e.g., `*.home.vanauken.tech`) covers all subdomains under a parent domain with a single certificate.

### Requirements

- A wildcard certificate **requires the DNS challenge** — it cannot be issued via HTTP challenge
- You need API access to your DNS provider (e.g., GoDaddy, Cloudflare, Route53) for automated DNS challenge
- Alternatively, you can complete the DNS challenge manually and upload the resulting certificate as a Custom certificate

### Manual Wildcard via acme.sh (Recommended for GoDaddy)

If the DNS provider does not have a working certbot plugin, use `acme.sh` on a separate machine:

```bash
# Install acme.sh
curl https://get.acme.sh | sh

# Request wildcard cert via manual DNS-01
~/.acme.sh/acme.sh --issue --dns --d '*.home.vanauken.tech' --d 'home.vanauken.tech' \
  --yes-I-know-dns-manual-mode-enough-go-ahead-please
```

Follow the instructions to add the TXT records to GoDaddy, then:

```bash
~/.acme.sh/acme.sh --renew --dns --d '*.home.vanauken.tech' \
  --yes-I-know-dns-manual-mode-enough-go-ahead-please
```

Upload the resulting `.crt` and `.key` files to NPM as a Custom certificate.

---

## 9. Access Lists

Access Lists allow you to restrict access to a Proxy Host by IP address or HTTP Basic Authentication.

### Creating an Access List

1. Navigate to **Access Lists** → **Add Access List**
2. Enter a name (e.g., `Internal Only`)
3. **Authorization tab** — optionally add username/password pairs for Basic Auth
4. **Access tab**:
   - **Allow** — add IP ranges that are permitted (e.g., `192.168.0.0/16`, `172.16.0.0/12`)
   - **Deny** — add IPs that should be blocked
   - Enable **Satisfy Any** if you want either IP allowlist OR password auth to grant access
5. Click **Save**

### Applying an Access List

When creating or editing a Proxy Host, select the Access List in the **Access List** tab.

---

## 10. Streams (TCP/UDP Proxying)

Streams allow raw TCP or UDP port forwarding without HTTP — useful for non-HTTP services.

### Adding a Stream

1. Navigate to **Streams** → **Add Stream**
2. Enter the **Incoming Port** (the port NPM listens on)
3. Enter the **Forward Host** and **Forward Port** (the backend service)
4. Select **TCP** or **UDP**
5. Click **Save**

---

## 11. Certbot DNS Plugins

For DNS challenge certificate issuance (required for wildcard certs with supported providers), certbot DNS plugins can be installed inside the NPM LXC.

### Installing Common Plugins

Enter the NPM LXC console from Proxmox:

```bash
pct enter <CTID>
```

Then run the plugin installer script:

```bash
/app/scripts/install-certbot-plugins
```

This installs plugins for common providers including Cloudflare, Route53, DigitalOcean, Linode, and others.

> **Note:** Not all providers are included. Some plugins require additional system packages that must be installed manually. Consult the specific plugin's documentation for requirements.

### GoDaddy

As of 2026, there is no official certbot-dns-godaddy plugin in wide distribution. Use the manual `acme.sh` method described in Section 8 to obtain wildcard certificates for GoDaddy-managed domains.

---

## 12. Maintenance and Updates

### Updating Nginx Proxy Manager

To update NPM inside the LXC:

1. From the Proxmox VE shell, enter the LXC console:
   ```bash
   pct enter <CTID>
   ```
2. Run the update command:
   ```bash
   update
   ```

### Backing Up

All NPM data is stored in `/data/`. Back up this directory to preserve proxy rules, certificates, access lists, and the database:

```bash
tar czf npm-backup-$(date +%Y%m%d).tar.gz /data/
```

### Log Files

- NPM logs: `/data/logs/` inside the LXC
- Nginx/OpenResty access and error logs: `/var/log/nginx/` inside the LXC
- Install script log: `/var/log/npm-reverse-proxy-install-<timestamp>.log` on the Proxmox host

### Checking Service Status

Inside the LXC:

```bash
systemctl status npm
systemctl status openresty
```

---

## 13. Troubleshooting

### Web UI Not Accessible

- Verify the `npm` service is running: `systemctl status npm` inside the LXC
- Confirm port 81 is listening: `netstat -tulnp | grep :81`
- Check that the LXC IP is reachable from the client network

### HTTPS Not Working / Certificate Errors

- Verify the `openresty` service is running: `systemctl status openresty`
- Confirm port 443 is listening: `netstat -tulnp | grep :443`
- Check that the DNS record for the domain points to the NPM LXC IP
- Review the certificate in the NPM web UI — check expiry and domain coverage

### Let's Encrypt Certificate Request Failing

- For HTTP challenge: verify port 80 is open and reachable from the internet
- For DNS challenge: verify the DNS provider API credentials are correct
- Check the NPM web UI error message for the specific failure reason
- Let's Encrypt rate limits apply — do not request the same certificate more than 5 times per week

### Proxy Host Returning 502 Bad Gateway

- Verify the backend service is running and listening on the configured port
- Confirm the NPM LXC can reach the backend IP (check routing and firewall rules)
- Check the Nginx error log inside the LXC: `tail -f /var/log/nginx/error.log`

### Services Not Starting After LXC Reboot

- Confirm systemd services are enabled: `systemctl is-enabled npm openresty`
- If not: `systemctl enable npm openresty && systemctl start npm openresty`

---

*Created by: Thomas Van Auken — Van Auken Tech*  
*Repository: https://github.com/tvanauken/install-scripts*
