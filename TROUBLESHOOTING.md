# Docker Compose Troubleshooting Guide

## Common Issues and Solutions

### 1. Watchtower Cannot Update Jellyseerr

**Issue:** Watchtower fails to update `hotio/jellyseerr` with errors like "image not found" or "unauthorized".

**Root Cause:** The `hotio/jellyseerr` image on Docker Hub is unofficial/outdated. The official Jellyseerr image is under a different registry.

**Solution:**

The template has been updated to use the official image:

```yaml
jellyseerr:
  image: fallenbagel/jellyseerr:latest  # ✅ Official image
```

**Alternative Options:**

1. **Official Jellyseerr (Recommended)**
   ```yaml
   image: fallenbagel/jellyseerr:latest
   ```

2. **Hotio GHCR Version**
   ```yaml
   image: ghcr.io/hotio/jellyseerr:latest
   ```

**Action Required:**
1. Stop the container: `docker-compose down jellyseerr`
2. Update your compose file with the new image
3. Pull new image: `docker pull fallenbagel/jellyseerr:latest`
4. Start container: `docker-compose up -d jellyseerr`

**Synology-Specific Note:**
In Synology Container Manager, you may need to manually remove the old container and create a new one with the correct image if the name doesn't match.

---

### 2. Recyclarr Configuration Errors

**Issue:** Recyclarr logs show errors like:

```
└── X base_url must start with 'http' or 'https'
```

**Root Causes:**

1. ❌ **Using `localhost` in Docker**: `base_url: http://localhost:8989` won't work
2. ❌ **Empty API keys**: `api_key:` with no value
3. ❌ **Wrong config file location**: Config not mounted properly

**Solution:**

#### Step 1: Fix base_url (Use Docker Service Names)

**Wrong:**
```yaml
base_url: http://localhost:8989  # ❌ Won't work in Docker
```

**Correct:**
```yaml
base_url: http://sonarr:8989     # ✅ Use service name from docker-compose
base_url: http://radarr:7878     # ✅ Use service name from docker-compose
```

#### Step 2: Get API Keys

