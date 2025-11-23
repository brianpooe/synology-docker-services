# Synology Docker Services

Production-ready Docker Compose templates for Synology NAS, featuring security best practices, resource management, and comprehensive health monitoring.

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/brianpooe/synology-docker-services.git
cd synology-docker-services

# 2. Copy and configure environment
cp .env.sample .env
nano .env  # Fill in your configuration

# 3. Generate Docker Compose files
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
./substitute_env.sh docker-compose-files/postgres_template.yaml docker-compose.postgres.yml
./substitute_env.sh docker-compose-files/vault_template.yaml docker-compose.vault.yml

# 4. Deploy
docker-compose -f docker-compose.arr-stack.yml up -d
docker-compose -f docker-compose.postgres.yml up -d
docker-compose -f docker-compose.vault.yml up -d
```

---

## 📦 Available Stacks

### 🎬 Media Stack (`arr-stack_template.yaml`)
Complete automated media management with VPN protection and socket-proxy security.

**Services:**
- **Socket-Proxy** - Secure Docker API gateway ✅ *NEW*
- **Gluetun** - VPN container (WireGuard/OpenVPN)
- **qBittorrent** - Torrent client (through VPN)
- **SABnzbd** - Usenet client (through VPN)
- **Prowlarr** - Indexer manager
- **Radarr** - Movie collection manager
- **Sonarr** - TV series collection manager
- **Bazarr** - Subtitle manager
- **Emby** - Media server
- **Jellyseerr** - Request management
- **FlareSolverr** - Captcha solver
- **Recyclarr** - Quality profile sync (TRaSH Guides)
- **Watchtower** - Automatic container updates (via socket-proxy)

**Features:**
- ✅ VPN kill-switch for download clients
- ✅ Socket-proxy for secure Docker API access
- ✅ Health checks and dependency management
- ✅ Resource limits to prevent system exhaustion
- ✅ Security hardening (no-new-privileges, internal networks)

### 🗄️ Database Stack (`postgres_template.yaml`)
PostgreSQL with pgAdmin web interface.

**Services:**
- **PostgreSQL 17** - Alpine-based database
- **pgAdmin 4** - Web-based administration

**Features:**
- ✅ Health-aware dependency management
- ✅ Automated backups ready
- ✅ Resource limits configured
- ✅ Persistent data volumes

### 🔐 Secrets Stack (`vault_template.yaml`)
HashiCorp Vault for secrets management.

**Services:**
- **Vault 1.19.2** - Secrets management

**Features:**
- ✅ Production-ready configuration
- ✅ Watchtower disabled for stability
- ✅ IPC_LOCK capability for security
- ✅ Health monitoring

---

## 🔒 Security Features

### Socket-Proxy Integration
All media stack services use socket-proxy for restricted Docker API access:

| Feature | Traditional | With Socket-Proxy |
|---------|------------|-------------------|
| Docker Socket Access | Full R/W | Restricted API endpoints |
| Exec in Containers | ✅ Possible | ❌ Blocked |
| Access Secrets | ✅ Possible | ❌ Blocked |
| Manage Volumes | ✅ Possible | ❌ Blocked |
| Attack Surface | 100% | ~10% |

**See:** [docs/SOCKET_PROXY.md](docs/SOCKET_PROXY.md) for details

### Additional Security
- **No-new-privileges** on all containers
- **Read-only filesystems** where applicable
- **Internal networks** for service isolation
- **Resource limits** to prevent DoS
- **Health checks** for reliability
- **Watchtower scoping** to limit auto-update scope

---

## 📋 Prerequisites

### Required
- Synology NAS with DSM 7.x
- Docker & Docker Compose installed via Package Center
- SSH access enabled
- Basic knowledge of Docker and command line

### Recommended
- Static IP for your NAS
- Domain name for reverse proxy (optional)
- VPN subscription for Gluetun (AirVPN, Mullvad, etc.)

---

## ⚙️ Configuration

### 1. Environment Variables

Edit `.env` file with your settings:

```bash
# System Settings
DOCKERCONFDIR=/volume1/docker/appdata
DOCKERSTORAGEDIR=/volume1/data
PUID=1026
PGID=100
TZ=Africa/Johannesburg

# Docker Logging
DOCKERLOGGING_MAXFILE=3
DOCKERLOGGING_MAXSIZE=10m

