# End-to-End Migration Runbook (Pi-hole on Pi Zero 2 W -> Technitium on Pi 4)

Use this as the single flow document. Each step links to the deeper guide where needed.

## 1) Confirm baseline and keep rollback assets
1. Keep your current backups safe:
   - pfSense backup XML
   - Pi-hole teleporter tarball
2. Keep the old Pi Zero 2 W untouched until final cutover is stable.
3. Review your analyzed current-state map:
   - [pfsense-pihole-technitium-analysis.md](./pfsense-pihole-technitium-analysis.md)

## 2) Prepare the new Pi 4 with a temporary DNS IP
1. Connect Pi 4 to the same Adblock VLAN (`10.60.0.0/24`).
2. In pfSense, create a temporary DHCP static mapping for Pi 4, for example `10.60.0.6`.
3. Confirm Pi 4 gets the temporary IP and has network reachability.

Why temporary IP first:
- You can build and test everything without disturbing production DNS (`10.60.0.5`).

### Compatibility preflight on Pi 4 (important)
Run these checks before deployment:
```bash
uname -m
cat /etc/os-release
docker --version
docker compose version
```

Expected:
- `uname -m` should be `aarch64` (64-bit) for best compatibility with current Docker images.
- OS can be Raspberry Pi OS Lite based on Debian Trixie.
- Docker Engine + Compose plugin installed and working.
- 2GB RAM Pi 4 is fine for this stack with current memory caps.

## 3) Configure compose environment and render stack
1. Fill required values in `.env` (or environment file you use):
   - `DNS_BIND_IP=10.60.0.6` (temporary during staging)
   - `TECHNITIUM_ADMIN_PASSWORD=<strong-password>`
   - `TECHNITIUM_CONFIG_DIR=./appdata/technitium`
2. Render the compose from template:
```bash
./substitute_env.sh docker-compose-files/technitium_template.yaml docker-compose-files/technitium.yaml .env
```
3. Start the stack:
```bash
docker compose -f docker-compose-files/technitium.yaml up -d
```

Reference:
- [technitium-deployment.md](./technitium-deployment.md)
- [technitium_template.yaml](../docker-compose-files/technitium_template.yaml)

## 4) Configure Technitium to mirror current behavior
1. Open Technitium UI on Pi 4 temporary IP:
   - `http://10.60.0.6:5380`
2. Create primary zone `home.example.com`.
3. Add:
   - `A` record inside that zone:
     - Name: `caddy` (FQDN: `caddy.home.example.com`)
     - Address: `10.10.0.5`
   - wildcard `CNAME` inside that zone:
     - Name: `*` (FQDN: `*.home.example.com`)
     - Target: `caddy.home.example.com`
4. Configure blocklist:
   - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
5. Add allowlist entry:
   - `www.googleadservices.com`

Reference:
- [technitium-cutover-checklist.md](./technitium-cutover-checklist.md)

## 5) Pre-cutover validation on temporary IP
From clients (or directly from Pi 4), validate against `10.60.0.6`:
```bash
nslookup google.com 10.60.0.6
nslookup proxmox.home.example.com 10.60.0.6
nslookup switchlite8poe.home.example.com 10.60.0.6
```

If these fail, do not proceed to IP swap.

## 6) Apply/confirm pfSense DNS enforcement policy
If not already done, apply forced DNS interception for LAN + VLANs.

If you already have the LAN redirect rule (`LAN`, TCP/UDP, `!LOCAL_DNS`, `53` -> `LOCAL_DNS:53`), keep it and do not duplicate it.
Only add missing interface rules for `OPT2`, `OPT3`, `OPT4`, `OPT5`, and `OPT6`.

Reference (fast entry):
- [pfsense-forced-dns-quick-entry.md](./pfsense-forced-dns-quick-entry.md)

Reference (full explanation):
- [pfsense-forced-dns-all-vlans.md](./pfsense-forced-dns-all-vlans.md)

Important for Caddy DNS-01 + Cloudflare:
- If Caddy host is inside a force-redirected VLAN (for this setup, `OFFICE`), exclude that host from the interface's forced DNS NAT rule.
- Keep rule source as inverted `!CADDY_HOST` and source port as `any` to `any`.
- This prevents ACME failures like: `expected 1 zone, got 0 for home.example.com`.

Optional hardening for encrypted DNS bypass:
- [pfsense-dot-doh-blocking-quick-entry.md](./pfsense-dot-doh-blocking-quick-entry.md)

## 7) Safe same-IP handover (make Pi 4 become `10.60.0.5`)
1. Schedule a short maintenance window.
2. Stop/disconnect old Pi Zero 2 W first (avoid duplicate IP and ARP conflict).
3. In pfSense DHCP static mappings (Adblock VLAN):
   - Move `10.60.0.5` reservation from old Pi MAC to new Pi 4 MAC.
4. On Pi 4:
   - Renew DHCP lease or reboot networking/container host.
5. Confirm Pi 4 now has `10.60.0.5`.
6. If needed, clear stale ARP entry for `10.60.0.5` on pfSense.
7. Update `.env`:
   - set `DNS_BIND_IP=10.60.0.5`
8. Re-render and restart stack:
```bash
./substitute_env.sh docker-compose-files/technitium_template.yaml docker-compose-files/technitium.yaml .env
docker compose -f docker-compose-files/technitium.yaml up -d
```

## 8) Post-cutover validation (production IP)
Run tests from each VLAN segment:
```bash
nslookup google.com 10.60.0.5
nslookup cloudflare.com 1.1.1.1
nslookup proxmox.home.example.com 10.60.0.5
nslookup switchlite8poe.home.example.com 10.60.0.5
```

Expected:
- DNS works from all VLANs.
- Hardcoded public DNS on port 53 still resolves (redirected to your local DNS).
- Local app hostnames resolve correctly.
- Queries appear in Technitium logs.

## 9) Rollback (if needed)
1. Stop Technitium stack on Pi 4.
2. In pfSense, move `10.60.0.5` DHCP reservation back to old Pi Zero 2 W MAC.
3. Start old Pi Zero 2 W.
4. Validate DNS from clients.

## 10) After stabilization
1. Update Caddy host references if you want `pihole.home...` renamed to `dns.home...`.
2. Keep old Pi offline but available for a few days.
3. Export Technitium backup after final state is verified.
