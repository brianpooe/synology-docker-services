# Homelab Network

## 1. Overview
This document maps the homelab network using two sources:
- Primary truth: user-provided topology and access intent (2026-03-21).
- Repo evidence: DNS/pfSense runbooks, Caddy template, and environment templates.

High-level flow:
- Internet fiber enters through ISP ONT.
- ONT uplinks to pfSense (routing, VLANs, policy).
- pfSense uplinks to the core PoE switch.
- Core switch fans out to AP, downstream switches, homelab hosts, and DNS/ad-block node.
- DNS/ad-blocking is centralized on the AdBlock VLAN (`10.60.0.0/24`) with resolver service at `10.60.0.5` in repo docs.
- Reverse proxy is hosted on Office VLAN and is used as the controlled cross-VLAN destination for Family/Media access intent.

## Evidence Table
| Fact | Value | Source file(s) | Confidence |
|---|---|---|---|
| VLAN names and CIDRs are documented | LAN `10.1.0.0/24`, Office `10.10.0.0/24`, Family `10.20.0.0/24`, IoT `10.30.0.0/24`, Media `10.40.0.0/24`, Guest `10.50.0.0/24`, Adblock `10.60.0.0/24` | `dns/pfsense-pihole-technitium-analysis.md`, `dns/pfsense-forced-dns-all-vlans.md` | High |
| DNS resolver service IP | `10.60.0.5` | `dns/pfsense-forced-dns-all-vlans.md`, `.env.sample` | High |
| Office reverse proxy host/IP used in policy docs | `caddy.home.example.com` -> `10.10.0.5` (`CADDY_HOST`) | `dns/technitium-cutover-checklist.md`, `dns/pfsense-forced-dns-all-vlans.md` | High |
| Caddy base domain default | `home.example.com` (template/default) | `.env.sample`, `caddy/Caddyfile_template` | High |
| Caddy infra hostnames include switch and DNS/admin endpoints | `switchlite8poe`, `tplink16de`, `dns01`, `nas`, `proxmox`, `pbs`, etc. | `caddy/Caddyfile_template` | High |
| pfSense DNS interception status described in repo | Current-state analysis says DNS NAT redirect is LAN-only; runbooks define extension to VLANs | `dns/pfsense-pihole-technitium-analysis.md`, `dns/pfsense-forced-dns-all-vlans.md` | Medium-High |
| Raspberry Pi 4 2GB context for DNS/ad-blocking stack | Pi 4 2GB deployment and cutover steps are documented | `dns/end-to-end-migration-runbook.md`, `dns/technitium-deployment.md` | Medium |
| Physical hardware chain (ONT, Netgate, switches, AP, endpoints) | As specified by user | User brief (2026-03-21) | High |

## 2. Device Inventory
| Device / Group | Role | Verified details |
|---|---|---|
| Calix GigaPoint 803G GPON ONT | ISP optical termination | From user topology (not repo-verified) |
| Netgate 1100 (pfSense) | Router/firewall, VLAN gateway, policy enforcement | VLAN names/CIDRs and policy behavior are documented in `dns/*` runbooks |
| Ubiquiti UB-USW-LITE-8-POE | Core aggregation switch after pfSense | From user topology (not repo-verified) |
| UniFi U6 LR AP | Wi-Fi AP carrying multiple VLANs | From user topology (not repo-verified) |
| TP-Link TL-SG108 (unmanaged) | Media switch segment | From user topology (not repo-verified) |
| TP-Link TL-SG1016DE (managed) | Office/homelab switch segment | From user topology (not repo-verified) |
| Raspberry Pi 4 Model B (2GB) | DNS/ad-block host in AdBlock VLAN | Pi 4 2GB DNS deployment documented in `dns/technitium-deployment.md`; resolver IP `10.60.0.5` documented in `dns/*` |
| Mac mini | Endpoint connected to core switch | From user topology (not repo-verified) |
| Intel NUC | Homelab endpoint on office/homelab switch | From user topology (not repo-verified) |
| Synology DS920+ | NAS/homelab service host | Repo is Synology-focused; Caddy template maps `nas` to Office subnet prefix (`10.10.0.24:5000`) |
| Wireless family devices | Family VLAN clients | From user topology |
| Guest devices | Guest VLAN clients | From user topology |
| IoT devices | IoT VLAN clients | From user topology |
| Media devices (Samsung TV, Apple TV, soundbar, etc.) | Media VLAN clients | From user topology |

