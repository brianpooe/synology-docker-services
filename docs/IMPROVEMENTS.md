# Docker Compose Improvements

## Overview
This document outlines the comprehensive improvements made to all Docker Compose template files in this repository. These changes follow best practices for production-ready containerized applications, with special consideration for Synology NAS deployments.

## Summary of Changes

### Global Improvements Applied to All Templates

1. **Version Specification**
   - Added `version: '3.8'` to all compose files for compatibility and feature support
   - Enables advanced features like healthchecks, resource limits, and dependency conditions

2. **Environment Variable Format**
   - Converted from array format (`- KEY=value`) to map format (`KEY: value`)
   - Improves readability and maintainability
   - Consistent with Docker Compose v3+ best practices

3. **Resource Limits**
   - Added CPU and memory limits/reservations to all services
   - Prevents resource exhaustion and ensures system stability
   - Tailored limits based on typical service requirements

4. **Health Checks**
   - Implemented comprehensive healthcheck configurations
   - Includes proper `start_period` to allow services time to initialize
   - Services can now properly wait for dependencies to be healthy

5. **Dependency Management**
   - Upgraded `depends_on` to use `condition: service_healthy`
   - Ensures services start only when dependencies are ready
   - Prevents cascading failures and startup issues

6. **Security Hardening**
   - Added `security_opt: no-new-privileges:true` to all services
   - Prevents privilege escalation attacks
   - Read-only mounts where appropriate (e.g., docker.sock)

7. **Logging Configuration**
   - Standardized logging across all services using json-file driver
   - Uses centralized DOCKERLOGGING_MAXFILE and DOCKERLOGGING_MAXSIZE variables
   - Prevents disk space exhaustion from unlimited logs

8. **Labels for Organization**
   - Added descriptive labels to all services and networks
   - Format: `com.synology.stack` and `com.synology.service`
   - Improves service discovery and management in Synology DSM

9. **Restart Policies**
   - Standardized to `unless-stopped` across all services
   - More predictable behavior than `always`
   - Services won't auto-restart if manually stopped

10. **Network Configuration**
    - Moved network definitions to bottom of files (convention)
    - Added explicit network names and labels
    - Better organization and documentation

11. **Image Version Tags**
    - Added `:latest` tag where missing for clarity
    - Explicit version pinning where stability is critical (e.g., Vault)

---

## File-Specific Improvements

### 1. postgres_template.yaml

**Services Modified:** postgres, pgadmin

**Key Changes:**
- **PostgreSQL**
  - Added healthcheck using `pg_isready`
  - Resource limits: 2 CPU cores, 2GB RAM (max)
  - Added `start_period: 30s` for initialization time

- **pgAdmin**
  - Enhanced healthcheck using wget to ping endpoint
  - Added configuration for server mode and master password
  - Depends on postgres with `service_healthy` condition
  - Resource limits: 1 CPU core, 1GB RAM (max)

- **Network**
  - Named network: `postgres_network`
  - Added descriptive label

**Example Healthcheck:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U {{POSTGRES_USER}} -d {{POSTGRES_DB}}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

---

### 2. arr-stack_template.yaml

**Services Modified:** gluetun, qbittorrent, flaresolverr, sabnzbd, prowlarr, radarr, sonarr, bazarr, emby, jellyseerr, recyclarr, watchtower

**Key Changes:**

#### VPN Services
- **Gluetun**
  - Healthcheck: Verifies internet connectivity through VPN
  - Resource limits: 1 CPU, 512MB RAM
  - Added TZ environment variable
  - Proper port documentation with comments

- **qBittorrent**
  - Depends on gluetun with health condition
  - Uses gluetun's network (`network_mode: service:gluetun`)
  - Resource limits: 2 CPUs, 1GB RAM for download processing

#### Indexer & Download Clients
- **FlareSolverr**
  - Added healthcheck using API endpoint
  - Resource limits: 1 CPU, 1GB RAM
  - Comprehensive environment configuration

- **SABnzbd**
  - Healthcheck monitors API availability
  - Resource limits: 2 CPUs, 2GB RAM for extraction

- **Prowlarr**
  - Depends on flaresolverr health
  - Added proper API healthcheck
  - Longer start_period (60s) for initialization

