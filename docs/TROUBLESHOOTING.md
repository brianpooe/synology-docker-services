# Docker Stack Troubleshooting Guide

## Quick diagnostics

Run these first:

```bash
docker ps -a
docker stats --no-stream
docker network ls
docker-compose -f docker-compose.arr-stack.yml config
```

## Common issues

### 1. Variables not substituted

Symptoms:

- Generated file still contains `{{VAR}}`
- Container fails due to missing env values

Fix:

```bash
./substitute_env.sh docker-compose-files/arr-stack/template.yaml docker-compose.arr-stack.yml
```

The script prints any unresolved placeholders. Add missing keys to `.env` (or provide defaults in templates).

### 2. Recyclarr errors (`base_url must start with http`)

Use service names, not `localhost`:

```yaml
sonarr:
  sonarr-main:
    base_url: http://sonarr:8989

radarr:
  radarr-main:
    base_url: http://radarr:7878
```

Generate your file from this repo template:

```bash
./substitute_env.sh docker-compose-files/arr-stack/config/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml
```

### 2b. Recyclarr errors (`Unable to find include template ...`)

Symptoms:

- `Unable to find include template with name 'radarr-quality-definition-movie'`
- Similar errors for other `include: - template:` entries

Cause:

- You are using an older pre-v8 `recyclarr.yml` that still has `include: - template:` entries.
- Recyclarr v8 removed official include templates from the default provider.

Fix (v8 path used by this repository):

```bash
# 1) Regenerate recyclarr config from the v8 template
./substitute_env.sh docker-compose-files/arr-stack/config/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml

# 2) Regenerate compose and recreate recyclarr (v8.4.0 pin)
./substitute_env.sh docker-compose-files/arr-stack/template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml pull recyclarr
docker-compose -f docker-compose.arr-stack.yml up -d recyclarr
```

### 3. qBittorrent/SAB not using VPN IP

In this template, only download clients are expected behind VPN tunnel.

- Behind VPN: `gluetun`, `qbittorrent`
- Not behind VPN by default: `radarr`, `sonarr`, `prowlarr`, `bazarr`, `emby`, `seerr`

Checks:

```bash
docker logs gluetun | grep -i connected
docker exec qbittorrent curl -s ifconfig.me
```

### 4. Dependency/healthcheck startup failures

Symptoms:

- `dependency failed to start`
- Services wait forever on `service_healthy`

Checks:

```bash
docker inspect gluetun | grep -A 20 Health
docker inspect prowlarr | grep -A 20 Health
docker logs <container_name>
```

Fixes:

- Increase `start_period` for slow-start services.
- Test healthcheck command inside the container.
- Validate generated compose YAML syntax with `docker-compose ... config`.

### 5. Network communication failures

Checks:

```bash
docker network inspect vpn_network
docker exec radarr wget -qO- http://prowlarr:9696/ping
```

Fixes:

- Ensure relevant services are on `vpn-network` in generated compose.
- Recreate stack networks:

```bash
docker-compose -f docker-compose.arr-stack.yml down
docker network prune
docker-compose -f docker-compose.arr-stack.yml up -d
```

### 5b. qBittorrent stuck in "Created" / `network service:gluetun not found`

Symptoms:

- `qbittorrent` does not start after updates and remains in `Created`
- Recreate shows: `Error response from daemon: network service:gluetun not found`

Cause:

- `network_mode: service:gluetun` can fail during single-service recreate/update flows on some Docker setups.

Fix:

```bash
# Ensure template uses container mode for qbittorrent:
# network_mode: "container:gluetun"

# Re-render compose and recreate the pair
./substitute_env.sh docker-compose-files/arr-stack/template.yaml docker-compose.arr-stack.yml .env
docker-compose -f docker-compose.arr-stack.yml up -d --force-recreate gluetun qbittorrent
```

Verify:

```bash
docker-compose -f docker-compose.arr-stack.yml ps gluetun qbittorrent
docker-compose -f docker-compose.arr-stack.yml logs --tail 100 qbittorrent
```

### 5c. qBittorrent HTTPS `502` after stack updates

Symptoms:

- qBittorrent opens via HTTPS reverse proxy URL and returns `502` after stack updates/recreates.

Common causes:

- `gluetun` and `qbittorrent` are out of sync after recreate/update and need a paired restart.
- qBittorrent WebUI can be left in HTTPS mode while your reverse proxy still targets HTTP upstream.

Fix:

```bash
# 1) Recreate the VPN + torrent pair together
docker-compose -f docker-compose.arr-stack.yml up -d --force-recreate gluetun qbittorrent

# 2) If 502 persists, force qBittorrent WebUI back to HTTP
CONF="$(find /volume1/docker/appdata/qbittorrent -type f -name 'qBittorrent.conf' | head -n1)"
echo "Using config: $CONF"
sudo sed -i 's#^WebUI\\HTTPS\\Enabled=.*#WebUI\\HTTPS\\Enabled=false#' "$CONF"
sudo sed -i 's#^WebUI\\HTTPS\\CertificatePath=.*#WebUI\\HTTPS\\CertificatePath=#' "$CONF"
sudo sed -i 's#^WebUI\\HTTPS\\KeyPath=.*#WebUI\\HTTPS\\KeyPath=#' "$CONF"
docker-compose -f docker-compose.arr-stack.yml restart qbittorrent
```

Verify:

```bash
docker-compose -f docker-compose.arr-stack.yml ps gluetun qbittorrent
docker-compose -f docker-compose.arr-stack.yml logs --tail 120 qbittorrent
```

### 6. Data/config persistence problems

Checks:

```bash
docker inspect radarr | grep -A 20 Mounts
ls -la /volume1/docker/appdata/radarr
```

Fixes:

```bash
mkdir -p /volume1/docker/appdata/radarr
chown -R <PUID>:<PGID> /volume1/docker/appdata/radarr
```

For pgAdmin specifically:

```bash
chown -R 5050:5050 /volume1/docker/appdata/pgadmin
```

### 7. Caddy reverse proxy issues

If Caddy refuses to start, validate syntax first:

```bash
./substitute_env.sh caddy/Caddyfile_template caddy/Caddyfile .env
caddy validate --config caddy/Caddyfile
```

If certificate issuance fails with errors like:

- `could not determine zone for domain ...` / `expected 1 zone, got 0`
- `dial tcp 1.0.0.1:53: i/o timeout`

these are two distinct failure modes with the same underlying cause: Caddy's DNS-01 resolver
cannot reach `1.1.1.1`/`1.0.0.1` on port 53.

**Distinguish the two errors:**

| Error | Meaning |
|---|---|
| `expected 1 zone, got 0` | Caddy reached a resolver, but it was Technitium (split-DNS). NAT exception misconfigured or alias IP wrong. |
| `dial tcp 1.0.0.1:53: i/o timeout` | Caddy's packets are being dropped. A firewall block rule on OPT2 is above the pass rule, or the NAT exception is not set up at all. |

Check DNS reachability from the Caddy host:

```bash
# Must return Cloudflare SOA, not Technitium SOA (dns01.home.example.com)
dig +short SOA home.example.com @1.1.1.1

# Distinguish firewall drop from redirect:
dig @1.1.1.1 +tcp +time=5 google.com   # timeout = firewall drop
dig @1.1.1.1 +notcp +time=5 google.com # timeout = same; success = TCP-specific block
```

Keep public resolvers in the Caddy TLS block — do not switch to Technitium as a workaround,
as it causes `expected 1 zone, got 0` because Technitium is authoritative for the internal zone:

```caddy
tls you@example.com {
  dns cloudflare {env.CLOUDFLARE_DNS_TOKEN}
  resolvers 1.1.1.1 1.0.0.1
}
```

If your VLAN uses forced DNS redirection, two pfSense changes are both required:

1. **NAT source-invert exception** on OPT2 — edit the `Force DNS to LOCAL_DNS (OFFICE)` rule,
   set Source → Invert Match = **checked**, Source = `CADDY_HOST`. The `Invert Match` checkbox
   is critical and easy to miss; leaving it unchecked reverses the logic entirely.

2. **Explicit PASS rule** on `Firewall > Rules > OPT2`, placed above any block rules:
   Source = `CADDY_HOST`, Destination = any, Port = DNS (53), Action = Pass.
   Without this, a block rule above the general `allow any` will drop Caddy's packets even
   when the NAT exception is correctly configured, producing the `i/o timeout` error.

See: [pfsense-forced-dns-quick-entry.md](../dns/pfsense-forced-dns-quick-entry.md) section 1b.

If a proxied app fails over HTTPS with self-signed backend certs, ensure the target block uses:

```caddy
transport http {
  tls_insecure_skip_verify
}
```

## Update flow (safe)

1. Generate compose files from templates.
2. Validate with `docker-compose -f <file> config`.
3. Pull images.
4. Recreate services.
5. Review logs after startup.

```bash
docker-compose -f docker-compose.arr-stack.yml pull
docker-compose -f docker-compose.arr-stack.yml up -d
```

---

**Last Updated:** 2026-02-14