## 3. Physical Topology
Physical path (left-to-right):
1. Internet (500/500 Mbps fiber)
2. Calix GigaPoint 803G ONT
3. Netgate 1100 running pfSense
4. Ubiquiti UB-USW-LITE-8-POE (core switch)
5. Downstream from core switch:
   - UniFi U6 LR (PoE)
   - TP-Link TL-SG108 (media segment)
   - TP-Link TL-SG1016DE (office/homelab segment)
   - Mac mini
   - Raspberry Pi 4 (AdBlock VLAN; DNS/ad blocker)
6. Downstream endpoints:
   - Media clients from TL-SG108
   - Intel NUC, Synology DS920+, and other office/homelab devices from TL-SG1016DE
   - Wireless clients (Family/Guest/IoT emphasis) via U6 LR

## 4. Logical Topology / VLAN Layout
| VLAN | Purpose | CIDR | Typical residents |
|---|---|---|---|
| Office | Admin/workstation + homelab management zone | `10.10.0.0/24` (repo) | Caddy/reverse proxy host (`10.10.0.5`), NAS/services, office devices |
| Family | Family user traffic, controlled access to office reverse proxy | `10.20.0.0/24` (repo) | Family wireless clients |
| IoT | Device isolation segment | `10.30.0.0/24` (repo) | IoT clients |
| Media | Media endpoint segment with controlled access to office reverse proxy | `10.40.0.0/24` (repo) | TV/Apple TV/soundbar/media devices |
| Guest | Guest client isolation segment | `10.50.0.0/24` (repo) | Guest devices |
| AdBlock | Central DNS/ad-blocking services | `10.60.0.0/24` (repo) | Raspberry Pi DNS/ad-block node (`10.60.0.5` in repo docs) |
| LAN | Additional local segment referenced by pfSense docs | `10.1.0.0/24` (repo) | LAN services and gateway path |

Notes:
- CIDRs above are repo-documented in pfSense/DNS runbooks.
- Domain values in templates use `home.example.com` defaults; production domain is not confirmed in repo.

## 5. Access Policy Summary
### Plain-language policy intent
- Office: full internal access to itself, LAN, and all VLANs.
- Family: access to itself plus Office reverse proxy destination only.
- IoT: self-only.
- Media: access to itself plus Office reverse proxy destination only.
- Guest: self-only.
- AdBlock: access to all VLANs including LAN.

### Compact matrix (intent)
| Source VLAN | Self | LAN | Office (general) | Office reverse proxy | Family | IoT | Media | Guest | AdBlock |
|---|---|---|---|---|---|---|---|---|---|
| Office | Allow | Allow | Allow | Allow | Allow | Allow | Allow | Allow | Allow |
| Family | Allow | Deny | Deny | Allow | Deny | Deny | Deny | Deny | Allow (DNS path expected) |
| IoT | Allow | Deny | Deny | Deny | Deny | Deny | Deny | Deny | Allow (DNS path expected) |
| Media | Allow | Deny | Deny | Allow | Deny | Deny | Deny | Deny | Allow (DNS path expected) |
| Guest | Allow | Deny | Deny | Deny | Deny | Deny | Deny | Deny | Allow (DNS path expected) |
| AdBlock | Allow | Allow | Allow | N/A | Allow | Allow | Allow | Allow | Allow |

