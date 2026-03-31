# Homelab Network

## 1. Overview
This document reflects the current network state using:
- User-provided topology and intent.
- Repo configuration/templates.
- pfSense backup provided by user: `config-pfSense.home.arpa-20260321225944.xml` (private local file, not committed to repo).

Public-safe notation policy used in this repository:
- Internal RFC1918 layout is represented as `10.<vlan>.0/24` examples.
- Internal domain is represented as `home.example.com`.

High-level design:
- Fibre Internet -> ISP ONT -> Netgate 1100/pfSense.
- pfSense trunks VLANs to core switching.
- Core switching fans out to AP, media switch, office/homelab switch, Mac mini, and Raspberry Pi DNS node.
- Technitium DNS/ad-blocking is centralized on AdBlock VLAN.
- Office-hosted reverse proxy is the controlled cross-VLAN destination for Family/Media.

Diagram source files (Eraser diagram-as-code):
- `docs/network/diagrams/homelab-network-physical.eraserdiagram`
- `docs/network/diagrams/homelab-network-logical.eraserdiagram`

Rendered exports:
- `docs/network/diagrams/homelab-network-logical.svg`
- `docs/network/diagrams/homelab-network-physical.svg`
- `docs/network/diagrams/homelab-network-combined.svg`

## Evidence Table
| Fact | Value (public-safe) | Source file(s) | Confidence |
|---|---|---|---|
| Active VLAN interfaces and gateways exist for LAN, Office, Family, IoT, Media, Guest, AdBlock | LAN `10.1.0.0/24`, Office `10.10.0.0/24`, Family `10.20.0.0/24`, IoT `10.30.0.0/24`, Media `10.40.0.0/24`, Guest `10.50.0.0/24`, AdBlock `10.60.0.0/24` | `config-pfSense.home.arpa-20260321225944.xml` (`<interfaces>`, `<vlans>`) | High |
| DHCP hands out centralized DNS on client segments | Clients use `10.60.0.5` as DNS on LAN + Office + Family + IoT + Media + Guest | `config-pfSense.home.arpa-20260321225944.xml` (`<dhcpd>`) | High |
| DNS platform is Technitium on Raspberry Pi in AdBlock VLAN | `LOCAL_DNS` alias points to `10.60.0.5`; static map `dns01` exists on AdBlock VLAN | `config-pfSense.home.arpa-20260321225944.xml` (`<aliases>`, `<dhcpd><opt7>`) | High |
| Forced DNS NAT is active on LAN + Office + Family + IoT + Media + Guest | NAT redirect rules to `LOCAL_DNS:53` exist on `lan`, `opt2`, `opt3`, `opt4`, `opt5`, `opt6` | `config-pfSense.home.arpa-20260321225944.xml` (`<nat>`) | High |
| Office has DNS redirect exception for reverse proxy host | Office NAT rule source excludes `CADDY_HOST` | `config-pfSense.home.arpa-20260321225944.xml` (`<nat>`) | High |
| Family and Media have explicit reverse-proxy access rule | TCP pass rules from Family/Media to reverse proxy host (`CADDY_HOST`) | `config-pfSense.home.arpa-20260321225944.xml` (`<filter>`) | High |
| IoT and Guest are isolated from other private networks except explicit rules | `Block access to other networks` (RFC1918) + own-subnet + DNS + internet pass ordering | `config-pfSense.home.arpa-20260321225944.xml` (`<filter>`) | High |
| Core infrastructure static mappings on LAN exist | USW Lite 8, Mac mini, U6 LR, and TL-SG1016DE have static mappings on LAN | `config-pfSense.home.arpa-20260321225944.xml` (`<dhcpd><lan>`) | High |
| Caddy and NAS are statically mapped on Office VLAN | Reverse proxy (`10.10.0.5`) and NAS (`10.10.0.24`) mapped in Office subnet example | `config-pfSense.home.arpa-20260321225944.xml` (`<dhcpd><opt2>`) | High |
| Published reverse-proxy naming uses safe domain examples | `home.example.com` in templates | `.env.sample`, `caddy/Caddyfile_template` | High |

