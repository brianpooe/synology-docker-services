# Docker Socket Proxy Guide

## Why this exists

Mounting `/var/run/docker.sock` directly into a container gives that container broad control over the Docker daemon. In this repo, Docker API access is restricted through `lscr.io/linuxserver/socket-proxy`.

## Current implementation in this repo

`docker-compose-files/arr-stack_template.yaml` includes:

- `socket-proxy` on an internal network (`socket_proxy_network`)
- `diun` connected to the proxy via `tcp://socket-proxy:2375`
- Read-only Docker socket mount: `/var/run/docker.sock:/var/run/docker.sock:ro`

### Enabled API permissions

The template is configured for Diun read-only monitoring:

```yaml
environment:
  CONTAINERS: 1
  IMAGES: 1
  POST: 0
  EXEC: 0
  SECRETS: 0
  NETWORKS: 0
  SERVICES: 0
  TASKS: 0
```

This allows Diun to discover container/image updates while blocking write operations and dangerous endpoints.

## Deploy

```bash
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml up -d
```

## Verify

### 1. Check containers

```bash
docker ps | grep -E "socket-proxy|diun"
```

### 2. Check health

```bash
docker inspect socket-proxy | grep -A 10 Health
```

### 3. Confirm allowed endpoint works

```bash
docker exec diun wget -qO- http://socket-proxy:2375/version
```

### 4. Confirm blocked endpoint is denied

```bash
docker exec diun wget -qO- http://socket-proxy:2375/containers/diun/exec
# expected: HTTP 403 Forbidden
```

## Troubleshooting

### Diun cannot connect to socket-proxy

Symptoms:

- Diun logs show Docker provider errors
- DNS lookup failure for `socket-proxy`

Checks:

```bash
docker logs diun
docker logs socket-proxy
docker inspect diun | grep -A 20 Networks
```

Fixes:

- Ensure `diun` and `socket-proxy` are on the same network in the generated compose file.
- Ensure `socket-proxy` is healthy before `diun` starts.

### `403 Forbidden` on expected calls

If `version` or container listing fails with 403, verify proxy env flags:

```bash
docker exec socket-proxy env | grep -E "CONTAINERS|IMAGES|POST|EXEC|SECRETS"
```

For this repo, `CONTAINERS=1` and `IMAGES=1` are required.

### socket-proxy will not start

```bash
ls -la /var/run/docker.sock
docker logs socket-proxy
```

On Synology, ensure Docker/Container Manager is running and the socket path exists.

## Security notes

- Keep the proxy network internal (`internal: true`).
- Do not publish port `2375` to the host/network.
- Prefer least privilege; only enable endpoints that a consumer actually needs.

---

**Last Updated:** 2026-02-14
**Compatibility:** Synology DSM 7.x, Docker Compose 1.27.0+