Policy traceability:
- Intent rows come from the user brief.
- DNS exceptions are supported by repo pfSense runbooks that explicitly permit/redirect DNS to `10.60.0.5`.

## 6. Wireless and Media Segmentation
- UniFi U6 LR is the wireless entry point carrying multiple VLANs, with practical emphasis on Family, Guest, and IoT traffic per user topology.
- Media devices are grouped behind TP-Link TL-SG108 (unmanaged), treated as Media VLAN clients in the logical model.
- Office/homelab infrastructure is grouped behind TP-Link TL-SG1016DE (managed) for Intel NUC, Synology DS920+, and related systems.

## 7. DNS / Ad-Blocking Path
Verified flow from repo docs:
1. Clients receive DNS settings that point to resolver IP `10.60.0.5` (pfSense + DNS runbook docs).
2. DNS/ad-block service runs in the AdBlock VLAN (`10.60.0.0/24`) on Raspberry Pi-hosted stack (Pi-hole current, Technitium target).
3. Local split DNS maps reverse-proxied app names toward the Office-hosted reverse proxy (`caddy.home.example.com` -> `10.10.0.5`).

Repo-derived details:
- Resolver IP: `10.60.0.5`
- Reverse proxy DNS anchor: `caddy.home.example.com`
- Upstream strategy references include forwarding via pfSense (`10.1.0.1`) or direct recursion (migration option)
- Blocklist reference: StevenBlack hosts list

## 8. Reverse Proxy Notes
Repo-verified reverse proxy context:
- Caddy config template defines many internal service hostnames under `{{CADDY_BASE_DOMAIN}}`.
- Office-hosted reverse proxy target is consistently represented as `10.10.0.5` in pfSense DNS runbooks.
- Caddy upstream targets include:
  - `nas` -> `10.10.0.24:5000`
  - `proxmox` -> `10.10.0.10:8006`
  - `pbs` -> `10.10.0.8:8007`
  - multiple media/app services on office subnet hosts

Important domain caveat:
- Repo templates/defaults use `home.example.com`.
- `home.brianpooe.com` was not found in this repository.

## 9. Assumptions / Unknowns
1. Physical hardware chain is treated as authoritative from user brief because repo does not include hardware inventory files for ONT/switch/AP/endpoint cabling.
2. No switch port assignments, trunk/access mode per port, or VLAN tagging maps were found.
3. No SSIDs, Wi-Fi security settings, or AP radio policy details were found.
4. No definitive production base domain value was found (only template default `home.example.com`).
5. pfSense runbook docs indicate current-state DNS NAT redirect is LAN-only in one analysis, while other runbooks define desired all-VLAN forced DNS; active state at this moment is not directly verifiable from this repo alone.
6. IPs for Mac mini, Intel NUC, DS920+, and most endpoints are not directly verified in repo.
7. Firewall rule IDs/order numbers are not provided in repo; only intent and runbook-level policy are documented.

## 10. Validation Checklist
Use this quick checklist to close remaining gaps:

1. Confirm production domain: is internal DNS/reverse proxy domain still `home.example.com`, or another value (for example `home.brianpooe.com`)?
2. Confirm active pfSense state: are forced DNS NAT rules currently active on LAN only, or LAN + Office/Family/IoT/Media/Guest?
3. Confirm reverse proxy host placement: is Caddy currently at `10.10.0.5` on Office VLAN?
4. Confirm DNS resolver host/IP: is Raspberry Pi 4 (2GB) currently serving DNS at `10.60.0.5`?
5. Confirm whether IoT and Guest are strict self-only or self-only plus DNS exception to AdBlock VLAN.
6. Confirm switch uplink/trunk and access-port mappings (USW Lite 8 PoE, TL-SG108, TL-SG1016DE).
7. Confirm endpoint IPs/hostnames for Mac mini, Intel NUC, Synology DS920+ for diagram annotations.
8. Confirm whether any direct LAN segment clients/services should be drawn explicitly beyond VLAN interfaces.