# Watchtower (optional)
WATCHTOWER_SCHEDULE=0 0 4 * * *
WATCHTOWER_NOTIFICATION_URL=
WATCHTOWER_SCOPE=
WATCHTOWER_LABEL_ENABLE=

# VPN Configuration
VPN_SERVICE_PROVIDER=airvpn
WIREGUARD_PRIVATE_KEY=your_private_key
WIREGUARD_PRESHARED_KEY=your_preshared_key
WIREGUARD_ADDRESSES=10.x.x.x/32
FIREWALL_VPN_INPUT_PORTS=12345
SERVER_COUNTRIES=Netherlands

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=strong_password
POSTGRES_DB=maindb
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=strong_password
```

**Get your PUID/PGID:**
```bash
ssh admin@synology-nas
id $USER
```

### 2. Recyclarr Configuration

Copy and configure Recyclarr for quality profile management:

```bash
# Copy template
cp RECYCLARR_CONFIG_TEMPLATE.yml /volume1/docker/appdata/recyclarr/recyclarr.yml

# Edit with your API keys
nano /volume1/docker/appdata/recyclarr/recyclarr.yml
```

**Get API Keys:**
- **Sonarr:** Settings → General → Security → API Key
- **Radarr:** Settings → General → Security → API Key

**Important:** Use service names (`http://sonarr:8989`), NOT `localhost`!

### 3. Directory Structure

Create required directories:

```bash
# Config directories
sudo mkdir -p /volume1/docker/appdata/{gluetun,qbittorrent,sabnzbd,prowlarr,radarr,sonarr,bazarr,emby,jellyseerr,recyclarr,postgres,pgadmin,vault}

# Storage directories
sudo mkdir -p /volume1/data/{torrents,usenet,media}/{movies,tv,music}
sudo mkdir -p /volume1/docker/appdata/postgres/{data,backups}

# Set permissions
sudo chown -R $PUID:$PGID /volume1/docker/appdata
sudo chown -R $PUID:$PGID /volume1/data

# Special: pgAdmin needs specific user
sudo chown -R 5050:5050 /volume1/docker/appdata/pgadmin
```

---

## 🚀 Deployment

### Option 1: Deploy All Stacks
```bash
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
./substitute_env.sh docker-compose-files/postgres_template.yaml docker-compose.postgres.yml
./substitute_env.sh docker-compose-files/vault_template.yaml docker-compose.vault.yml

docker-compose -f docker-compose.arr-stack.yml up -d
docker-compose -f docker-compose.postgres.yml up -d
docker-compose -f docker-compose.vault.yml up -d
```

### Option 2: Deploy Specific Stack
```bash
# Media stack only
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml up -d

# Verify deployment
docker ps
docker logs -f watchtower
```

### Option 3: Deploy Individual Services
```bash
# Start only specific services
docker-compose -f docker-compose.arr-stack.yml up -d socket-proxy gluetun qbittorrent prowlarr radarr sonarr
```

---

## 🔍 Verification

### Check Service Health
```bash
# View all containers
docker ps

# Check specific service logs
docker logs socket-proxy
docker logs watchtower
docker logs gluetun

# Check health status
docker inspect socket-proxy | grep -A 10 Health
```

### Test Socket-Proxy Security
```bash
# Should work - Watchtower can list containers
docker exec watchtower wget -qO- http://socket-proxy:2375/containers/json

# Should fail with 403 - exec is blocked
docker exec watchtower wget -qO- http://socket-proxy:2375/containers/watchtower/exec
```

### Test VPN Connection
```bash
# Check VPN is connected
docker logs gluetun | grep "connected"

# Test qBittorrent is using VPN
docker exec qbittorrent curl ifconfig.me
# Should show VPN IP, not your real IP
```

---

## 📊 Resource Allocation

Total resources if all services running:

| Resource | Reserved | Limit | Notes |
|----------|----------|-------|-------|
| CPU | 4.6 cores | 19.5 cores | Adjust based on your NAS |
| Memory | 4.44 GB | 18.75 GB | Minimum 8GB RAM recommended |

**Per-service limits configured to prevent resource exhaustion**

---

## 🔧 Common Tasks

### Update Containers
```bash
# Automatic (via Watchtower)
# Watchtower runs on schedule defined in WATCHTOWER_SCHEDULE

# Manual update
docker-compose -f docker-compose.arr-stack.yml pull
docker-compose -f docker-compose.arr-stack.yml up -d
```

