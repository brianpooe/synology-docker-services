# Recyclarr Configuration Guide

Recyclarr automatically synchronizes TRaSH Guides quality profiles and custom formats to your Sonarr and Radarr instances.

## Quick Start

### 1. Copy Configuration Template

```bash
# Copy the template to your recyclarr config directory
./substitute_env.sh docker-compose-files/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml

# Edit with your API keys
nano /volume1/docker/appdata/recyclarr/recyclarr.yml
```

### 2. Get API Keys

**Sonarr:**
1. Open Sonarr web interface: `http://your-nas-ip:8989`
2. Go to: Settings → General → Security
3. Copy the **API Key**

**Radarr:**
1. Open Radarr web interface: `http://your-nas-ip:7878`
2. Go to: Settings → General → Security
3. Copy the **API Key**

### 3. Configure Base URLs

**CRITICAL:** Use Docker service names, NOT `localhost`!

```yaml
# ✅ Correct - Uses service name
sonarr:
  web-1080p-v4:
    base_url: http://sonarr:8989
    api_key: your_sonarr_api_key_here

radarr:
  uhd-bluray-web:
    base_url: http://radarr:7878
    api_key: your_radarr_api_key_here
```

```yaml
# ❌ Wrong - localhost doesn't work in Docker
sonarr:
  web-1080p-v4:
    base_url: http://localhost:8989  # Won't work!
```

**Why?** Inside the recyclarr container, `localhost` refers to itself, not the host or other containers.

---

## Configuration Example

### Complete Working Configuration

```yaml
sonarr:
  web-1080p-v4:
    base_url: http://sonarr:8989
    api_key: abc123def456...  # Your actual API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: sonarr-quality-definition-series
      - template: sonarr-v4-quality-profile-web-1080p
      - template: sonarr-v4-custom-formats-web-1080p

  web-2160p-v4:
    base_url: http://sonarr:8989
    api_key: abc123def456...  # Same API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: sonarr-quality-definition-series
      - template: sonarr-v4-quality-profile-web-2160p
      - template: sonarr-v4-custom-formats-web-2160p

radarr:
  uhd-bluray-web:
    base_url: http://radarr:7878
    api_key: xyz789ghi012...  # Your actual API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: radarr-quality-definition-movie
      - template: radarr-quality-profile-uhd-bluray-web
      - template: radarr-custom-formats-uhd-bluray-web

  hd-bluray-web:
    base_url: http://radarr:7878
    api_key: xyz789ghi012...  # Same API key
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      - template: radarr-quality-definition-movie
      - template: radarr-quality-profile-hd-bluray-web
      - template: radarr-custom-formats-hd-bluray-web
```

---

## Testing Configuration

### 1. Validate Config File

```bash
# List configured instances
docker exec recyclarr recyclarr config list
```

**Expected output:**
```
Sonarr Instances:
  - web-1080p-v4
  - web-2160p-v4

Radarr Instances:
  - uhd-bluray-web
  - hd-bluray-web
```

### 2. Preview Sync (Dry Run)

```bash
# Preview changes without applying
docker exec recyclarr recyclarr sync --preview
```

This shows what would change without actually modifying anything.

### 3. Actually Sync

```bash
# Apply changes to Sonarr and Radarr
docker exec recyclarr recyclarr sync
```

### 4. Check Logs

```bash
# View recyclarr logs
docker logs recyclarr

# Follow logs in real-time
docker logs -f recyclarr
```

---

## Automatic Sync Schedule

Recyclarr runs on a cron schedule defined in the container. By default, it syncs daily.

To modify the schedule, you would need to customize the container configuration (advanced).

For manual syncs:
```bash
docker exec recyclarr recyclarr sync
```

---

## Common Issues

### Issue: "base_url must start with 'http' or 'https'"

**Cause:** The `base_url` is empty or malformed.

**Fix:**
```yaml
# Wrong
base_url: localhost:8989
base_url:  # Empty

# Correct
base_url: http://sonarr:8989
```

### Issue: "Connection refused" or "Cannot connect"

**Possible causes:**
1. Service names are wrong
2. Containers not on same network
3. Sonarr/Radarr not running

**Fix:**
```bash
# Check containers are running
docker ps | grep -E "sonarr|radarr|recyclarr"

# Check network connectivity
docker exec recyclarr ping sonarr
docker exec recyclarr ping radarr

# Check Sonarr is responding
docker exec recyclarr wget -qO- http://sonarr:8989/ping
```

### Issue: "Unauthorized" or "Invalid API key"

**Cause:** Wrong API key or permissions issue.

**Fix:**
1. Get correct API key from Sonarr/Radarr (Settings → General → Security)
2. Copy-paste carefully (no extra spaces)
3. Ensure API key has full permissions