## 2. Device Inventory
| Device / Group | Role | Verified details |
|---|---|---|
| Calix GigaPoint 803G GPON ONT | ISP optical termination | User topology source |
| Netgate 1100 (pfSense) | Router/firewall, inter-VLAN routing, NAT/policy | VLAN interfaces, NAT, aliases, and filter rules verified in pfSense backup |
| Ubiquiti UB-USW-LITE-8-POE | Core aggregation switch | Static mapping on LAN as `10.1.0.5` example |
| UniFi U6 LR (managed AP) | Multi-VLAN wireless AP | Static mapping on LAN as `10.1.0.7` example |
| TP-Link TL-SG108 (unmanaged) | Media downstream switch | User topology source (no direct pfSense static mapping expected) |
| TP-Link TL-SG1016DE (managed) | Office/homelab downstream switch | Static mapping on LAN as `10.1.0.8` example |
| Raspberry Pi 4 Model B (2GB) | Technitium DNS/ad-block host | Static mapping `dns01` on AdBlock VLAN as `10.60.0.5` example |
| Mac mini | Endpoint on core switch/LAN | Static mapping on LAN as `10.1.0.6` example |
| Intel NUC | Homelab endpoint | User-confirmed static IP on Office VLAN (public-safe value not published here) |
| DS920+ NAS | NAS/homelab service host | Static mapping in Office VLAN as `10.10.0.24` example |
| Office reverse proxy host (Caddy) | Controlled cross-VLAN ingress target | Alias `CADDY_HOST`; static mapping in Office VLAN as `10.10.0.5` example |
| Family/Guest/IoT wireless clients | Client groups on AP | Family and other client DHCP scopes verified |
| Media clients | TV/Apple TV/soundbar class clients | Media VLAN DHCP scope and static TV entry verified |

## 3. Physical Topology
Physical path (left-to-right):
1. Internet (fibre)
2. Calix ONT
3. Netgate 1100 / pfSense
4. Ubiquiti UB-USW-LITE-8-POE (core switch)
5. Downstream from core switch:
   - UniFi U6 LR managed AP (PoE)
   - TP-Link TL-SG108 (media segment)
   - TP-Link TL-SG1016DE (office/homelab segment)
   - Mac mini
   - Raspberry Pi 4 (Technitium DNS)
6. Downstream endpoints:
   - Media clients via TL-SG108
   - Office/homelab endpoints via TL-SG1016DE (including NAS, other infra)
   - Wireless Family/Guest/IoT clients via U6 LR

Physical/logical clarification:
- Raspberry Pi DNS host is physically connected to switching.
- pfSense-to-DNS is a routed logical resolver path, not a direct cable.

Netgate internal switch implementation details are intentionally abstracted in this public-safe document.

## 4. Logical Topology / VLAN Layout
| VLAN | Purpose | CIDR (public-safe) | Typical residents |
|---|---|---|---|
| LAN | Core local management/client segment | `10.1.0.0/24` | Switch/AP management, Mac mini, baseline LAN clients |
| Office | Admin/workstation + homelab services | `10.10.0.0/24` | Caddy reverse proxy, NAS, Proxmox-related services |
| Family | Family user segment | `10.20.0.0/24` | Family wireless devices |
| IoT | IoT isolation segment | `10.30.0.0/24` | IoT clients |
| Media | Media device segment | `10.40.0.0/24` | TV/media devices |
| Guest | Guest isolation segment | `10.50.0.0/24` | Guest clients |
| AdBlock | Central DNS/ad-block services | `10.60.0.0/24` | Technitium DNS host |

## 5. Access Policy Summary
### Plain-language policy (current pfSense backup)
- LAN: default allow to any; DNS redirect present.
- Office: broad access policy (allow any); DNS redirect present with `CADDY_HOST` source exception.
- Family: allow own subnet, allow TCP to Office reverse proxy, allow DNS to resolver, block other RFC1918, then allow internet.
- IoT: allow own subnet, allow DNS to resolver, block other RFC1918, then allow internet.
- Media: allow own subnet, allow TCP to Office reverse proxy, allow DNS to resolver, block other RFC1918, then allow internet.
- Guest: allow own subnet, allow DNS to resolver, block other RFC1918, then allow internet.
- AdBlock: broad allow policy (pass any).

AdBlock tightening guidance:
- Current behavior is functional and intentionally permissive.
- If you want tighter posture later, start with least-disruptive controls:
- Allow required flows only (DNS, upstream resolver access, update traffic, and admin access from Office).
- Then deny broad east-west traffic from AdBlock to unrelated internal subnets.

### Recommended `OPT7` Rule Order (Moderate)
This order is for the **AdBlock interface rules** (top to bottom), using sanitized public-safe values.

Required aliases:
- `LOCAL_DNS` = `10.60.0.5`
- `PFSENSE_DNS` = `10.1.0.1` (create this if you use pfSense as Technitium upstream)
- `RFC1918` (already present in your config)