### View Logs
```bash
# Follow logs
docker logs -f radarr

# Last 100 lines
docker logs --tail 100 sonarr

# All services
docker-compose -f docker-compose.arr-stack.yml logs -f
```

### Restart Service
```bash
# Single service
docker-compose -f docker-compose.arr-stack.yml restart radarr

# All services
docker-compose -f docker-compose.arr-stack.yml restart
```

### Stop/Start Stack
```bash
# Stop everything
docker-compose -f docker-compose.arr-stack.yml down

# Start everything
docker-compose -f docker-compose.arr-stack.yml up -d

# Stop but keep data
docker-compose -f docker-compose.arr-stack.yml stop
```

---

## 📚 Documentation

### Detailed Guides
- **[Socket-Proxy Security](docs/SOCKET_PROXY.md)** - Docker API security implementation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Improvements Guide](docs/IMPROVEMENTS.md)** - What changed and why
- **[Recyclarr Setup](docs/RECYCLARR.md)** - Quality profile configuration

### External Resources
- **[TRaSH Guides](https://trash-guides.info/)** - File structure and quality profiles
- **[Servarr Wiki](https://wiki.servarr.com/)** - Arr stack documentation
- **[Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)** - VPN configuration

---

## 🛠️ Troubleshooting

### Quick Diagnostics
```bash
# Check container status
docker ps -a

# Check resource usage
docker stats

# Check networks
docker network ls
docker network inspect vpn_network

# Validate compose file
docker-compose -f docker-compose.arr-stack.yml config
```

### Common Issues

#### Recyclarr: "base_url must start with http"
**Fix:** Use service names in recyclarr.yml:
```yaml
base_url: http://sonarr:8989  # ✅ Correct
base_url: http://localhost:8989  # ❌ Wrong
```

#### Watchtower: Cannot update containers
**Fix:** Check socket-proxy is running:
```bash
docker logs socket-proxy
docker logs watchtower
```

#### qBittorrent: No connection
**Fix:** Check Gluetun VPN is connected:
```bash
docker logs gluetun | grep -i "connected"
```

**Full troubleshooting guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🔄 Migration from Old Setup

If upgrading from previous configurations:

1. **Backup everything:**
   ```bash
   docker-compose down
   tar -czf docker-backup-$(date +%Y%m%d).tar.gz /volume1/docker/appdata
   ```

2. **Regenerate compose files:**
   ```bash
   ./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
   ```

3. **Review changes:**
   ```bash
   docker-compose -f docker-compose.arr-stack.yml config
   ```

4. **Deploy:**
   ```bash
   docker-compose -f docker-compose.arr-stack.yml up -d
   ```

**Migration guide:** [docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md)

---

## 🎯 Best Practices

### Security
- ✅ Use socket-proxy for Watchtower (enabled by default)
- ✅ Enable Watchtower scoping to limit auto-updates
- ✅ Never expose Watchtower to exclude critical services (Vault, databases)
- ✅ Use strong passwords in `.env`
- ✅ Never commit `.env` to git
- ✅ Regularly update containers

### Performance
- ✅ Adjust resource limits based on your NAS specs
- ✅ Monitor with `docker stats`
- ✅ Use SSD for Docker volumes if possible
- ✅ Enable hardware transcoding in Emby/Jellyfin

### Maintenance
- ✅ Regular backups of `/volume1/docker/appdata`
- ✅ Monitor logs for errors
- ✅ Test updates in staging before production
- ✅ Document any custom configurations

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

---

## 📝 License

This project is provided as-is for personal and educational use.

---

## 🙏 Credits

- **[TRaSH Guides](https://trash-guides.info/)** - Quality profiles and best practices
- **[Hotio](https://hotio.dev/)** - Excellent container images
- **[LinuxServer.io](https://www.linuxserver.io/)** - Container images and documentation
- **[Gluetun](https://github.com/qdm12/gluetun)** - VPN container

---

## 📧 Support

- **Issues:** [GitHub Issues](https://github.com/brianpooe/synology-docker-services/issues)
- **Discussions:** [GitHub Discussions](https://github.com/brianpooe/synology-docker-services/discussions)

---

**Last Updated:** 2025-11-23
**Version:** 2.0
**Compatibility:** Synology DSM 7.x, Docker Compose 1.27.0+
