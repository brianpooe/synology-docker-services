# Docker Socket Proxy Security Guide

## Why Use Socket-Proxy?

The Docker socket (`/var/run/docker.sock`) provides **full control** over Docker. Any container with access to it can:
- Start/stop ANY container
- Execute commands in ANY container (`docker exec`)
- Access volumes and secrets
- Create privileged containers
- Potentially escape to the host system

**Socket-proxy** acts as a **security gateway**, providing:
- ✅ **Least Privilege Access** - Only expose needed API endpoints
- ✅ **Read-only Socket** - Proxy has read-only access to docker.sock
- ✅ **Granular Permissions** - Enable/disable specific API functions
- ✅ **Network Isolation** - Services connect via TCP, not direct socket
- ✅ **Audit Trail** - Log all Docker API calls
- ✅ **Defense in Depth** - Even if compromised, limited damage

---

## Security Comparison

### Direct Socket Access (Current Default)
```yaml
watchtower:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

**Risk Level:** 🔴 **HIGH**
- Full Docker API access
- Can execute commands in containers
- Can access any volume/secret
- Can create privileged containers

### With Socket-Proxy (Recommended)
```yaml
socket-proxy:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only!
  environment:
    CONTAINERS: 1  # Only what Watchtower needs
    IMAGES: 1
    EXEC: 0        # Explicitly denied
    SECRETS: 0     # Explicitly denied

watchtower:
  environment:
    DOCKER_HOST: tcp://socket-proxy:2375  # Restricted API
```

**Risk Level:** 🟡 **MEDIUM**
- Limited API endpoints only
- No exec access
- No secrets access
- Defined blast radius

---

## What Watchtower Actually Needs

### Required Permissions
```bash
CONTAINERS=1  # Start, stop, create, remove containers
IMAGES=1      # Pull new images, remove old images
EVENTS=1      # Monitor container events (default enabled)
INFO=1        # Docker system info (default enabled)
VERSION=1     # Docker version (default enabled)
PING=1        # Health checks (default enabled)
```

### Explicitly Denied (Security Critical)
```bash
EXEC=0         # Cannot execute commands in containers
SECRETS=0      # Cannot access Docker secrets
VOLUMES=0      # Cannot manage volumes (uses existing)
NETWORKS=0     # Cannot manage networks (uses existing)
BUILD=0        # Cannot build images
COMMIT=0       # Cannot commit containers
POST=0         # Cannot unrestricted POST
SYSTEM=0       # Cannot system-wide operations
```

---

## Implementation Guide

### Step 1: Deploy Socket-Proxy

```bash
# Generate the compose file
./substitute_env.sh docker-compose-files/socket-proxy_template.yaml docker-compose.socket-proxy.yml

# Start socket-proxy
docker-compose -f docker-compose.socket-proxy.yml up -d

# Verify it's running
docker logs socket-proxy
docker exec socket-proxy wget -qO- http://localhost:2375/version
```

### Step 2: Update Watchtower Configuration

Edit your generated `docker-compose.arr-stack.yml`:

**Before:**
```yaml
watchtower:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  networks:
    - vpn-network
```

**After:**
```yaml
watchtower:
  environment:
    DOCKER_HOST: tcp://socket-proxy:2375  # Use proxy instead
  networks:
    - vpn-network
    - socket-proxy  # Add socket-proxy network
  depends_on:
    socket-proxy:
      condition: service_healthy
  # Remove volumes section

networks:
  socket-proxy:
    external: true
    name: socket_proxy
```

### Step 3: Test Watchtower

```bash
# Recreate Watchtower with new config
docker-compose -f docker-compose.arr-stack.yml up -d watchtower

# Check Watchtower logs - should connect successfully
docker logs watchtower

# Verify it can check for updates
docker exec watchtower watchtower --run-once --debug
```

### Step 4: Verify Security

```bash
# This should work (Watchtower can list containers)
docker exec watchtower wget -qO- http://socket-proxy:2375/containers/json

# This should fail with 403 Forbidden (exec is disabled)
docker exec watchtower wget -qO- http://socket-proxy:2375/containers/watchtower/exec