### Issue: Config file not found

**Cause:** File not in correct location.

**Fix:**
```bash
# Check file exists
docker exec recyclarr ls -la /config

# Expected location inside container
/config/recyclarr.yml
```

On host, this maps to:
```
{{DOCKERCONFDIR}}/recyclarr/recyclarr.yml
```

---

## Quality Profiles

### What Recyclarr Syncs

**For Sonarr:**
- Quality definitions (file size limits)
- Quality profiles (which qualities to allow)
- Custom formats (preferences for releases)
- Custom format scores (prioritization)

**For Radarr:**
- Quality definitions
- Quality profiles
- Custom formats
- Custom format scores

### Available TRaSH Templates

**Sonarr:**
- `sonarr-quality-definition-series` - File size limits
- `sonarr-v4-quality-profile-web-1080p` - 1080p WEB profile
- `sonarr-v4-quality-profile-web-2160p` - 4K WEB profile
- `sonarr-v4-custom-formats-web-1080p` - 1080p custom formats
- `sonarr-v4-custom-formats-web-2160p` - 4K custom formats

**Radarr:**
- `radarr-quality-definition-movie` - File size limits
- `radarr-quality-profile-hd-bluray-web` - HD Bluray/WEB
- `radarr-quality-profile-uhd-bluray-web` - 4K Bluray/WEB
- `radarr-custom-formats-hd-bluray-web` - HD custom formats
- `radarr-custom-formats-uhd-bluray-web` - 4K custom formats

---

## Custom Formats

### Common Custom Formats

Recyclarr applies TRaSH Guide custom formats to improve release selection:

**Quality Improvements:**
- Prefer proper/repack releases
- Avoid bad dual audio groups
- Prefer streaming optimized releases

**HDR/Audio:**
- DV (Dolby Vision) handling
- HDR10+ support
- Audio codec preferences

**Release Groups:**
- Prefer scene/p2p groups
- Avoid obfuscated releases
- Filter low-quality encodes

### Customizing Scores

In your config, you can adjust scores:

```yaml
custom_formats:
  - trash_ids:
      - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
    assign_scores_to:
      - name: UHD Bluray + WEB
        score: 100  # Higher score = higher priority
```

---

## Maintenance

### Manual Sync

```bash
# Sync all instances
docker exec recyclarr recyclarr sync

# Sync specific instance
docker exec recyclarr recyclarr sync sonarr web-1080p-v4
```

### Update Recyclarr

Apply Recyclarr image updates manually after review.

Manual update:
```bash
docker-compose -f docker-compose.arr-stack.yml pull recyclarr
docker-compose -f docker-compose.arr-stack.yml up -d recyclarr
```

### View Current Settings

Check what's currently configured in Sonarr/Radarr:
- Settings → Profiles → Quality Profiles
- Settings → Profiles → Custom Formats

---

## Best Practices

1. **Start with Templates**
   - Use TRaSH templates as baseline
   - Customize only if needed

2. **Test with Preview**
   - Always preview before syncing
   - Review changes carefully

3. **Backup Before Syncing**
   - Backup Sonarr/Radarr databases
   - Easy rollback if needed

4. **Monitor First Sync**
   - Watch logs during initial sync
   - Verify profiles in UI after sync

5. **Keep It Simple**
   - Don't over-customize initially
   - TRaSH defaults work well for most

---

## Advanced Configuration

### Multiple Instances

You can configure multiple Sonarr/Radarr instances:

```yaml
sonarr:
  instance-1:
    base_url: http://sonarr:8989
    api_key: key1

  instance-2:
    base_url: http://sonarr-4k:8989
    api_key: key2
```

### Instance-Specific Templates

Different quality settings per instance:

```yaml
sonarr:
  web-1080p:
    include:
      - template: sonarr-v4-quality-profile-web-1080p

  web-2160p:
    include:
      - template: sonarr-v4-quality-profile-web-2160p
```

---

## Resources

- **TRaSH Guides:** https://trash-guides.info/
- **Recyclarr Wiki:** https://recyclarr.dev/
- **Recyclarr GitHub:** https://github.com/recyclarr/recyclarr
- **TRaSH Discord:** https://trash-guides.info/discord

---

## Troubleshooting Checklist

- [ ] Config file exists at correct location
- [ ] Base URLs use service names (not localhost)
- [ ] API keys are correct and complete
- [ ] Sonarr/Radarr are running and healthy
- [ ] Containers are on same Docker network
- [ ] No typos in configuration
- [ ] YAML syntax is valid (proper indentation)

---

**Last Updated:** 2026-02-14
