# Technitium + Dockhand Docker Deployment Guide

This guide deploys Technitium DNS and Dockhand using:
- `/Users/luda/Documents/synology-docker-services/docker-compose-files/technitium-dockhand_template.yaml`

Compatibility note:
- Dockhand image in this stack is `fnsys/dockhand:latest` and should be run on 64-bit Linux (`arm64` on Pi 4).
- 2GB RAM Pi 4 is supported with the included memory caps in the compose template.
- This template hardcodes `PUID=1000`, `PGID=1000`, `max-file=3`, and `max-size=10m` for Pi-local use.

## 1) Prepare env values
Update your `.env` with these required values:
- `DNS_BIND_IP=192.168.60.5`
- `TECHNITIUM_ADMIN_PASSWORD=<strong-password>`
- `DOCKHAND_ENCRYPTION_KEY=<base64 key that decodes to exactly 32 bytes>`
- `TECHNITIUM_CONFIG_DIR=./appdata/technitium`
- `DOCKHAND_DATA_DIR=./appdata/dockhand`
- `DOCKHAND_STACKS_DIR=./stacks` (or any local host path containing compose files)
- `DOCKER_GID=<docker.sock group id>`

For 2GB Pi 4 (recommended defaults already in `.env.sample`):
- `TECHNITIUM_MEM_LIMIT=512m`
- `DOCKHAND_MEM_LIMIT=256m`

Tip:
- `DOCKER_GID` command: `stat -c '%g' /var/run/docker.sock`
- Relative bind paths (like `./appdata/...`) are resolved from the folder containing the rendered compose file (`docker-compose-files/`).

Generate a valid Dockhand encryption key:
```bash
openssl rand -base64 32
```
Paste the output into `.env` as `DOCKHAND_ENCRYPTION_KEY=...`.

Create local bind-mount folders:
```bash
mkdir -p docker-compose-files/appdata/technitium docker-compose-files/appdata/dockhand docker-compose-files/stacks
```

## 2) Render compose from template
Run:
```bash
./substitute_env.sh docker-compose-files/technitium-dockhand_template.yaml docker-compose-files/technitium-dockhand.yaml .env
```

## 3) Start stack
Run:
```bash
docker compose -f docker-compose-files/technitium-dockhand.yaml up -d
```

## 4) First-time Technitium setup (required)
Open:
- `http://<DNS_BIND_IP>:5380`

Then configure:
1. Create primary zone `home.brianpooe.com`.
2. Add `A` record inside that zone:
   - Name: `caddy` (FQDN: `caddy.home.brianpooe.com`)
   - Address: `192.168.10.5`
3. Add wildcard `CNAME` inside that zone:
   - Name: `*` (FQDN: `*.home.brianpooe.com`)
   - Target: `caddy.home.brianpooe.com`
4. Add allowlist equivalent for `www.googleadservices.com`.

Reference details:
- `/Users/luda/Documents/synology-docker-services/dns/technitium-cutover-checklist.md`

## 5) pfSense integration
Keep DNS server IP as `192.168.60.5` to avoid changing existing DHCP and firewall dependencies.

For forced DNS across all VLANs:
- `/Users/luda/Documents/synology-docker-services/dns/pfsense-forced-dns-quick-entry.md`

For DoT/DoH hardening:
- `/Users/luda/Documents/synology-docker-services/dns/pfsense-dot-doh-blocking-quick-entry.md`

## 6) Validation
Run from clients on each VLAN:
```bash
nslookup google.com 192.168.60.5
nslookup proxmox.home.brianpooe.com 192.168.60.5
nslookup switchlite8poe.home.brianpooe.com 192.168.60.5
```

## 7) Common gotchas
- If Technitium fails to bind port 53, check for other DNS services on the host (for example `systemd-resolved`, `dnsmasq`, old Pi-hole container).
- If Dockhand cannot manage containers, verify `DOCKER_GID` and docker socket mount.
- If Dockhand shows `Invalid ENCRYPTION_KEY`, regenerate with `openssl rand -base64 32`, re-render the compose file, and restart Dockhand.
- If `http://<DNS_BIND_IP>:5380` is refused, run:
```bash
docker compose -f docker-compose-files/technitium-dockhand.yaml ps technitium-dns
docker compose -f docker-compose-files/technitium-dockhand.yaml port technitium-dns 5380
ss -ltnp | grep 5380 || true
```
  - Confirm `TECHNITIUM_WEB_BIND_IP` in `.env` is not `127.0.0.1`.