# This should fail with 403 Forbidden (secrets are disabled)
docker exec watchtower wget -qO- http://socket-proxy:2375/secrets
```

---

## Configuration Options

### Minimal Security (Watchtower Only)
```yaml
socket-proxy:
  environment:
    CONTAINERS: 1
    IMAGES: 1
    # All other endpoints default to 0
```

### Multiple Services (Watchtower + Monitoring)
```yaml
socket-proxy:
  environment:
    # Watchtower
    CONTAINERS: 1
    IMAGES: 1

    # Monitoring tools (Prometheus, etc.)
    NETWORKS: 1
    VOLUMES: 1

    # Still deny dangerous operations
    EXEC: 0
    SECRETS: 0
    BUILD: 0
```

### Paranoid Mode (Monitor Only)
```yaml
socket-proxy:
  environment:
    # Read-only access for monitoring
    CONTAINERS: 1  # Read only (no write without POST)
    POST: 0        # No write operations
    EXEC: 0
    SECRETS: 0
```

---

## Docker Compose Integration Patterns

### Pattern 1: Separate Stack (Recommended)
**Best for:** Production environments, multiple services need socket access

```bash
# Stack 1: Security infrastructure
docker-compose.socket-proxy.yml
  - socket-proxy

# Stack 2: Media services
docker-compose.arr-stack.yml
  - watchtower (uses external socket-proxy network)
  - radarr, sonarr, etc.
```

**Benefits:**
- Socket-proxy isolated from app services
- Can be updated independently
- Multiple stacks can share one proxy

### Pattern 2: Combined Stack
**Best for:** Simplicity, single-use deployments

Add socket-proxy directly to arr-stack_template.yaml:

```yaml
services:
  socket-proxy:
    # ... socket-proxy config ...

  watchtower:
    environment:
      DOCKER_HOST: tcp://socket-proxy:2375
    depends_on:
      socket-proxy:
        condition: service_healthy
```

**Benefits:**
- Single compose file
- Easier to manage
- Good for dev/test environments

---

## Troubleshooting

### Issue: Watchtower can't connect to socket-proxy

**Symptoms:**
```
Error response from daemon: Get "http://socket-proxy:2375/version": dial tcp: lookup socket-proxy
```

**Solutions:**
1. Verify socket-proxy is running:
   ```bash
   docker ps | grep socket-proxy
   ```

2. Check Watchtower is on socket-proxy network:
   ```bash
   docker inspect watchtower | grep -A 10 Networks
   ```

3. Test connectivity:
   ```bash
   docker exec watchtower ping socket-proxy
   docker exec watchtower wget -qO- http://socket-proxy:2375/version
   ```

### Issue: Permission denied errors

**Symptoms:**
```
HTTP 403: Forbidden
```

**Solutions:**
1. Check which endpoint is failing in logs
2. Enable the required permission in socket-proxy:
   ```yaml
   environment:
     CONTAINERS: 1  # If containers endpoint fails
     IMAGES: 1      # If images endpoint fails
   ```
3. Restart socket-proxy:
   ```bash
   docker-compose -f docker-compose.socket-proxy.yml restart
   ```

### Issue: Socket-proxy not starting

**Symptoms:**
```
Cannot connect to Docker socket
```

**Solutions:**
1. Verify docker.sock permissions:
   ```bash
   ls -la /var/run/docker.sock
   # Should be: srw-rw---- 1 root docker
   ```

2. On Synology, ensure Docker group exists:
   ```bash
   # If needed, add user to docker group
   sudo synogroup --add docker <username>
   ```

3. Check socket-proxy logs:
   ```bash
   docker logs socket-proxy
   ```

---

## Performance Impact

### Benchmarks

**Direct Socket Access:**
- Latency: ~1ms
- Throughput: Maximum

**Via Socket-Proxy:**
- Latency: ~2-3ms (negligible for Watchtower)
- Throughput: Slight overhead
- CPU: +0.1-0.2% (socket-proxy itself)
- Memory: +50-60MB (socket-proxy container)

**Impact on Watchtower:**
- Update checks: No noticeable difference
- Container updates: <100ms additional latency
- Totally acceptable for scheduled updates

---

## Alternative: Other Tools That Benefit from Socket-Proxy

### Traefik (Reverse Proxy)
```yaml
socket-proxy:
  environment:
    CONTAINERS: 1  # Monitor container labels
    POST: 0        # Read-only

