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
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
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
./substitute_env.sh docker-compose-files/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml
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

- `network_mode: service:gluetun` can fail during single-service recreate/update flows on some Synology setups.

Fix:

```bash
# Ensure template uses container mode for qbittorrent:
# network_mode: "container:gluetun"

# Re-render compose and recreate the pair
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml .env
docker-compose -f docker-compose.arr-stack.yml up -d --force-recreate gluetun qbittorrent
```

Verify:

```bash
docker-compose -f docker-compose.arr-stack.yml ps gluetun qbittorrent
docker-compose -f docker-compose.arr-stack.yml logs --tail 100 qbittorrent
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
caddy validate --config caddy/Caddyfile
```

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
