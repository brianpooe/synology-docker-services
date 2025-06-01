# Homelab

# Synology arr stack installation guide
### [TRaSH Guides](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Synology/)

# Recyclarr installation guide
#### Recyclarr is a command-line application that will automatically synchronize recommended settings from the TRaSH guides to your Sonarr/Radarr instances.
### [Recyclarr Wiki](https://wiki.serversatho.me/en/Recyclarr)

## Pgadmin permissions issue
```shell
    chown -R 5050:5050 /volume1/docker/appdata/pgadmin
```

## [Connect vault to postgres database](https://developer.hashicorp.com/vault/docs/configuration/storage/postgresql) 

## Caddyfile
### paperless-ngx config
If you've installed **Paperless-ngx** directly in a Proxmox LXC container, the key considerations remain similar but with slightly adjusted setup.

Here's a clear step-by-step fix for the **CSRF error (403)** when using Paperless-ngx directly installed in an LXC behind **Caddy**:

---

### ✅ **1. Confirm Paperless Configuration (`paperless.conf` or `.env`):**

Inside your LXC container, Paperless needs explicit trust for the domain:

```bash
sudo nano /etc/paperless.conf
```

Ensure you have:

```env
PAPERLESS_URL=https://paperless.example.com
PAPERLESS_ALLOWED_HOSTS=paperless.example.com
PAPERLESS_CSRF_TRUSTED_ORIGINS=https://paperless.example.com
```

Replace `paperless.example.com` with your actual domain.

---

### ✅ **2. Adjust Django Settings (if custom):**

Usually, Paperless-ngx includes these settings automatically, but you can explicitly verify:

* Ensure settings reflect headers forwarded by Caddy:

```env
PAPERLESS_FORCE_SCRIPT_NAME=/
```

*(Typically not required, but can help in edge cases.)*

---

### ✅ **3. Proper Caddyfile Configuration:**

Your Caddyfile should explicitly forward crucial headers correctly:

```caddy
paperless.example.com {
    reverse_proxy localhost:8000 {
        header_up Host {host}
        header_up X-Forwarded-Proto https
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        Referrer-Policy same-origin
        X-Content-Type-Options nosniff
    }

    encode gzip
}
```

Make sure the port (`8000`) matches the port your Paperless-ngx instance runs on inside your LXC container.

---

### ✅ **4. Ensure Paperless is aware of Proxy Headers:**

Make sure the Gunicorn or the internal server running Paperless is aware it's behind a reverse proxy:

If using Gunicorn explicitly, run with:

```bash
gunicorn paperless.asgi:application --bind 0.0.0.0:8000 --forwarded-allow-ips="*"
```

*If Paperless runs through systemd, you can modify its startup parameters accordingly.*

---

### ✅ **5. Restart everything:**

Inside your LXC container:

```bash
sudo systemctl restart paperless
```

Outside, reload Caddy to ensure config is active:

```bash
sudo caddy reload
```

---

### ⚠️ **Testing:**

* Clear your browser cache or use incognito mode.
* Open `https://paperless.example.com`.
* Attempt login again.

---

Following these steps will resolve the CSRF errors occurring due to header misconfigurations between Caddy and Django (Paperless-ngx).
