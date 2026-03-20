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
./substitute_env.sh docker-compose-files/beszel-agent_template.yaml docker-compose.beszel-agent.yml
./substitute_env.sh caddy/Caddyfile_template caddy/Caddyfile .env

# 4. Deploy
docker-compose -f docker-compose.arr-stack.yml up -d
docker-compose -f docker-compose.postgres.yml up -d
docker-compose -f docker-compose.vault.yml up -d
docker-compose -f docker-compose.beszel-agent.yml up -d
```

---

## 📦 Available Stacks

### 🎬 Media Stack (`arr-stack_template.yaml`)
Complete automated media management with VPN protection and security hardening.

**Services:**
- **Gluetun** - VPN container (WireGuard/OpenVPN)
- **qBittorrent** - Torrent client (through VPN)
- **SABnzbd** - Usenet client (through VPN)
- **Prowlarr** - Indexer manager
- **Radarr** - Movie collection manager
- **Sonarr** - TV series collection manager
- **Bazarr** - Subtitle manager
- **Emby** - Media server
- **Seerr** - Request management
- **FlareSolverr** - Captcha solver
- **Recyclarr** - Quality profile sync (TRaSH Guides)

**Features:**
- ✅ VPN kill-switch for download clients
- ✅ Health checks and dependency management
- ✅ Resource limits to prevent system exhaustion
- ✅ Security hardening (no-new-privileges, internal networks)

### 📈 Monitoring Stack (`beszel-agent_template.yaml`)
Host-level telemetry agent for Beszel Hub.

**Services:**
- **Beszel Agent** - Host metrics and Docker telemetry collector

**Features:**
- ✅ Official Beszel agent container setup
- ✅ Host networking for interface metrics visibility
- ✅ Docker socket read-only mount
- ✅ Persistent state volume and constrained memory limit

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
- ✅ Pinned Vault version for predictable upgrades
- ✅ IPC_LOCK capability for security
- ✅ Health monitoring

---

## 🔒 Security Features

### Additional Security
- **No-new-privileges** on all containers
- **Read-only filesystems** where applicable
- **Internal networks** for service isolation
- **Resource limits** to prevent DoS
- **Health checks** for reliability

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

# VPN Configuration
VPN_SERVICE_PROVIDER=airvpn
WIREGUARD_PRIVATE_KEY=your_private_key
WIREGUARD_PRESHARED_KEY=your_preshared_key
WIREGUARD_ADDRESSES=10.x.x.x/32
FIREWALL_VPN_INPUT_PORTS=12345
SERVER_COUNTRIES=Netherlands

# Beszel Agent
BESZEL_AGENT_KEY=<public_key_from_hub>
BESZEL_AGENT_TOKEN=<token_from_hub>
BESZEL_AGENT_HUB_URL=https://beszel.example.com
BESZEL_AGENT_LISTEN=45876
BESZEL_AGENT_IMAGE_TAG=latest
BESZEL_AGENT_MEM_LIMIT=128m

# Caddy reverse proxy template
CADDY_TLS_EMAIL=admin@example.com
CADDY_BASE_DOMAIN=home.example.com
CADDY_LAN_PREFIX=10.1.0
CADDY_DNS_PREFIX=10.60.0
CADDY_OFFICE_PREFIX=10.10.0

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

**Beszel agent required values:**
- `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN`, and `BESZEL_AGENT_HUB_URL` come from Beszel Hub when adding a system.
- Keep `BESZEL_AGENT_LISTEN=45876` unless you intentionally changed the agent listen port in Beszel.

### 2. Recyclarr Configuration

Copy and configure Recyclarr for quality profile management:

```bash
# Generate config from template
./substitute_env.sh docker-compose-files/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml

# Edit with your API keys
nano /volume1/docker/appdata/recyclarr/recyclarr.yml
```

**Get API Keys:**
- **Sonarr:** Settings → General → Security → API Key
- **Radarr:** Settings → General → Security → API Key

**Important:** Use service names (`http://sonarr:8989`), NOT `localhost`!
This repository's template uses Recyclarr v8 guide-backed profiles and is pinned to `ghcr.io/recyclarr/recyclarr:8.4.0`.

### 3. Directory Structure

Create required directories:

```bash
# Config directories
sudo mkdir -p /volume1/docker/appdata/{gluetun,qbittorrent,sabnzbd,prowlarr,radarr,sonarr,bazarr,emby,seerr,recyclarr,postgres,pgadmin,vault,beszel-agent}

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
./substitute_env.sh docker-compose-files/beszel-agent_template.yaml docker-compose.beszel-agent.yml
./substitute_env.sh caddy/Caddyfile_template caddy/Caddyfile .env

docker-compose -f docker-compose.arr-stack.yml up -d
docker-compose -f docker-compose.postgres.yml up -d
docker-compose -f docker-compose.vault.yml up -d
docker-compose -f docker-compose.beszel-agent.yml up -d
```

### Option 2: Deploy Specific Stack
```bash
# Media stack only
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml up -d

# Verify deployment
docker ps
docker logs -f gluetun
```

### Option 3: Deploy Individual Services
```bash
# Start only specific services
docker-compose -f docker-compose.arr-stack.yml up -d gluetun qbittorrent prowlarr radarr sonarr
```

---

## 🔍 Verification

### Check Service Health
```bash
# View all containers
docker ps

# Check specific service logs
docker logs gluetun

# Check health status
docker inspect gluetun | grep -A 10 Health
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
| Memory | 4.00 GB | 15.00 GB | CPU limits are intentionally omitted for DSM compatibility |

**Per-service limits configured to prevent resource exhaustion**

---

## 🔧 Common Tasks

### Update Containers
```bash
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
- **[Recyclarr Setup](docs/RECYCLARR.md)** - Quality profile configuration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Improvements Guide](docs/IMPROVEMENTS.md)** - What changed and why

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

#### Recyclarr: "Unable to find include template with name ..."
**Cause:** Old pre-v8 `recyclarr.yml` still using `include: - template:`.
**Fix:** Regenerate from `docker-compose-files/recyclarr_template.yml` and recreate Recyclarr. See [docs/RECYCLARR.md](docs/RECYCLARR.md).

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

**Last Updated:** 2026-02-14
**Version:** 2.1
**Compatibility:** Synology DSM 7.x, Docker Compose 1.27.0+
