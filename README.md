# docker-cronicle
Docker Image for Cronicle Scheduler

| Build | latest | git-volume-backup |
|-------|--------|-------------------|
| [![Build status](https://img.shields.io/docker/build/leodagan/cronicle.svg)](https://hub.docker.com/r/leodagan/cronicle/) | [![Image Size](https://img.shields.io/microbadger/image-size/leodagan/cronicle/latest.svg)](https://microbadger.com/images/leodagan/cronicle:latest) [![Layers](https://img.shields.io/microbadger/layers/leodagan/cronicle/latest.svg)](https://microbadger.com/images/leodagan/cronicle:latest) | [![Image Size](https://img.shields.io/microbadger/image-size/leodagan/cronicle/git-volume-backup.svg)](https://microbadger.com/images/leodagan/cronicle:git-volume-backup) [![Layers](https://img.shields.io/microbadger/layers/leodagan/cronicle/git-volume-backup.svg)](https://microbadger.com/images/leodagan/cronicle:git-volume-backup) |

# Try It

```
docker run --rm -name cronicle -p 80:80 -p 443:443 -e MASTER_PING_TIMEOUT=1 leodagan/cronicle
```

Or with uncommon ports

```
docker run --rm -name cronicle -p 8080:8080 -p 8443:8443 -e MASTER_PING_TIMEOUT=1 -e WEBSERVER_HTTP_PORT=8080 -e WEBSERVER_HTTPS_PORT=8443 leodagan/cronicle
```

Bind ```/opt/cronicle/data``` for persistence

# Environment Variables

| Config Key | Default Value | Description |
|------------|---------------|-------------|
| BASE_APP_URL | HTTPS HOST | Application Base URL |
| SECRET_KEY | Random | Cronicle Server Secret Key |
| EMAIL_FROM | None | Cronicle E-Mail From |
| SMTP_HOSTNAME | None | Cronicle SMTP Server |
| SMTP_PORT | None | Cronicle SMTP Port |
| SMTP_SECURE | None | Cronicle SMTP Secure Protocol |
| SMTP_USER | None | Cronicle SMTP Username |
| SMTP_PASSWORD | None | Cronicle SMTP Password |
| WEB_SOCKET_USE_HOSTNAMES | 1 | Does Cronicle Web Socket use Hostnames instead of IP |
| SERVER_COMM_USE_HOSTNAMES | 1 | Does Cronicle Comms use Hostnames instead of IP |
| WEBSERVER_HTTP_PORT | 80 | Cronicle Webserver Public HTTP Port |
| WEBSERVER_HTTPS_PORT | 443 | Cronicle Webserver Public HTTPS Port |
| WEBSERVER_HTTPS | true | Enable Cronicle HTTPS Webserver |
| MASTER_PING_TIMEOUT | 60 | Ping timeout joining existing pool beforme becoming Master |
| CRONICLE_ADMIN_USERNAME | admin | Cronicle Admin Username |
| CRONICLE_ADMIN_PASSWORD | admin | Cronicle Admin Password |
| CRONICLE_ADMIN_EMAIL | admin@localhost | Cronicle Admin E-Mail |
| TZ | UTC | Timezone for Container |

