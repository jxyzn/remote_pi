# Remote Pi Deployment & Web Client Guide

This document describes a reference self-hosted deployment architecture, configuration, and considerations for running the Remote Pi web app, relay server, and reverse proxy.

---

## 1. Architecture Overview

```
                      +---------------------------------------+
                      |               Browser                 |
                      |   http://web.example.com/remote-pi/   |
                      +-------------------+-------------------+
                                          |
                        +-----------------+-----------------+
                        | (WebSocket WSS)                   | (HTTP GET / POST / OPTIONS)
                        v                                   v
             +-----------------------+           +-----------------------+
             | relay.example.com:443 |           | relay.example.com:443 |
             | lighttpd reverse      |           | lighttpd reverse      |
             | proxy (/remote-pi)    |           | proxy (/remote-pi)    |
             +-----------+-----------+           +-----------+-----------+
                        |                                   | (CORS preflight
                        | proxy -> :3001                    |  handled locally;
                        v                                   |  proxies API)
             +-----------------------+                      |
             | docker-host:3001      | <--------------------+
             | remote-pi-relay       |
             | (Docker container)    |
             +-----------------------+
```

- **Web App Host (`web.example.com`)**:
  - Serves static Flutter web build from `/var/www/remote-pi` (symlinked to `/opt/remote-pi/app/build/web`).
  - Accessible via `http://web.example.com/remote-pi/`.
  - Built with base href: `flutter build web --base-href "/remote-pi/"` (or via `./scripts/build-web.sh`).

- **Relay Container (`docker-host`)**:
  - Runs in Docker from compose file `/opt/remote-pi-relay/docker-compose.yml`.
  - Image: `jacobmoura7/remote-pi-relay:latest` (Rust Axum relay).
  - Port mapping: `3001:3000`.
  - Volume: `remote-pi-data:/data` hosting `/data/mesh.db`.

- **Reverse Proxy & SSL (`relay.example.com`)**:
  - Runs `lighttpd` terminating TLS on port 443 for `relay.example.com`.
  - Configuration: `/etc/lighttpd/conf-available/14-proxy-remote-pi.conf` (tracked in repository at `relay/lighttpd/14-proxy-remote-pi.conf`).
  - Proxies `/remote-pi` to `http://10.0.0.10:3001` (`docker-host`).
  - WebSocket upgrade enabled with zero read/write timeout.

---

## 2. Key Web Compatibility Solutions

### Insecure Context Storage Fallback (`WebInsecureStoragePlatform`)
- **Problem**: When accessing `http://web.example.com/remote-pi/` over plain HTTP (any non-localhost hostname), modern browsers mark the environment as an **insecure context** (`window.isSecureContext === false`). The `flutter_secure_storage_web` plugin uses `window.crypto.subtle`, which is restricted to secure contexts by the W3C spec and is `undefined`. Any read/write threw an uncatchable TypeError on startup.
- **Solution**: [`WebInsecureStoragePlatform`](../app/lib/pairing/web_insecure_storage_platform.dart) subclasses `FlutterSecureStoragePlatform` and registers itself as the active platform instance on startup when `!window.isSecureContext`. It stores base64-encoded credentials directly in standard `window.localStorage` with key prefix `rp_web_storage.`.

### Web Identity & Platform Guards
- **Web Owner Identity**: Uses [`WebOwnerIdentityStore`](../app/lib/pairing/web_owner_identity_store.dart) backed by secure storage rather than native mobile MethodChannels.
- **WebSocket Transport**: [`WsTransport`](../app/lib/data/transport/ws_transport.dart) connects via `WebSocketChannel.connect(uri)` on web rather than `IOWebSocketChannel.connect` (which requires `dart:io`).
- **`Platform.environment` / `Platform.is*`**: All access to `dart:io` `Platform` is guarded with `if (!kIsWeb)`.

### CORS & Preflight Handling on `relay.example.com`
- **Problem**: When the web app at `http://web.example.com` calls the relay at `https://relay.example.com/remote-pi/mesh/<owner_pk_hash>`:
  1. The browser sends an `OPTIONS` preflight request.
  2. The Axum relay backend only routes `GET` and `POST`, returning `405 Method Not Allowed` on `OPTIONS` without CORS headers.
  3. `GET` (which returns 404 when no mesh blob is published yet) had no `Access-Control-Allow-Origin` header, causing Chrome to block the client from reading the response.
- **Solution**:
  - `lighttpd` config (`14-proxy-remote-pi.conf`) injects CORS response headers (`Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods: GET, POST, OPTIONS`, etc.).
  - `lighttpd` intercepts `OPTIONS` requests via `url.rewrite-once = ( ".*" => "/remote-pi/cors-options" )` (where `/var/www/remote-pi/cors-options` is an empty file), returning `200 OK` directly without passing `OPTIONS` to the backend.

### Default Relay Endpoint
- [`kDefaultRelayUrl`](../app/lib/data/transport/relay_config.dart) defaults to `https://relay-rp1.jacobmoura.work`. Users can configure a custom self-hosted relay URL (e.g. `https://relay.example.com/remote-pi`) in Onboarding or Settings.

---

## 3. Maintenance & Update Commands

### Rebuilding and Deploying the Web App
From the repository root on `web.example.com`:
```bash
./scripts/build-web.sh
```
Or manually:
```bash
export PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$PATH"
cd app
flutter build web --base-href "/remote-pi/"
```

### Syncing Lighttpd Configuration to `relay.example.com`
If `relay/lighttpd/14-proxy-remote-pi.conf` is updated:
```bash
scp relay/lighttpd/14-proxy-remote-pi.conf relay.example.com:/tmp/14-proxy-remote-pi.conf
ssh relay.example.com "sudo mv /tmp/14-proxy-remote-pi.conf /etc/lighttpd/conf-available/14-proxy-remote-pi.conf && sudo lighttpd -tt -f /etc/lighttpd/lighttpd.conf && sudo systemctl restart lighttpd"
```

### Checking Relay Health & Logs on `docker-host`
```bash
ssh docker-host "docker logs --tail 50 remote-pi-relay"
```