traefik:
  environment:
    DOCKER_HOST: tcp://socket-proxy:2375
```

### Diun (Docker Image Update Notifier)
```yaml
socket-proxy:
  environment:
    CONTAINERS: 1
    IMAGES: 1
    POST: 0  # Read-only, no updates

diun:
  environment:
    DIUN_PROVIDERS_DOCKER_ENDPOINT: tcp://socket-proxy:2375
```

### Portainer (Docker UI)
```yaml
socket-proxy:
  environment:
    CONTAINERS: 1
    IMAGES: 1
    NETWORKS: 1
    VOLUMES: 1
    # Be careful - Portainer needs more access
    EXEC: 1   # For console access (optional)

portainer:
  environment:
    DOCKER_HOST: tcp://socket-proxy:2375
```

---

## Security Best Practices

### 1. Never Expose Socket-Proxy to Internet
```yaml
ports:
  - "127.0.0.1:2375:2375"  # ✅ Localhost only
  # NOT:
  - "2375:2375"  # ❌ Accessible from network
```

### 2. Use Internal Network
```yaml
networks:
  socket-proxy:
    internal: true  # ✅ Not routable outside Docker
```

### 3. Regular Audits
```bash
# Check what containers have socket-proxy access
docker network inspect socket_proxy

# Review enabled endpoints
docker exec socket-proxy env | grep -E "CONTAINERS|IMAGES|EXEC|SECRETS"
```

### 4. Monitor Logs
```bash
# Watch for suspicious API calls
docker logs -f socket-proxy | grep -E "POST|DELETE"
```

### 5. Keep Socket-Proxy Updated
```yaml
socket-proxy:
  labels:
    - "com.centurylinklabs.watchtower.enable=false"  # Manual updates only
```

Update manually after reviewing changelog:
```bash
docker pull lscr.io/linuxserver/socket-proxy:latest
docker-compose -f docker-compose.socket-proxy.yml up -d
```

---

## Comparison with Alternatives

### Socket-Proxy vs. Direct Socket
| Feature | Direct Socket | Socket-Proxy |
|---------|--------------|--------------|
| Security | Low | Medium-High |
| Setup Complexity | Simple | Moderate |
| Performance | Fastest | Minimal overhead |
| Audit Trail | No | Yes (with logging) |
| Granular Control | No | Yes |

### Socket-Proxy vs. Docker-in-Docker (DinD)
| Feature | DinD | Socket-Proxy |
|---------|------|--------------|
| Isolation | Complete | API-level |
| Security | High | Medium-High |
| Complexity | High | Moderate |
| Performance | Heavy overhead | Minimal overhead |
| Use Case | CI/CD builds | API access control |

### Socket-Proxy vs. Rootless Docker
| Feature | Rootless | Socket-Proxy |
|---------|----------|--------------|
| Security | Highest | Medium-High |
| Complexity | Very High | Moderate |
| Compatibility | Limited | Excellent |
| Synology Support | No | Yes |

**Verdict:** Socket-proxy is the best balance of security and usability for Synology NAS.

---

## Migration Checklist

- [ ] Deploy socket-proxy compose file
- [ ] Verify socket-proxy is healthy
- [ ] Update Watchtower configuration
- [ ] Test Watchtower connectivity
- [ ] Verify Watchtower can check for updates
- [ ] Remove docker.sock volume from Watchtower
- [ ] Test end-to-end update workflow
- [ ] Monitor logs for errors
- [ ] Document configuration for team
- [ ] Set up log monitoring/alerts

---

## Conclusion

**Recommendation:** Implement socket-proxy for production environments.

**Benefits:**
- Significantly reduced attack surface
- Minimal performance impact
- Easy to implement and maintain
- Industry best practice

**When to Skip:**
- Development/test environments where security is less critical
- Very resource-constrained systems
- Temporary deployments

**When to Definitely Use:**
- Production Synology NAS
- Systems with sensitive data
- Internet-exposed services
- Compliance requirements

---

**Last Updated:** 2025-11-23
**Compatibility:** Synology DSM 7.x, Docker Compose 1.27.0+