#### Media Management (Arr Stack)
- **Radarr & Sonarr**
  - Depend on both prowlarr and gluetun health
  - Consistent healthcheck implementation
  - Resource limits: 1 CPU, 1GB RAM each
  - Start period: 60s for database initialization

- **Bazarr**
  - Depends on both radarr and sonarr health
  - API-based healthcheck
  - Lighter resource limits: 0.5 CPU, 512MB RAM

#### Media Server
- **Emby**
  - Higher resource allocation: 4 CPUs, 4GB RAM
  - Longer start_period (90s) for library scanning
  - Hardware transcoding device properly mounted
  - Healthcheck monitors API health

- **Jellyseerr**
  - Depends on emby health
  - API status endpoint healthcheck
  - Resource limits: 0.5 CPU, 512MB RAM

#### Maintenance Tools
- **Recyclarr**
  - Depends on both radarr and sonarr health
  - Lightweight: 0.5 CPU, 256MB RAM
  - Proper user mapping with quotes

- **Watchtower**
  - Read-only docker.sock mount for security
  - Additional safety environment variables
  - Resource limits: 0.5 CPU, 256MB RAM

**Network:**
- Named network: `vpn_network`
- Bridge driver for container isolation
- Labeled for media stack

---

### 3. vault_template.yaml

**Services Modified:** vault

**Key Changes:**
- Added dedicated `vault_network`
- Removed PUID/PGID (not applicable to Vault image)
- Added Vault-specific environment variables:
  - `VAULT_LOG_LEVEL: info`
  - `VAULT_SKIP_VERIFY: "false"`
- Comprehensive healthcheck using Vault's health API
- Resource limits: 1 CPU, 512MB RAM
- Longer start_period (60s) for Vault initialization
- Security hardening with `no-new-privileges`
- Labeled as security stack

**Example Healthcheck:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider https://localhost:8200/v1/sys/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

---

## Resource Allocation Guide

The following table shows the resource allocations for each service:

| Service | CPU Limit | Memory Limit | CPU Reserve | Memory Reserve |
|---------|-----------|--------------|-------------|----------------|
| postgres | 2.0 | 2G | 0.5 | 512M |
| pgadmin | 1.0 | 1G | 0.25 | 256M |
| gluetun | 1.0 | 512M | 0.25 | 128M |
| qbittorrent | 2.0 | 1G | 0.5 | 256M |
| flaresolverr | 1.0 | 1G | 0.25 | 256M |
| sabnzbd | 2.0 | 2G | 0.5 | 512M |
| prowlarr | 1.0 | 512M | 0.25 | 128M |
| radarr | 1.0 | 1G | 0.25 | 256M |
| sonarr | 1.0 | 1G | 0.25 | 256M |
| bazarr | 0.5 | 512M | 0.1 | 128M |
| emby | 4.0 | 4G | 1.0 | 1G |
| jellyseerr | 0.5 | 512M | 0.1 | 128M |
| recyclarr | 0.5 | 256M | 0.1 | 64M |
| watchtower | 0.5 | 256M | 0.1 | 64M |
| vault | 1.0 | 512M | 0.25 | 128M |

**Total Resources (if all services running):**
- Total CPU Limit: 19.5 cores
- Total Memory Limit: 18.75GB
- Total CPU Reserved: 4.6 cores
- Total Memory Reserved: 4.44GB

---

## Security Improvements

1. **Privilege Escalation Prevention**
   - All services have `no-new-privileges:true` security option
   - Prevents containers from gaining additional privileges

2. **Read-Only Mounts**
   - Docker socket mounted read-only in Watchtower
   - `/etc/localtime` always mounted read-only
   - Reduces attack surface

3. **Network Isolation**
   - Separate networks for different stacks:
     - `postgres_network` - Database services
     - `vpn_network` - Media services
     - `vault_network` - Secrets management
   - Services only communicate within their network

4. **Resource Limits**
   - Prevents DoS through resource exhaustion
   - Ensures critical services always have resources available

---

## Healthcheck Strategy

All healthchecks follow this pattern:

