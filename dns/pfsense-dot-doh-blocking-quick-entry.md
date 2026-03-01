# pfSense DoT/DoH Blocking Quick Entry (Copy-Style)

Use this after forced DNS redirect is in place.

Goal:
- Block DNS-over-TLS (DoT) on port `853`.
- Block known DNS-over-HTTPS (DoH) endpoints on port `443`.

## 0) Create aliases
Path: `Firewall > Aliases`

Create network alias:
- Name: `DNS_CLIENT_NETS`
- Type: `Network(s)`
- Values:
  - `LAN net`
  - `Office net` (OPT2)
  - `Family net` (OPT3)
  - `IoT net` (OPT4)
  - `Media net` (OPT5)
  - `Guest net` (OPT6)

Create host alias:
- Name: `DOH_PROVIDERS`
- Type: `Host(s)`
- Values (FQDNs):
  - `dns.google`
  - `cloudflare-dns.com`
  - `one.one.one.one`
  - `security.cloudflare-dns.com`
  - `family.cloudflare-dns.com`
  - `dns.quad9.net`
  - `dns.nextdns.io`
  - `doh.opendns.com`
  - `doh.cleanbrowsing.org`
  - `dns.adguard-dns.com`
  - `unfiltered.adguard-dns.com`
  - `family.adguard-dns.com`
  - `dns.controld.com`
  - `doh.mullvad.net`

Notes:
- This list is intentionally practical, not exhaustive.
- You can add/remove providers later without editing firewall rules.

## 1) Floating rule: block DoT (853)
Path: `Firewall > Rules > Floating` then `Add`

Set fields:
- Action: `Block`
- Quick: `checked`
- Interface: `LAN, OPT2, OPT3, OPT4, OPT5, OPT6`
- Direction: `out`
- Address Family: `IPv4+IPv6`
- Protocol: `TCP/UDP`
- Source: `Single host or alias` = `DNS_CLIENT_NETS`
- Source Port: `any`
- Destination: `any`
- Destination Port Range: `853 (DoT)`
- Log: `checked` (recommended for tuning)
- Description: `Block DoT 853 from client VLANs`

Save, but do not apply yet.

## 2) Floating rule: block known DoH (443)
Path: `Firewall > Rules > Floating` then `Add`

Set fields:
- Action: `Block`
- Quick: `checked`
- Interface: `LAN, OPT2, OPT3, OPT4, OPT5, OPT6`
- Direction: `out`
- Address Family: `IPv4+IPv6`
- Protocol: `TCP`
- Source: `Single host or alias` = `DNS_CLIENT_NETS`
- Source Port: `any`
- Destination: `Single host or alias` = `DOH_PROVIDERS`
- Destination Port Range: `HTTPS (443)`
- Log: `checked` (recommended for tuning)
- Description: `Block known DoH 443 from client VLANs`

## 3) Rule order (critical)
In `Firewall > Rules > Floating`:
- Keep both block rules above broader floating pass rules.
- Keep `Quick` enabled so they match immediately.

## 4) Apply and verify
Apply:
- `Save` + `Apply Changes`

Client-side checks (from LAN and one VLAN):
```bash
# DoT test (should fail)
openssl s_client -connect 1.1.1.1:853 -brief

# DoH test (should fail or reset)
curl -I https://dns.google/dns-query

# Normal DNS still works because of forced redirect
nslookup google.com 8.8.8.8
```

Expected:
- DoT/DoH tests fail.
- `nslookup ... 8.8.8.8` still resolves via your local DNS redirect path.

## 5) Important limitations
- DoH blocking by known provider list is not complete; new/custom DoH endpoints can still bypass.
- For strict control, use egress allow-listing and/or proxy-based controls.
- Encrypted ClientHello (ECH) trends reduce hostname-based control over time.