Rule order:
| # | Action | Source | Destination | Protocol/Port | Purpose |
|---|---|---|---|---|---|
| 1 | Pass | `LOCAL_DNS` | `PFSENSE_DNS` | TCP/UDP 53 | Use when Technitium forwards to pfSense |
| 2 | Pass | `LOCAL_DNS` | `!RFC1918` | TCP/UDP 53 | Use when Technitium does direct recursion |
| 3 | Pass | `LOCAL_DNS` | `!RFC1918` | TCP 443 (optional 80) | Blocklist/package/update access |
| 4 | Pass | `LOCAL_DNS` | `!RFC1918` | UDP 123 | Time sync (NTP) |
| 5 | Block (log) | `OPT7 net` | `RFC1918` | any | Prevent broad lateral movement to internal subnets |
| 6 | Remove/disable broad pass | `OPT7 net` | `any` | any | Replace current permissive `pass any` stance |

Operational notes:
- Keep **either Rule 1 or Rule 2** depending on your Technitium upstream mode.
- Client-to-DNS access remains controlled on client VLAN interfaces (LAN/Office/Family/IoT/Media/Guest), so tightening `OPT7` does not inherently break client DNS.
- Apply changes during a low-risk window and test from each VLAN after each step.

### Compact matrix (sanitized)
| Source VLAN | Own Subnet | Other Private Subnets (RFC1918) | Office Reverse Proxy | DNS Resolver (`10.60.0.5`) | Internet |
|---|---|---|---|---|---|
| LAN | Allow | Allow | Allow | Force-redirect/allow | Allow |
| Office | Allow | Allow | Allow | Force-redirect with `CADDY_HOST` exception | Allow |
| Family | Allow | Deny (except explicit allows) | Allow (TCP) | Force-redirect/allow | Allow |
| IoT | Allow | Deny (except explicit DNS) | Deny | Force-redirect/allow | Allow |
| Media | Allow | Deny (except explicit allows) | Allow (TCP) | Force-redirect/allow | Allow |
| Guest | Allow | Deny (except explicit DNS) | Deny | Force-redirect/allow | Allow |
| AdBlock | Allow | Allow | Allow | N/A (hosting resolver) | Allow |

## 6. Wireless and Media Segmentation
- UniFi U6 LR is managed and distributes VLAN-backed wireless client traffic.
- Family/Guest/IoT traffic is primarily represented as Wi-Fi client groups behind the AP.
- Media devices are grouped behind TP-Link TL-SG108.
- Office/homelab infrastructure is grouped behind TP-Link TL-SG1016DE.

## 7. DNS / Ad-Blocking Path
Current-state flow (sanitized):
1. DHCP hands clients resolver `10.60.0.5` on LAN + Office + Family + IoT + Media + Guest.
2. pfSense NAT redirects port 53 traffic to `LOCAL_DNS` on LAN + Office + Family + IoT + Media + Guest.
3. Office redirect rule excludes `CADDY_HOST` source to avoid ACME DNS-01 resolution issues.
4. `LOCAL_DNS` alias points to Technitium on AdBlock VLAN (`10.60.0.5`).
5. AdBlock host (`dns01`) is statically mapped to the resolver IP.

## 8. Reverse Proxy Notes
- Reverse proxy host is represented as `10.10.0.5` in public-safe docs.
- `CADDY_HOST` alias is used by pfSense policy and DNS redirect exception logic.
- Family and Media have explicit TCP allow rules to reverse proxy destination.
- Published hostnames remain under `home.example.com` in repository templates.

## 9. Assumptions / Unknowns
1. TL-SG108 is unmanaged; no dedicated management IP is visible in pfSense DHCP static maps (you indicated this was removed accidentally and will be added back).
2. Downstream switch port-by-port access/trunk assignments are intentionally abstracted in public docs.
3. SSID names, WLAN security settings, and AP radio policy are not stored in this repo.
4. AdBlock VLAN is intentionally broad right now; future hardening boundaries are a policy decision.

## 10. Validation Checklist
1. Confirm your preferred AdBlock hardening level: `Current`, `Moderate`, or `Strict`.
2. Confirm when TL-SG108 management IP/static map is re-added so docs can include it.
3. Confirm whether Technitium upstream mode is `Forward-to-pfSense` or `Direct recursion` (drives OPT7 Rule 1 vs Rule 2).

## 11. Rackmount Migration Guide
The full UDM Pro + USW-Aggregation + UNAS Pro migration guide (including gotchas and MermaidJS topology) is maintained in:
- `docs/network/homelab-network-unifi-rackmount-migration.md`