**For Sonarr:**
1. Open Sonarr WebUI (http://your-nas:8989)
2. Go to: Settings → General → Security
3. Copy the **API Key**

**For Radarr:**
1. Open Radarr WebUI (http://your-nas:7878)
2. Go to: Settings → General → Security
3. Copy the **API Key**

#### Step 3: Update Configuration File

Location: `{{DOCKERCONFDIR}}/recyclarr/recyclarr.yml`

```yaml
sonarr:
  web-1080p-v4:
    base_url: http://sonarr:8989
    api_key: abc123def456ghi789jkl012mno345pq  # Your actual API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: sonarr-quality-definition-series
      - template: sonarr-v4-quality-profile-web-1080p
      - template: sonarr-v4-custom-formats-web-1080p

radarr:
  uhd-bluray-web:
    base_url: http://radarr:7878
    api_key: xyz789abc456def123ghi890jkl567mno  # Your actual API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: radarr-quality-definition-movie
      - template: radarr-quality-profile-uhd-bluray-web
      - template: radarr-custom-formats-uhd-bluray-web
```

#### Step 4: Test Configuration

```bash
# Test Recyclarr config
docker exec -it recyclarr recyclarr config list

# Test sync (dry run)
docker exec -it recyclarr recyclarr sync --preview

# Actually sync
docker exec -it recyclarr recyclarr sync
```

#### Step 5: Fix Volume Mount (if needed)

Ensure your docker-compose has the correct volume mount:

```yaml
recyclarr:
  volumes:
    - {{DOCKERCONFDIR}}/recyclarr:/config  # Config file should be in this directory
```

Your config file should be at:
```
{{DOCKERCONFDIR}}/recyclarr/recyclarr.yml
```

**Template Provided:** A proper config template has been created at:
```
config-files/recyclarr/recyclarr.yml.template
```

---

### 3. Docker Image Source Reliability

#### ✅ Recommended Image Sources

| Service | Recommended Image | Registry | Notes |
|---------|------------------|----------|-------|
| Sonarr | `ghcr.io/hotio/sonarr:latest` | GitHub | Hotio official GHCR |
| Radarr | `ghcr.io/hotio/radarr:latest` | GitHub | Hotio official GHCR |
| Prowlarr | `ghcr.io/hotio/prowlarr:latest` | GitHub | Hotio official GHCR |
| Bazarr | `ghcr.io/hotio/bazarr:nightly` | GitHub | Hotio official GHCR |
| qBittorrent | `ghcr.io/hotio/qbittorrent:latest` | GitHub | Hotio official GHCR |
| SABnzbd | `ghcr.io/hotio/sabnzbd:latest` | GitHub | Hotio official GHCR |
| Jellyseerr | `fallenbagel/jellyseerr:latest` | Docker Hub | Official Jellyseerr |
| Emby | `lscr.io/linuxserver/emby:latest` | LinuxServer | LinuxServer.io official |
| PostgreSQL | `postgres:17-alpine` | Docker Hub | Official PostgreSQL |
| Vault | `hashicorp/vault:1.19.2` | Docker Hub | Official HashiCorp |
| Gluetun | `qmcgaw/gluetun:latest` | Docker Hub | Well-maintained |
| FlareSolverr | `flaresolverr/flaresolverr:latest` | Docker Hub | Official |
| Watchtower | `containrrr/watchtower:latest` | Docker Hub | Official |
| Recyclarr | `ghcr.io/recyclarr/recyclarr:latest` | GitHub | Official |
| pgAdmin | `dpage/pgadmin4:9.2.0` | Docker Hub | Official |

#### ⚠️ Images to Avoid

| Image | Issue | Use Instead |
|-------|-------|-------------|
| `hotio/jellyseerr` | Outdated/unofficial on Docker Hub | `fallenbagel/jellyseerr:latest` |
| `linuxserver/sonarr` | Use Hotio for better updates | `ghcr.io/hotio/sonarr:latest` |
| Untagged images (`:latest` implied) | Unpredictable updates | Always specify `:latest` explicitly |

---

### 4. Synology Container Manager Issues

#### Issue: Watchtower Permissions on Synology

**Symptom:** Watchtower cannot update containers, shows permission errors.

**Solution 1: Run Watchtower with Elevated Permissions**

In your docker-compose:

```yaml
watchtower:
  image: containrrr/watchtower:latest
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro  # ✅ Read-only is safer
  # On Synology, you may need:
  user: root  # Add this if permission errors occur
```

**Solution 2: Use Synology's Built-in Container Updates**

Instead of Watchtower, use Synology Container Manager's built-in auto-update feature:
1. Open Container Manager
2. Select container
3. Settings → Enable auto-restart
4. Configure update schedule in Container Manager settings

**Solution 3: Manual Updates via Synology**

```bash
# SSH into Synology
cd /volume1/docker/compose-files
docker-compose pull
docker-compose up -d
```

#### Issue: Health Checks Not Working on Synology

**Symptom:** Services marked as "unhealthy" or health checks ignored.

**Cause:** Synology DSM 7.x has limited Docker Compose version support.

**Solution:**

1. Check Docker Compose version:
   ```bash
   docker-compose --version
   ```

2. If version < 1.27.0, upgrade or simplify health checks:
   ```yaml
   healthcheck:
     test: ["CMD-SHELL", "curl -f http://localhost:8989 || exit 1"]
     interval: 30s
     timeout: 10s
     retries: 3
     # Remove start_period if not supported
   ```

3. Alternatively, remove `condition: service_healthy` and use simple `depends_on`:
   ```yaml
   depends_on:
     - prowlarr  # Without condition
   ```

---

### 5. Service Won't Start - Dependency Issues

**Issue:** Service fails with "dependency failed to start" or "waiting for service health".

**Diagnosis:**

```bash
# Check service status
docker ps -a

# Check logs
docker logs <container_name>

# Check health
docker inspect <container_name> | grep -A 10 Health
```

**Solutions:**

1. **Increase start_period:**
   ```yaml
   healthcheck:
     start_period: 90s  # Give service more time to initialize
   ```

2. **Check healthcheck command:**
   ```bash
   # Test healthcheck manually
   docker exec <container> curl -f http://localhost:8989/ping
   ```

3. **Temporary workaround - Remove health conditions:**
   ```yaml
   depends_on:
     - prowlarr  # Simple dependency without health check
   ```

---

### 6. Network Connectivity Issues

**Issue:** Services can't communicate (e.g., Radarr can't reach Prowlarr).

**Diagnosis:**

```bash
# Check networks
docker network ls

# Inspect network
docker network inspect vpn_network

# Test connectivity from inside container
docker exec radarr ping prowlarr
docker exec radarr curl http://prowlarr:9696/ping
```

**Solutions:**

1. **Ensure all services on same network:**
   ```yaml
   services:
     radarr:
       networks:
         - vpn-network  # ✅ Same network
     prowlarr:
       networks:
         - vpn-network  # ✅ Same network
   ```

2. **Recreate network:**
   ```bash
   docker-compose down
   docker network prune
   docker-compose up -d
   ```

3. **Check VPN container network mode:**

   qBittorrent uses `network_mode: service:gluetun`, meaning:
   - It shares Gluetun's network
   - Accessed via `http://<synology-ip>:8080`, NOT `http://qbittorrent:8080`
   - Other services need to use Gluetun's IP or host IP

---

### 7. Resource Limit Issues

**Issue:** Container keeps restarting or shows OOM (Out of Memory) errors.

**Diagnosis:**

```bash
# Check resource usage
docker stats

# Check logs for OOM
docker logs <container> | grep -i "out of memory\|oom\|killed"
```

**Solutions:**

1. **Increase memory limits:**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 2G  # Increase if needed
   ```

2. **Monitor before setting limits:**
   ```bash
   # Run without limits first, monitor actual usage
   docker stats --no-stream
   ```

3. **Adjust based on workload:**
   - Emby transcoding: 4-8GB
   - Download clients: 1-2GB
   - Arr services: 512MB-1GB
   - Utility services: 256-512MB

---

### 8. Configuration Persistence Issues

**Issue:** Container loses configuration after restart.

**Diagnosis:**

```bash
# Check volume mounts
docker inspect <container> | grep -A 20 Mounts

# Check host directory permissions
ls -la {{DOCKERCONFDIR}}/service-name
```

**Solutions:**

1. **Verify volume paths:**
   ```yaml
   volumes:
     - {{DOCKERCONFDIR}}/radarr:/config  # ✅ Host:Container
   ```

2. **Check directory exists:**
   ```bash
   mkdir -p {{DOCKERCONFDIR}}/radarr
   chown -R {{PUID}}:{{PGID}} {{DOCKERCONFDIR}}/radarr
   ```

3. **Synology-specific permissions:**
   ```bash
   # For pgAdmin
   chown -R 5050:5050 {{DOCKERCONFDIR}}/pgadmin

   # For other services
   chown -R {{PUID}}:{{PGID}} {{DOCKERCONFDIR}}/service-name
   ```

---

## Quick Fixes Checklist

### Before Opening an Issue

- [ ] Check container logs: `docker logs <container>`
- [ ] Verify all environment variables are set in `.env`
- [ ] Confirm volume paths exist and have correct permissions
- [ ] Test health checks manually inside container
- [ ] Check network connectivity between services
- [ ] Verify image is pulled correctly: `docker images`
- [ ] Try recreating container: `docker-compose up -d --force-recreate <service>`
- [ ] Check Synology Container Manager for any specific errors

### Common Commands

```bash
# View logs
docker logs -f <container>

# Restart service
docker-compose restart <service>

# Recreate service
docker-compose up -d --force-recreate <service>

# Full restart
docker-compose down && docker-compose up -d

# Check health
docker ps
docker inspect <container> | grep -A 10 Health

# Shell into container
docker exec -it <container> /bin/bash
# or
docker exec -it <container> /bin/sh

# View resource usage
docker stats

# Check networks
docker network ls
docker network inspect <network_name>
```

---

## Getting Help

When reporting issues, include:

1. **Synology Model & DSM Version**
2. **Docker & Docker Compose versions**
3. **Complete error logs** (`docker logs <container>`)
4. **Relevant compose file snippet**
5. **Environment variables** (redact sensitive values)
6. **Output of**: `docker ps -a`, `docker stats`, `docker network ls`

---

**Last Updated:** 2025-11-23
