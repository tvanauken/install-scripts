# Nginx Proxy Manager — User Manual

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
8. [After the Script — Adding Proxy Hosts](#8-after-the-script--adding-proxy-hosts)
9. [SSL Certificates](#9-ssl-certificates)
10. [Maintenance and Updates](#10-maintenance-and-updates)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Overview

This script configures an **Nginx Proxy Manager** LXC container that has already been deployed on Proxmox VE. It connects to the NPM HTTP API and performs all post-install setup automatically:

- Creates the admin account
- Authenticates and acquires an API token
- Optionally imports a wildcard SSL certificate

Nginx Proxy Manager (NPM) is a web-based reverse proxy manager backed by OpenResty/Nginx. It provides domain-to-service routing, SSL certificate management, access control, and HTTP/2 — all managed through a browser UI with no manual Nginx config editing.

---

## 2. How This Script Works

The script communicates with NPM exclusively through its HTTP REST API. No SSH into the LXC is required. The script runs from any machine with network access to the LXC IP on port 81.

**API endpoints used:**

| Action | Endpoint |
|--------|----------|
| Create admin account | `POST /api/users` |
| Login / get token | `POST /api/tokens` |
| Import SSL certificate | `POST /api/nginx/certificates` |

---

## 3. Prerequisites

| Requirement | Details |
|-------------|----------|
| Proxmox VE | 8.x or 9.x |
| NPM LXC | Already deployed and running (see Step 1) |
| Port 81 | Must be reachable from the machine running this script |
| Root access | Script must run as root |
| Internet | Required to auto-install `curl` and `jq` if not present |
| SSL cert files | Optional — `.crt` and `.key` files if importing a wildcard cert |

---

## 4. Step 1 — Install the LXC from Community Scripts

Before running this script, the Nginx Proxy Manager LXC must be deployed.

1. Log in to your Proxmox VE web UI at `https://<PVE-IP>:8006`
2. Navigate to your node → click **Shell**
3. Go to: **https://community-scripts.org/scripts?id=nginxproxymanager**
4. Copy the install command and run it in the Proxmox shell
5. Follow the prompts — choose **Default** or **Advanced** (Advanced lets you set a static IP, which is recommended)
6. Wait for the LXC to be created and started — the build process compiles OpenResty from source and takes several minutes
7. Note the LXC IP address shown at the end of the community script

**Default LXC specs created by the community script:**

| Setting | Value |
|---------|-------|
| OS | Debian 12 (Bookworm) |
| CPU | 2 vCPU |
| RAM | 2048 MB |
| Disk | 8 GB |
| Web UI | http://\<LXC-IP\>:81 |

---

## 5. Step 2 — Run the Configuration Script

Once the LXC is running, execute the following from a root shell with network access to the LXC:

```bash
bash <(curl -s https://raw.githubusercontent.com/tvanauken/install-scripts/main/npm-reverse-proxy/npm-reverse-proxy-install.sh)
```

The script will walk you through all configuration interactively.

---

## 6. Configuration Prompts Explained

When the script starts, it displays the following in the Configuration section:

```
── Configuration ───────────────────────────────────────────

  About admin credentials:

  [▸]  Fresh install (web UI setup wizard never opened):
        Enter the email and password you WANT to create.
        This script creates the admin account via the API automatically.

  [▸]  Already completed the NPM web UI setup wizard:
        Enter the email and password you already set up.
        The script will skip account creation and log in directly.
```

### Prompt Details

**NPM LXC IP address**
The IP address of the NPM LXC container. Example: `172.16.250.9`

**Admin full name** (default: `Administrator`)
Display name for the administrator account shown in the NPM web UI.

**Admin email address**
The email address used as the NPM login username. Example: `admin@home.vanauken.tech`

**Admin password**
Entered twice for confirmation. Input is hidden.

**Path to .crt file** (optional)
Full file path to a wildcard SSL certificate file. Example: `/root/certs/wildcard.crt`
Press Enter to skip cert import.

**Path to .key file** (optional)
Full file path to the private key matching the certificate. Example: `/root/certs/wildcard.key`
Only prompted if a `.crt` path was provided.

**Certificate friendly name** (default: `Wildcard Certificate`)
The label shown for this certificate in the NPM Certificates list.

---

## 7. What the Script Configures

### Admin Account

On a fresh NPM installation, no accounts exist. The NPM web UI shows a setup wizard on first visit. This script bypasses the wizard entirely by calling `POST /api/users` to create the admin account directly via the API.

If the account already exists (you completed the web UI wizard), the creation call returns an error. The script detects this, shows `Account already exists — logging in with provided credentials`, and proceeds normally.

### Authentication Token

After account creation (or if account already exists), the script calls `POST /api/tokens` with the email and password to obtain a Bearer token. This token is used for all subsequent API calls.

### Wildcard SSL Certificate Import

If `.crt` and `.key` file paths were provided, the script uploads them to NPM via `POST /api/nginx/certificates` as a multipart form upload. The certificate is stored in NPM and is immediately available to assign to Proxy Hosts.

If no cert paths were provided, this step is skipped. You can import certificates later through the NPM web UI under **SSL Certificates**.

---

## 8. After the Script — Adding Proxy Hosts

Proxy Hosts route incoming domain names to backend services. Adding them is done through the NPM web UI.

1. Open `http://<LXC-IP>:81` and log in
2. Click **Hosts → Proxy Hosts → Add Proxy Host**
3. **Details tab:**
   - Domain Names: the FQDN (e.g. `npm.home.vanauken.tech`)
   - Scheme: `http` or `https` (scheme to the backend, not the client)
   - Forward Hostname/IP: backend service IP or hostname
   - Forward Port: backend service port
   - Enable **Block Common Exploits**
   - Enable **Websockets Support** if needed (e.g. Home Assistant)
4. **SSL tab:**
   - Select your imported wildcard certificate (or request a new one)
   - Enable **Force SSL**
   - Enable **HTTP/2 Support**
5. Click **Save**

---

## 9. SSL Certificates

### Using the Imported Wildcard Certificate

If you imported a wildcard cert during the script, it will appear in **SSL Certificates** in the NPM web UI. When adding a Proxy Host, select it from the certificate dropdown in the SSL tab.

### Requesting a Let's Encrypt Certificate

1. **SSL Certificates → Add SSL Certificate → Let's Encrypt**
2. Enter domain names, email address, and select challenge type
3. HTTP challenge requires port 80 accessible from the internet
4. DNS challenge requires a supported DNS provider certbot plugin

### Installing Certbot DNS Plugins

For DNS challenge automation, run inside the NPM LXC:

```bash
pct enter <CTID>
/app/scripts/install-certbot-plugins
```

This installs common DNS provider plugins (Cloudflare, Route53, DigitalOcean, etc.).

---

## 10. Maintenance and Updates

### Updating NPM

```bash
pct enter <CTID>
update
```

### Backing Up

All NPM configuration, certificates, and proxy rules are stored in `/data/` inside the LXC:

```bash
tar czf npm-backup-$(date +%Y%m%d).tar.gz /data/
```

### Log Files

- NPM logs: `/data/logs/` inside the LXC
- Nginx logs: `/var/log/nginx/` inside the LXC
- Configuration script log: `/var/log/npm-config-<timestamp>.log` on the host that ran the script

### Service Status

Inside the LXC:

```bash
systemctl status npm
systemctl status openresty
```

---

## 11. Troubleshooting

### Script Cannot Reach NPM

- Verify the LXC is running: `pct status <CTID>`
- Confirm port 81 is listening: `pct exec <CTID> -- netstat -tulnp | grep :81`
- Ensure no firewall blocks port 81 between the script host and LXC

### Authentication Failed

- If you already set up an account via the web UI wizard, enter exactly those credentials at the prompt
- Email addresses are case-sensitive in some NPM versions
- Check `/var/log/npm-config-<timestamp>.log` for the raw API response

### Certificate Import Failed

- Verify the `.crt` and `.key` files exist at the paths provided
- Confirm the key matches the certificate: `openssl x509 -noout -modulus -in cert.crt | md5sum` should match `openssl rsa -noout -modulus -in cert.key | md5sum`
- Check the log file for the raw API error response

### Proxy Host Returns 502 Bad Gateway

- Confirm the backend service is running and listening
- Verify the NPM LXC can reach the backend IP (check VLAN routing)
- Check Nginx error log inside LXC: `tail -f /var/log/nginx/error.log`

### Services Not Starting After LXC Reboot

```bash
pct exec <CTID> -- systemctl enable npm openresty
pct exec <CTID> -- systemctl start npm openresty
```

---

*Created by: Thomas Van Auken — Van Auken Tech*
*Repository: https://github.com/tvanauken/install-scripts*
