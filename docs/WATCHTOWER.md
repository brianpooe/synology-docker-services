# Watchtower Configuration Guide

Watchtower automatically updates your Docker containers when new images are available.

## Table of Contents
- [Basic Configuration](#basic-configuration)
- [Discord Notifications](#discord-notifications)
- [Other Notification Services](#other-notification-services)
- [Troubleshooting](#troubleshooting)

## Basic Configuration

### Schedule
Set update schedule in `.env` using cron format:

```bash
# Daily at 4 AM
WATCHTOWER_SCHEDULE=0 0 4 * * *

# Every Sunday at 3 AM
WATCHTOWER_SCHEDULE=0 0 3 * * SUN

# Every 6 hours
WATCHTOWER_SCHEDULE=0 0 */6 * * *
```

Cron format: `second minute hour day month weekday`

### Disable Notifications
Leave the notification URL empty to run without notifications:

```bash
WATCHTOWER_NOTIFICATION_URL=
```

## Discord Notifications

### Step 1: Create Discord Webhook

1. Open Discord and go to your server
2. Click Server Settings (gear icon)
3. Go to **Integrations** → **Webhooks**
4. Click **New Webhook** or **Create Webhook**
5. Configure:
   - Name: `Watchtower`
   - Channel: Select where notifications should go
6. Click **Copy Webhook URL**

You'll get a URL like:
```
https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ
```

### Step 2: Convert to Shoutrrr Format

**IMPORTANT:** Do NOT use the Discord URL directly. You must convert it to Shoutrrr format.

Discord webhook URL format:
```
https://discord.com/api/webhooks/WEBHOOK_ID/TOKEN
```

Convert to Shoutrrr format:
```
discord://TOKEN@WEBHOOK_ID
```

**Example:**

Discord webhook:
```
https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ
```

Shoutrrr format (what you put in .env):
```bash
WATCHTOWER_NOTIFICATION_URL=discord://abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ@1234567890
```

### Step 3: Update .env File

Edit your `.env` file:

```bash
WATCHTOWER_NOTIFICATION_URL=discord://YOUR_TOKEN@YOUR_WEBHOOK_ID
WATCHTOWER_SCHEDULE=0 0 4 * * *
```

### Step 4: Restart Watchtower

```bash
docker-compose down watchtower
docker-compose up -d watchtower
```

Check logs to verify:
```bash
docker logs watchtower
```

You should see:
```
Watchtower 1.x.x
Using notifications: discord
```

### Discord Notification Customization

Add parameters to customize notifications:

```bash
# Add username
discord://TOKEN@WEBHOOK_ID?username=Watchtower

# Add avatar
discord://TOKEN@WEBHOOK_ID?avatar=https://i.imgur.com/xyz.png

# Combine parameters
discord://TOKEN@WEBHOOK_ID?username=Watchtower&avatar=https://i.imgur.com/xyz.png
```

## Other Notification Services

### Slack
```bash
WATCHTOWER_NOTIFICATION_URL=slack://TOKEN@CHANNEL
```

### Email (SMTP)
```bash
WATCHTOWER_NOTIFICATION_URL=smtp://username:password@host:port/?fromAddress=from@example.com&toAddresses=to@example.com
```

### Telegram
```bash
WATCHTOWER_NOTIFICATION_URL=telegram://TOKEN@telegram?channels=CHANNEL_ID
```

### Pushover
```bash
WATCHTOWER_NOTIFICATION_URL=pushover://shoutrrr:TOKEN@USER_KEY/?devices=DEVICE1,DEVICE2
```

### Multiple Services
Send to multiple services by separating with space:

```bash
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@WEBHOOK_ID slack://TOKEN@CHANNEL
```

For complete list: https://containrrr.dev/shoutrrr/v0.8/services/overview/

## Troubleshooting

### Error: "unknown service 'https'"

**Problem:** You're using the Discord webhook URL directly instead of converting to Shoutrrr format.

**Wrong:**
```bash
WATCHTOWER_NOTIFICATION_URL=https://discord.com/api/webhooks/1234567890/abcdefg
```

**Correct:**
```bash
WATCHTOWER_NOTIFICATION_URL=discord://abcdefg@1234567890
```

### Error: "Failed to initialize Shoutrrr notifications"

**Possible causes:**
1. Wrong URL format
2. Invalid token or webhook ID
3. Webhook was deleted in Discord

**Solution:**
1. Verify webhook still exists in Discord
2. Double-check the format: `discord://TOKEN@WEBHOOK_ID`
3. Ensure no extra spaces or quotes
4. Check logs: `docker logs watchtower`

### Notifications Not Arriving

**Check:**
1. Watchtower is actually running: `docker ps | grep watchtower`
2. Webhook URL is correct in `.env`
3. Discord webhook is active (test in Discord settings)
4. Check Watchtower logs for errors: `docker logs watchtower`

### Test Notifications

Watchtower only sends notifications when:
- Container updates are found
- Updates are applied
- Errors occur during updates

To test, you can:
1. Pull an older image version: `docker pull image:old-tag`
2. Tag it as latest: `docker tag image:old-tag image:latest`
3. Wait for Watchtower to run
4. It should detect and update, sending notification

Or trigger manual run:
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_NOTIFICATION_URL="discord://TOKEN@WEBHOOK_ID" \
  containrrr/watchtower \
  --run-once \
  --cleanup
```

## Advanced Configuration

### Scope to Specific Containers
Only monitor containers matching scope:

```bash
WATCHTOWER_SCOPE=media-stack
```

Then label containers:
```yaml
labels:
  - "com.centurylinklabs.watchtower.scope=media-stack"
```

### Label-Based Filtering
Only monitor containers with specific label:

```bash
WATCHTOWER_LABEL_ENABLE=com.centurylinklabs.watchtower.enable
```

Then add to containers you want monitored:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

### Monitor-Only Mode
Check for updates without applying them:

```yaml
environment:
  WATCHTOWER_MONITOR_ONLY: "true"
```

You'll get notifications about available updates, but containers won't be updated automatically.

## Security Best Practices

1. **Use socket-proxy** (already configured in arr-stack)
   - Limits Watchtower's Docker API access
   - Only grants necessary permissions

2. **Scope or label filtering**
   - Prevent Watchtower from updating critical services
   - Use `WATCHTOWER_SCOPE` or `WATCHTOWER_LABEL_ENABLE`

3. **Exclude critical containers**
   ```yaml
   labels:
     - "com.centurylinklabs.watchtower.enable=false"
   ```

4. **Run at off-peak hours**
   ```bash
   WATCHTOWER_SCHEDULE=0 0 3 * * *  # 3 AM daily
   ```

5. **Enable notifications**
   - Know when updates happen
   - Get alerts on failures

## Examples

### Minimal Setup (No Notifications)
```bash
WATCHTOWER_SCHEDULE=0 0 4 * * *
WATCHTOWER_NOTIFICATION_URL=
```

### Production Setup (Discord + Scoped)
```bash
WATCHTOWER_SCHEDULE=0 0 3 * * SUN
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@WEBHOOK_ID?username=Watchtower
WATCHTOWER_SCOPE=media-stack
```

### Monitor-Only (Test Updates)
```bash
WATCHTOWER_SCHEDULE=0 0 4 * * *
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@WEBHOOK_ID
WATCHTOWER_MONITOR_ONLY=true
```

## References

- Watchtower Documentation: https://containrrr.dev/watchtower/
- Shoutrrr Services: https://containrrr.dev/shoutrrr/v0.8/services/overview/
- Discord Webhooks Guide: https://support.discord.com/hc/en-us/articles/228383668
- Cron Expression Helper: https://crontab.guru/