```yaml
healthcheck:
  test: [appropriate health test command]
  interval: 30s       # How often to check (10-60s typical)
  timeout: 10s        # Max time for check to complete
  retries: 3          # Failed checks before unhealthy
  start_period: 30-90s # Grace period for service startup
```

**Start Period Guidelines:**
- Simple services: 30s (e.g., FlareSolverr)
- Database services: 30-60s (e.g., Postgres)
- Arr services: 60s (database initialization)
- Media servers: 90s (library scanning)

---

## Migration Guide

### Before Applying Changes

1. **Backup Current Configuration**
   ```bash
   cp .env .env.backup
   tar -czf docker-configs-backup.tar.gz docker-compose-files/
   ```

2. **Stop All Services**
   ```bash
   docker-compose down
   ```

3. **Generate New Compose Files**
   ```bash
   ./substitute_env.sh docker-compose-files/postgres_template.yaml docker-compose.postgres.yml
   ./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
   ./substitute_env.sh docker-compose-files/vault_template.yaml docker-compose.vault.yml
   ```

4. **Validate Compose Files**
   ```bash
   docker-compose -f docker-compose.postgres.yml config
   docker-compose -f docker-compose.arr-stack.yml config
   docker-compose -f docker-compose.vault.yml config
   ```

5. **Start Services Gradually**
   ```bash
   # Start VPN first
   docker-compose -f docker-compose.arr-stack.yml up -d gluetun

   # Wait for VPN to be healthy, then start download clients
   docker-compose -f docker-compose.arr-stack.yml up -d qbittorrent sabnzbd flaresolverr

   # Then start Arr stack
   docker-compose -f docker-compose.arr-stack.yml up -d prowlarr radarr sonarr bazarr

   # Finally media server and supporting services
   docker-compose -f docker-compose.arr-stack.yml up -d emby jellyseerr recyclarr watchtower
   ```

### Monitoring Health

Check service health status:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

View service logs:
```bash
docker logs -f <container_name>
```

Check resource usage:
```bash
docker stats
```

---

## Environment Variables

No new environment variables were added. All improvements use existing variables from `.env.sample`:
- TZ
- PUID/PGID
- DOCKERCONFDIR
- DOCKERSTORAGEDIR
- DOCKERLOGGING_MAXFILE
- DOCKERLOGGING_MAXSIZE
- Service-specific variables (VPN, database credentials, etc.)

---

## Compatibility Notes

1. **Docker Compose Version**
   - Requires Docker Compose v1.27.0+ for v3.8 support
   - All features compatible with Synology DSM 7.x

2. **Synology DSM**
   - Labels follow Synology conventions
   - Resource limits work with DSM's Docker implementation
   - Healthchecks supported in DSM 7.x

3. **Backward Compatibility**
   - Environment variables unchanged - no .env modifications needed
   - Volume paths unchanged - existing data safe
   - Port mappings unchanged - no networking changes required

---

## Troubleshooting

### Services Won't Start
- Check `docker logs <container>` for errors
- Verify healthchecks aren't too aggressive
- Ensure sufficient system resources available

### Healthcheck Failures
- Increase `start_period` if service needs more init time
- Check healthcheck command syntax
- Verify service actually provides the expected endpoint

### Resource Constraints
- Adjust limits in templates based on your hardware
- Monitor with `docker stats`
- Consider running fewer services simultaneously

### Dependency Issues
- Verify dependent services are healthy: `docker ps`
- Check that networks are created correctly
- Review service startup order

---

## Future Improvements

Potential enhancements for consideration:

1. **Secrets Management**
   - Integrate Docker secrets for sensitive values
   - Use Vault for dynamic secrets

2. **Monitoring**
   - Add Prometheus exporters
   - Implement Grafana dashboards

3. **Backup Automation**
   - Automated backup containers
   - Volume snapshot integration

4. **High Availability**
   - Database replication
   - Load balancing for media servers

---

## References

- [Docker Compose v3 Reference](https://docs.docker.com/compose/compose-file/compose-file-v3/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Synology Docker Documentation](https://www.synology.com/en-global/dsm/packages/Docker)
- [TRaSH Guides](https://trash-guides.info/)

---

**Last Updated:** 2025-11-23
**Author:** Claude AI Assistant
**Version:** 1.0
