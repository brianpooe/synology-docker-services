# Technitium Cutover Checklist (From Current pfSense + Pi-hole)

Start-here master flow:
- [end-to-end-migration-runbook.md](./end-to-end-migration-runbook.md)

## Short answer: do you need 26 CNAME records?
No, not if all your app hostnames should resolve to Caddy.

You can replace most manual CNAMEs with:
- `A` record: `caddy.home.example.com -> 10.10.0.5`
- wildcard `CNAME`: `*.home.example.com -> caddy.home.example.com`

This removes the need to add a new DNS record every time you add a new proxied service.

Technitium UI tip:
- When editing records inside zone `home.example.com`, use relative names (`caddy`, `*`) rather than full FQDN labels.

## Wildcard caveats (important)
- Wildcard does not cover the zone apex itself (`home.example.com`).
- Explicit records still override wildcard (this is good; you can keep special cases).
- A typo hostname will still resolve to Caddy; Caddy may return 404/cert mismatch until that host is configured there.
- Keep your reverse-proxy security policy in Caddy (host matching/auth), because DNS wildcard is broad by design.

## What your current data says
From Pi-hole backup:
- `caddy.home.example.com -> 10.10.0.5`
- 26 CNAMEs currently pointing to `caddy.home.example.com`

From your Caddyfile host blocks:
- 24 hostnames are defined in file.
- 1 active hostname exists in Caddy but is missing from Pi-hole CNAME list:
  - `switchlite8poe.home.example.com`
- 1 hostname is in Pi-hole CNAME list but not currently in Caddy:
  - `tplink8pe.home.example.com`

A wildcard record closes this drift gap permanently.

## Cutover plan

### Docker stack files in this repo
- Compose template: [technitium-dockhand_template.yaml](../docker-compose-files/technitium-dockhand_template.yaml)
- Deployment guide: [technitium-dockhand-deployment.md](./technitium-dockhand-deployment.md)

### 1. Keep network references stable
- Keep Technitium service IP as `10.60.0.5`.
- This avoids changing pfSense DHCP DNS settings, firewall allow rules, and LAN DNS redirect NAT target.

### 2. Deploy Technitium on Raspberry Pi
- Run Technitium container on the Adblock VLAN network reachable as `10.60.0.5`.
- Ensure TCP/UDP `53` reaches this container from all intended VLANs.

### 3. Create primary zone
- Zone name: `home.example.com`
- Zone type: Primary

### 4. Add DNS records (choose one model)

#### Model A: wildcard-first (recommended)
Create only these core records first:
- `A` record inside zone `home.example.com`:
  - Name: `caddy` (FQDN `caddy.home.example.com`)
  - Address: `10.10.0.5`
- `CNAME` record inside zone `home.example.com`:
  - Name: `*` (FQDN `*.home.example.com`)
  - Target: `caddy.home.example.com`

Optional explicit records for readability (not required if wildcard exists):
- `CNAME` `pihole.home.example.com` -> `caddy.home.example.com`
- `CNAME` `proxmox.home.example.com` -> `caddy.home.example.com`
- etc.

#### Model B: explicit-only (current behavior equivalent)
If you prefer explicit control, create:
- `A` `caddy.home.example.com` -> `10.10.0.5`
- CNAME records for each service:
  - `pihole.home.example.com`
  - `proxmox.home.example.com`
  - `nas.home.example.com`
  - `bazarr.home.example.com`
  - `emby.home.example.com`
  - `flaresolverr.home.example.com`
  - `gluetun.home.example.com`
  - `prowlarr.home.example.com`
  - `qbittorrent.home.example.com`
  - `radarr.home.example.com`
  - `sabnzbd.home.example.com`
  - `sonarr.home.example.com`
  - `tplink8pe.home.example.com`
  - `tplink16de.home.example.com`
  - `pbs.home.example.com`
  - `paperless-ngx.home.example.com`
  - `it-tools.home.example.com`
  - `bento-pdf.home.example.com`
  - `beszel.home.example.com`
  - `immich.home.example.com`
  - `speedtest.home.example.com`
  - `gramps.home.example.com`
  - `ytd.home.example.com`
  - `seerr.home.example.com`

If using explicit-only, also add active Caddy hosts that currently have no Pi-hole entry:
- `switchlite8poe.home.example.com`

### 5. Recreate filtering behavior
- Add blocklist URL:
  - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
- Add allowlist domain:
  - `www.googleadservices.com`

### 6. Choose upstream strategy in Technitium
Pick one:
- Least-change: forward to pfSense (`10.1.0.1`) first.
- Cleaner path: enable direct recursive resolution in Technitium.

### 7. Validate before full cutover
From a client in each VLAN, test:
- `nslookup proxmox.home.example.com 10.60.0.5`
- `nslookup switchlite8poe.home.example.com 10.60.0.5`
- `nslookup google.com 10.60.0.5`
- `nslookup www.googleadservices.com 10.60.0.5` (should be allowed)

Also test one blocked ad/tracker domain from query logs.

### 8. Cutover
- Stop Pi-hole service on `10.60.0.5`.
- Start Technitium on `10.60.0.5`.
- Confirm DNS responses and Caddy app access from each VLAN.

### 9. Rollback plan
If anything fails:
- Stop Technitium.
- Start Pi-hole back on `10.60.0.5`.
- Existing pfSense integration should recover immediately since IP dependencies are unchanged.

## Decision recommendation for your setup
Use Model A (wildcard-first).

Reason:
- Your Caddy host inventory changes over time and is already ahead of Pi-hole CNAME entries.
- Wildcard removes manual DNS drift while preserving the same user-facing URLs.

## DNS + proxy interaction (with wildcard)
```mermaid
flowchart LR
    A["Client queries any host\n*.home.example.com"] --> B["Technitium wildcard CNAME"]
    B --> C["caddy.home.example.com"]
    C --> D["A record 10.10.0.5"]
    D --> E["Caddy routes by Host header\nto matching app"]
```

## Related pfSense enforcement runbook
For exact NAT/firewall settings to force DNS across LAN + VLANs, see:
- [pfsense-forced-dns-all-vlans.md](./pfsense-forced-dns-all-vlans.md)
- [pfsense-forced-dns-quick-entry.md](./pfsense-forced-dns-quick-entry.md)
- [pfsense-dot-doh-blocking-quick-entry.md](./pfsense-dot-doh-blocking-quick-entry.md)
