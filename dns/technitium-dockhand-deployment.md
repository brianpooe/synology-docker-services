# Technitium + Dockhand Docker Deployment Guide

This guide deploys Technitium DNS and Dockhand using:
- `/Users/luda/Documents/synology-docker-services/docker-compose-files/technitium-dockhand_template.yaml`

Compatibility note:
- Dockhand image in this stack is `fnsys/dockhand:latest` and should be run on 64-bit Linux (`arm64` on Pi 4).
- 2GB RAM Pi 4 is supported with the included memory caps in the compose template.

## 1) Prepare env values
Update your `.env` with these required values:
- `DNS_BIND_IP=192.168.60.5`
- `TECHNITIUM_ADMIN_PASSWORD=<strong-password>`
- `DOCKHAND_ENCRYPTION_KEY=<long-random-string>`
- `TECHNITIUM_CONFIG_DIR=./appdata/technitium`
- `DOCKHAND_DATA_DIR=./appdata/dockhand`
- `DOCKHAND_STACKS_DIR=./stacks` (or any local host path containing compose files)
- `DOCKER_GID=<docker.sock group id>`

For 2GB Pi 4 (recommended defaults already in `.env.sample`):
- `TECHNITIUM_MEM_LIMIT=512m`
- `TECHNITIUM_MEM_RESERVATION=192m`
- `DOCKHAND_MEM_LIMIT=256m`
- `DOCKHAND_MEM_RESERVATION=64m`

Tip:
- `DOCKER_GID` command: `stat -c '%g' /var/run/docker.sock`
- Relative bind paths (like `./appdata/...`) are resolved from the folder containing the rendered compose file (`docker-compose-files/`).

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
2. Add `A` record: `caddy.home.brianpooe.com -> 192.168.10.5`.
3. Add wildcard `CNAME`: `*.home.brianpooe.com -> caddy.home.brianpooe.com`.
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
