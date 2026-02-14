# Diun Configuration Guide

Diun (Docker Image Update Notifier) monitors your Docker containers for available image updates and sends notifications. Unlike Watchtower, **Diun does NOT auto-update** - it only notifies you, giving you full control.

## Table of Contents
- [Why Diun Over Watchtower](#why-diun-over-watchtower)
- [Basic Configuration](#basic-configuration)
- [Discord Notifications](#discord-notifications)
- [Other Notification Services](#other-notification-services)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

## Why Diun Over Watchtower

| Feature | Diun | Watchtower |
|---------|------|------------|
| **Updates containers** | ❌ No (notify only) | ✅ Yes (auto-updates) |
| **Safety** | ✅ You control when to update | ⚠️ Auto-updates can break things |
| **Discord webhooks** | ✅ Direct URL (simple) | ❌ Requires Shoutrrr conversion |
| **Notification options** | ✅ Many providers | ✅ Many providers |
| **Resource usage** | ✅ Lightweight | ✅ Lightweight |
| **Best for** | Production environments | Home labs |

**Recommendation:** Diun is safer for production. You get notified, review changes, then manually update.

## Basic Configuration

### Schedule
Set check schedule in `.env` using cron format:

```bash
# Every 6 hours
DIUN_WATCH_SCHEDULE=0 */6 * * *

# Daily at 4 AM
DIUN_WATCH_SCHEDULE=0 0 4 * * *

# Every Sunday at 3 AM
DIUN_WATCH_SCHEDULE=0 0 3 * * SUN
```

Cron format: `minute hour day-of-month month day-of-week`

### Disable Notifications
Leave the webhook URL empty to run without notifications:

```bash
DIUN_DISCORD_WEBHOOK_URL=
```

Diun will still log updates to console (check with `docker logs diun`).

## Discord Notifications

### Step 1: Create Discord Webhook

1. Open Discord and go to your server
2. Click Server Settings (gear icon)
3. Go to **Integrations** → **Webhooks**
4. Click **New Webhook** or **Create Webhook**
5. Configure:
   - Name: `Diun`
   - Channel: Select where notifications should go
6. Click **Copy Webhook URL**

You'll get a URL like:
```
https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN
```

### Step 2: Add to .env File

**NO CONVERSION NEEDED!** Just paste the Discord URL directly:

```bash
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN
```

**That's it!** Unlike Watchtower, Diun uses Discord URLs directly.

### Step 3: Update Configuration

Edit your `.env` file:

```bash
DIUN_WATCH_SCHEDULE=0 */6 * * *
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_TOKEN
```

### Step 4: Restart Diun

```bash
docker-compose -f docker-compose.arr-stack.yml restart diun
```

Check logs to verify:
```bash
docker logs diun
```

You should see:
```
Diun version X.X.X
Loaded 11 containers to watch
```

### Test Notification

To test immediately without waiting for the schedule:

```bash
docker exec diun diun notif test
```

This sends a test notification to your Discord channel.

## Notification Examples

### What Notifications Look Like

When an update is available, you'll receive a Discord message like:

```
🔔 Image Update Available

Image: ghcr.io/hotio/sonarr
Current: release-4.0.0.738
Latest: release-4.0.1.1234
Container: sonarr
```

With `DIUN_NOTIF_DISCORD_RENDERFIELDS=true`, you get a nice formatted embed with fields.

## Other Notification Services

### Telegram
```bash
DIUN_NOTIF_TELEGRAM_TOKEN=your_bot_token
DIUN_NOTIF_TELEGRAM_CHATIDS=your_chat_id
```

### Slack
```bash
DIUN_NOTIF_SLACK_WEBHOOKURL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Email (SMTP)
```bash
DIUN_NOTIF_MAIL_HOST=smtp.gmail.com
DIUN_NOTIF_MAIL_PORT=587
DIUN_NOTIF_MAIL_USERNAME=your-email@gmail.com
DIUN_NOTIF_MAIL_PASSWORD=your-app-password
DIUN_NOTIF_MAIL_FROM=your-email@gmail.com
DIUN_NOTIF_MAIL_TO=recipient@example.com
```

### Pushover
```bash
DIUN_NOTIF_PUSHOVER_TOKEN=your_app_token
DIUN_NOTIF_PUSHOVER_RECIPIENT=your_user_key
```

### Gotify
```bash
DIUN_NOTIF_GOTIFY_ENDPOINT=https://gotify.example.com
DIUN_NOTIF_GOTIFY_TOKEN=your_token
```

For complete list: https://crazymax.dev/diun/notif/overview/

## Advanced Configuration

### Control What's Monitored

By default, only containers with `diun.enable=true` label are monitored:

```yaml
labels:
  - "diun.enable=true"
```

To monitor ALL containers by default:
```bash
DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true
```

Then exclude specific containers:
```yaml
labels:
  - "diun.enable=false"
```

### Watch Specific Tags

Monitor specific image tags instead of `latest`:

```yaml
labels:
  - "diun.enable=true"
  - "diun.watch_repo=true"
  - "diun.include_tags=^\\d+\\.\\d+\\.\\d+$"  # Semantic versions only
```

### Custom Check Intervals Per Container

```yaml
labels:
  - "diun.enable=true"
  - "diun.watch_schedule=0 0 * * *"  # Daily for this container
```

### Notification Threshold

Only notify if image is older than a certain time:

```yaml
labels:
  - "diun.enable=true"
  - "diun.max_diff_hours=24"  # Only notify if update is >24h old
```

### Filter by Platform

Only watch specific platform images:

```bash
DIUN_WATCH_WORKERS=20
DIUN_WATCH_SCHEDULE=0 */6 * * *
DIUN_WATCH_FIRSTCHECKNOTIF=false  # Don't notify on first check
```

## Troubleshooting

### No Notifications Received

**Check Diun is running:**
```bash
docker ps | grep diun
```

**Check Diun logs:**
```bash
docker logs diun
```

Look for:
```
Loaded X containers to watch
```

**Verify webhook URL:**
```bash
# Test Discord webhook manually
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"Test from Diun setup"}'
```

You should see the test message in Discord.

**Common issues:**
1. Webhook URL is empty or incorrect
2. Discord webhook was deleted
3. No containers have `diun.enable=true` label
4. Socket-proxy not running (Diun can't access Docker)

### Diun Not Finding Containers

**Verify socket-proxy connectivity:**
```bash
docker logs diun | grep -i error
docker logs socket-proxy
```

**Check labels:**
```bash
docker inspect CONTAINER_NAME | grep -A 5 Labels
```

Should show:
```json
"Labels": {
  "diun.enable": "true",
  ...
}
```

### Too Many Notifications

**Increase check interval:**
```bash
DIUN_WATCH_SCHEDULE=0 0 4 * * *  # Once daily at 4 AM
```

**Or add threshold:**
```yaml
labels:
  - "diun.max_diff_hours=72"  # Only notify if update >3 days old
```

**Or disable first-check notifications:**
```bash
DIUN_WATCH_FIRSTCHECKNOTIF=false
```

### Discord Webhook Fails

**Error:** `webhook URL is required`

**Fix:** Ensure `.env` has:
```bash
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
```

**Error:** `401 Unauthorized`

**Fix:** Webhook was deleted or token is wrong. Create a new webhook in Discord.

**Error:** `404 Not Found`

**Fix:** Webhook ID is wrong. Copy the URL again from Discord.

### Test Individual Container

Force check a specific container:

```bash
# Check all watched containers now
docker exec diun diun exec

# Test notification system
docker exec diun diun notif test
```

## Migration from Watchtower

If you're migrating from Watchtower:

### 1. Remove Watchtower

```bash
docker-compose -f docker-compose.arr-stack.yml stop watchtower
docker-compose -f docker-compose.arr-stack.yml rm watchtower
```

### 2. Update .env

Replace:
```bash
WATCHTOWER_SCHEDULE=0 0 4 * * *
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@ID
```

With:
```bash
DIUN_WATCH_SCHEDULE=0 */6 * * *
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
```

### 3. Update Labels

Watchtower labels like:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

Are NOT used by Diun. The template already has `diun.enable=true` labels.

### 4. Deploy Diun

```bash
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml up -d
```

### 5. Verify

```bash
docker logs diun
```

## Examples

### Minimal Setup
```bash
# .env
DIUN_WATCH_SCHEDULE=0 0 4 * * *
DIUN_DISCORD_WEBHOOK_URL=
```
No notifications, just logs.

### Production Setup
```bash
# .env
DIUN_WATCH_SCHEDULE=0 */6 * * *
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123/abc
```
Check every 6 hours, notify to Discord.

### Conservative Monitoring
```bash
# .env
DIUN_WATCH_SCHEDULE=0 0 3 * * SUN
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123/abc
```
Check weekly on Sunday at 3 AM.

## Best Practices

1. **Don't auto-update** - Diun's strength is manual control
2. **Check logs first** - Review what changed before updating
3. **Test updates in dev** - Don't update production blindly
4. **Use semantic versioning** - Pin to major versions when possible
5. **Monitor critical services** - Add `diun.enable=true` to important containers
6. **Regular schedule** - Every 6 hours catches updates quickly
7. **Backup before updates** - Always backup configs before updating

## Security

### Why Socket-Proxy?

Diun needs read-only Docker API access to:
- List containers
- Get container labels
- Get image information

Socket-proxy provides:
- ✅ Read-only access
- ✅ No execute permissions
- ✅ No secrets access
- ✅ Network isolation

### What Diun Can Do

With socket-proxy, Diun can:
- ✅ List containers (CONTAINERS=1)
- ✅ Get image info (IMAGES=1)

With socket-proxy, Diun CANNOT:
- ❌ Execute commands in containers (EXEC=0)
- ❌ Access secrets (SECRETS=0)
- ❌ Modify containers
- ❌ Delete containers

## References

- Diun Documentation: https://crazymax.dev/diun/
- Notification Providers: https://crazymax.dev/diun/notif/overview/
- Configuration Options: https://crazymax.dev/diun/config/
- Docker Provider: https://crazymax.dev/diun/providers/docker/
- Discord Webhooks: https://support.discord.com/hc/en-us/articles/228383668

## Quick Reference

### Common Commands

```bash
# View logs
docker logs diun

# Follow logs live
docker logs -f diun

# Restart Diun
docker-compose -f docker-compose.arr-stack.yml restart diun

# Force check now
docker exec diun diun exec

# Test notifications
docker exec diun diun notif test

# Check which containers are monitored
docker ps --filter "label=diun.enable=true"
```

### Environment Variables Quick Reference

```bash
# Required
DIUN_WATCH_SCHEDULE=0 */6 * * *

# Discord (optional)
DIUN_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN

# Docker provider (already configured in template)
DIUN_PROVIDERS_DOCKER=true
DIUN_PROVIDERS_DOCKER_ENDPOINT=tcp://socket-proxy:2375
DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=false

# Logging (optional)
LOG_LEVEL=info
LOG_JSON=false
```

### Label Quick Reference

```yaml
# Enable monitoring
labels:
  - "diun.enable=true"

# Custom schedule for this container
labels:
  - "diun.enable=true"
  - "diun.watch_schedule=0 0 * * *"

# Watch all tags, not just latest
labels:
  - "diun.enable=true"
  - "diun.watch_repo=true"

# Only notify if update is >24h old
labels:
  - "diun.enable=true"
  - "diun.max_diff_hours=24"
```

---

**Last Updated:** 2026-02-14
