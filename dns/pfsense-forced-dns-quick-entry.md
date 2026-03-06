# pfSense Forced DNS Quick Entry (Copy-Style)

Use this when entering rules manually in pfSense with minimal interpretation.

## 0) Create alias first
Path: `Firewall > Aliases`

Create:
- Name: `LOCAL_DNS`
- Type: `Host(s)`
- Value: `192.168.60.5`

Optional (recommended when using Caddy DNS-01 with Cloudflare):
- Name: `CADDY_HOST`
- Type: `Host(s)`
- Value: `192.168.10.5`

## 1) NAT Port Forward rules (enter these 6)
Path: `Firewall > NAT > Port Forward`

If you already have a correct LAN rule matching `Force DNS to LOCAL_DNS (LAN)`, keep it and skip re-creating Rule A.
Then create only the missing VLAN rules (`OPT2` to `OPT6`).

For each block below, click `Add` and use exactly these fields.

### Rule A: LAN
- Interface: `LAN`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `LAN net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (LAN)`
- Filter rule association: `Add associated filter rule`

### Rule B: Office (OPT2)
- Interface: `OPT2`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `OPT2 net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (OPT2)`
- Filter rule association: `Add associated filter rule`

### Rule C: Family (OPT3)
- Interface: `OPT3`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `OPT3 net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (OPT3)`
- Filter rule association: `Add associated filter rule`

### Rule D: IoT (OPT4)
- Interface: `OPT4`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `OPT4 net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (OPT4)`
- Filter rule association: `Add associated filter rule`

### Rule E: Media (OPT5)
- Interface: `OPT5`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `OPT5 net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (OPT5)`
- Filter rule association: `Add associated filter rule`

### Rule F: Guest (OPT6)
- Interface: `OPT6`
- Address Family: `IPv4`
- Protocol: `TCP/UDP`
- Source: `OPT6 net`
- Source Port: `any`
- Destination: `Single host or alias` = `LOCAL_DNS`
- Invert Match (destination): `checked`
- Destination Port Range: `DNS (53)`
- Redirect target IP: `LOCAL_DNS`
- Redirect target port: `DNS (53)`
- Description: `Force DNS to LOCAL_DNS (OPT6)`
- Filter rule association: `Add associated filter rule`

Do not add this redirect on `OPT7` (DNS server VLAN).

## 1b) Exception for Caddy ACME DNS-01 traffic (important)
If Caddy is using DNS-01 challenges with Cloudflare, exclude the Caddy host from forced DNS redirect on the interface where Caddy lives (for this setup, `OFFICE` / `OPT2`).

Edit rule:
- `Force DNS to LOCAL_DNS (OFFICE)`

Set:
- Source: `Invert Match` = checked
- Source type/value: `Address or Alias` = `CADDY_HOST`
- Source Port: `any` to `any` (do not set `DNS` here)
- Destination: keep `Invert Match` checked and `LOCAL_DNS`
- Destination Port: keep `DNS (53)`
- Redirect target IP/Port: keep `LOCAL_DNS:53`

Why this is needed:
- Without this exception, pfSense intercepts Caddy's outbound DNS lookups (even when targeting public resolvers like `1.1.1.1`) and redirects them to local Technitium.
- Caddy then sees local split-DNS zone `home.brianpooe.com`, but Cloudflare only has public zone `brianpooe.com`.
- ACME fails with: `expected 1 zone, got 0 for home.brianpooe.com`.

Validation from Caddy host:
```bash
dig +short SOA home.brianpooe.com @1.1.1.1
```
- This should not return Technitium SOA (`dns01.home.brianpooe.com ...`) once the exception is active.

## 2) Rule order checks (critical)

### NAT order
In `Firewall > NAT > Port Forward`:
- Keep all `Force DNS to LOCAL_DNS (...)` rules above other generic redirects.

### Firewall order
In `Firewall > Rules` on each interface:
- Keep associated DNS pass rule above any RFC1918 block rule.
- On LAN, disable/remove your old `Block all rogue DNS requests` rule.

## 3) Apply and test

Apply:
- `Save` + `Apply Changes` in NAT and Rules.

Test from one client per segment:
```bash
nslookup google.com 8.8.8.8
nslookup cloudflare.com 1.1.1.1
nslookup proxmox.home.brianpooe.com
nslookup switchlite8poe.home.brianpooe.com
```

Expected:
- Queries succeed.
- Requests appear in your DNS server logs (Pi-hole now / Technitium later).

## 4) Optional bypass hardening
Port `53` interception does not stop encrypted DNS:
- DoT: TCP `853`
- DoH: HTTPS `443`

Minimum extra control:
- Add block rules for outbound TCP/UDP `853` on LAN/OPT2/OPT3/OPT4/OPT5/OPT6.

Related hardening quick-entry:
- [pfsense-dot-doh-blocking-quick-entry.md](./pfsense-dot-doh-blocking-quick-entry.md)
