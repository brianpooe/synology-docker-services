# End-to-End Migration Runbook (Pi-hole on Pi Zero 2 W -> Technitium + Dockhand on Pi 4)

Use this as the single flow document. Each step links to the deeper guide where needed.

## 1) Confirm baseline and keep rollback assets
1. Keep your current backups safe:
   - pfSense backup XML
   - Pi-hole teleporter tarball
2. Keep the old Pi Zero 2 W untouched until final cutover is stable.
3. Review your analyzed current-state map:
   - [Current architecture analysis](/Users/luda/Documents/synology-docker-services/dns/pfsense-pihole-technitium-analysis.md)

## 2) Prepare the new Pi 4 with a temporary DNS IP
1. Connect Pi 4 to the same Adblock VLAN (`192.168.60.0/24`).
2. In pfSense, create a temporary DHCP static mapping for Pi 4, for example `192.168.60.6`.
3. Confirm Pi 4 gets the temporary IP and has network reachability.

Why temporary IP first:
- You can build and test everything without disturbing production DNS (`192.168.60.5`).

### Compatibility preflight on Pi 4 (important)
Run these checks before deployment:
```bash
uname -m
cat /etc/os-release
docker --version
docker compose version
```

Expected:
- `uname -m` should be `aarch64` (64-bit) for best compatibility with Dockhand.
- OS can be Raspberry Pi OS Lite based on Debian Trixie.
- Docker Engine + Compose plugin installed and working.
- 2GB RAM Pi 4 is fine for this stack with current memory caps.

## 3) Configure compose environment and render stack
1. Fill required values in `.env` (or environment file you use):
   - `DNS_BIND_IP=192.168.60.6` (temporary during staging)
   - `TECHNITIUM_ADMIN_PASSWORD=<strong-password>`
   - `DOCKHAND_ENCRYPTION_KEY=<base64 key from openssl rand -base64 32>`
   - `TECHNITIUM_CONFIG_DIR=./appdata/technitium`
   - `DOCKHAND_DATA_DIR=./appdata/dockhand`
   - `DOCKER_GID=<docker.sock group id>`
   - `DOCKHAND_STACKS_DIR=./stacks` (or local path you want Dockhand to manage)
2. Render the compose from template:
```bash
./substitute_env.sh docker-compose-files/technitium-dockhand_template.yaml docker-compose-files/technitium-dockhand.yaml .env
```
3. Start the stack:
```bash
docker compose -f docker-compose-files/technitium-dockhand.yaml up -d
```

Reference:
- [Technitium + Dockhand deployment guide](/Users/luda/Documents/synology-docker-services/dns/technitium-dockhand-deployment.md)
- [Compose template](/Users/luda/Documents/synology-docker-services/docker-compose-files/technitium-dockhand_template.yaml)

## 4) Configure Technitium to mirror current behavior
1. Open Technitium UI on Pi 4 temporary IP:
   - `http://192.168.60.6:5380`
2. Create primary zone `home.brianpooe.com`.
3. Add:
   - `A` record: `caddy.home.brianpooe.com -> 192.168.10.5`
   - wildcard `CNAME`: `*.home.brianpooe.com -> caddy.home.brianpooe.com`
4. Configure blocklist:
   - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
5. Add allowlist entry:
   - `www.googleadservices.com`

Reference:
- [Technitium cutover checklist](/Users/luda/Documents/synology-docker-services/dns/technitium-cutover-checklist.md)

## 5) Pre-cutover validation on temporary IP
From clients (or directly from Pi 4), validate against `192.168.60.6`:
```bash
nslookup google.com 192.168.60.6
nslookup proxmox.home.brianpooe.com 192.168.60.6
nslookup switchlite8poe.home.brianpooe.com 192.168.60.6
```

If these fail, do not proceed to IP swap.

## 6) Apply/confirm pfSense DNS enforcement policy
If not already done, apply forced DNS interception for LAN + VLANs.

Reference (fast entry):
- [Forced DNS quick entry](/Users/luda/Documents/synology-docker-services/dns/pfsense-forced-dns-quick-entry.md)

Reference (full explanation):
- [Forced DNS all VLANs](/Users/luda/Documents/synology-docker-services/dns/pfsense-forced-dns-all-vlans.md)

Optional hardening for encrypted DNS bypass:
- [DoT/DoH blocking quick entry](/Users/luda/Documents/synology-docker-services/dns/pfsense-dot-doh-blocking-quick-entry.md)

## 7) Safe same-IP handover (make Pi 4 become `192.168.60.5`)
1. Schedule a short maintenance window.
2. Stop/disconnect old Pi Zero 2 W first (avoid duplicate IP and ARP conflict).
3. In pfSense DHCP static mappings (Adblock VLAN):
   - Move `192.168.60.5` reservation from old Pi MAC to new Pi 4 MAC.
4. On Pi 4:
   - Renew DHCP lease or reboot networking/container host.
5. Confirm Pi 4 now has `192.168.60.5`.
6. If needed, clear stale ARP entry for `192.168.60.5` on pfSense.
7. Update `.env`:
   - set `DNS_BIND_IP=192.168.60.5`
8. Re-render and restart stack:
```bash
./substitute_env.sh docker-compose-files/technitium-dockhand_template.yaml docker-compose-files/technitium-dockhand.yaml .env
docker compose -f docker-compose-files/technitium-dockhand.yaml up -d
```

## 8) Post-cutover validation (production IP)
Run tests from each VLAN segment:
```bash
nslookup google.com 192.168.60.5
nslookup cloudflare.com 1.1.1.1
nslookup proxmox.home.brianpooe.com 192.168.60.5
nslookup switchlite8poe.home.brianpooe.com 192.168.60.5
```

Expected:
- DNS works from all VLANs.
- Hardcoded public DNS on port 53 still resolves (redirected to your local DNS).
- Local app hostnames resolve correctly.
- Queries appear in Technitium logs.

## 9) Rollback (if needed)
1. Stop Technitium stack on Pi 4.
2. In pfSense, move `192.168.60.5` DHCP reservation back to old Pi Zero 2 W MAC.
3. Start old Pi Zero 2 W.
4. Validate DNS from clients.

## 10) After stabilization
1. Update Caddy host references if you want `pihole.home...` renamed to `dns.home...`.
2. Keep old Pi offline but available for a few days.
3. Export Technitium backup after final state is verified.
