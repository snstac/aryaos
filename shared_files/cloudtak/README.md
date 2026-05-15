# CloudTAK on AryaOS

Docker Compose stack: **shim** (TAK/Marti backend) plus **web** (browser client), exposed on the device portal at **`https://<host>/cloudtak/`** via lighttpd.

## Upstream pin

- **Repository:** https://github.com/snstac/CloudTAK-SA  
- **Branch:** `copilot/add-shim-for-cloudtak-client` (web image build clones this at container build time)  
- **Shim vendored in repo:** `shared_files/cloudtak/shim/`  
- **Installed on image:** `/opt/cloudtak`

## Portal URL

| URL | Backend |
|-----|---------|
| `https://<host>/cloudtak/` | CloudTAK web UI (loopback `:5000`) |
| `https://<host>/cloudtak/Marti/...` | Marti shim API (loopback HTTP `:18443`) |

lighttpd terminates TLS on `:443` and reverse-proxies; see `shared_files/aryaos/96-aryaos-cloudtak-proxy.conf`.

## Shim ports (published on all interfaces)

| Port | Purpose |
|------|---------|
| 8080 | Injection HTTP API |
| 8089 | CoT over TLS (TAK stream) |
| 8443 | Marti HTTPS API (direct; browser may warn on shim cert) |

Loopback **HTTP `18443`** is for lighttpd → Marti only (`SA_SHIM_MARTI_HTTP_PORT`).

## TLS / `shim/certs`

Compose bind-mounts `./shim/certs` → `/app/certs`. On first start the shim generates CA and server certificates (see `shim/lib/ca.ts`).

## Service

`cloudtak-shim.service` runs `docker compose up -d --build` from `/opt/cloudtak` after Docker is up. The first build of the **web** image compiles upstream CloudTAK `api/web` and can take several minutes on a Raspberry Pi.

## Connection

In the CloudTAK UI, point the server / Marti URL at **`https://<hostname-or-ip>/cloudtak/`** (same origin as the portal) so API calls use the proxied Marti path.

<!--
SPDX-License-Identifier: Apache-2.0
-->
