# CloudTAK on AryaOS

Docker Compose stack: **shim** (TAK/Marti + faux CloudTAK REST backend) plus **web** (browser client). Quick access without the portal: **`http://<host>:5000/cloudtak/`**. With lighttpd: **`https://<host>/cloudtak/`** (TLS).

REST calls **`/cloudtak/api/...`** (or **`/api/...`** behind lighttpd’s prefix strip) are proxied by the **web** nginx container to the shim’s Marti HTTP port **`18443`**, which serves both Marti-compatible paths (**`/Marti/...`**) and the minimal **`/api/...`** façade used by the SPA (login, config, fonts proxy, etc.).

## Default credentials

These are intentionally simple for labs. **Override them on any real deployment**: copy
`.env.example` to `.env` next to `docker-compose.yml` and set `CLOUDTAK_USER` /
`CLOUDTAK_PASSWORD` — Compose substitutes them into the shim environment automatically.

Use the **same username and password** for:

| Use | Detail |
|-----|--------|
| **CloudTAK web login** (`POST …/cloudtak/api/login`) | Form login in the SPA |
| **Marti HTTPS enrollment Basic auth** | `Authorization: Basic …` on **`/Marti/api/tls/config`** and **`POST /Marti/api/tls/signClient/v2`** (e.g. cert enrollment from TAK tools) |

| Field | Default | Environment variables |
|-------|---------|------------------------|
| Username | `cloudtak` | `SA_SHIM_LOGIN_USER` / `SA_SHIM_BASIC_USER` |
| Password | `cloudtak415` | `SA_SHIM_LOGIN_PASSWORD` / `SA_SHIM_BASIC_PASSWORD` |

If only one pair is set, login and Basic auth share it (`LOGIN_*` falls back to `BASIC_*` and vice versa in the shim).

## Upstream pin

- **Repository:** https://github.com/snstac/CloudTAK-SA  
- **Branch:** `copilot/add-shim-for-cloudtak-client` (web image build clones this at container build time)  
- **Shim vendored in repo:** `shared_files/cloudtak/shim/`  
- **Installed on image:** `/opt/cloudtak`

## URLs

| URL | Backend |
|-----|---------|
| `http://<host>:5000/cloudtak/` | CloudTAK web UI (docker **web** on all interfaces) |
| `https://<host>/cloudtak/` | Same UI via portal + TLS (lighttpd → `:5000`) |
| `…/cloudtak/api/…` or `…/api/…` (after strip) | Faux REST on shim `:18443` via nginx proxy |
| `https://<host>/cloudtak/Marti/...` | Marti shim only (lighttpd → loopback `:18443`) |
| `https://<host>:8443/` | Marti shim HTTPS (browser will warn — shim cert; direct to container) |

lighttpd terminates TLS on `:443` and reverse-proxies; see `shared_files/aryaos/96-aryaos-cloudtak-proxy.conf`.

The **web** image runs `patch-aryaos-subpath.mjs` before `npm run build` so Vue Router, **`std()` URLs**, API client base, and service worker use the `/cloudtak/` base.

## Shim ports (published on all interfaces)

| Port | Purpose |
|------|---------|
| 8080 | Injection HTTP API |
| 8089 | CoT over TLS (TAK stream) |
| 8443 | Marti HTTPS API (direct; browser may warn on shim cert) |

**HTTP `18443`** binds on the shim container for Marti HTTP + **`/api`**. On AryaOS, Compose publishes it as **`127.0.0.1:18443`** on the host for lighttpd; the **web** container reaches **`shim:18443`** over the Compose network.

## TLS / `shim/certs`

Compose bind-mounts `./shim/certs` → `/app/certs`. On first start the shim generates CA and server certificates (see `shim/lib/ca.ts`).

## Service

`cloudtak-shim.service` runs `docker compose up -d --build` from `/opt/cloudtak` after Docker is up. The first build of the **web** image compiles upstream CloudTAK `api/web` and can take several minutes on a Raspberry Pi.

## Connection

- **HTTPS portal:** Open **`https://<hostname-or-ip>/cloudtak/`** and sign in with the default credentials above. Point TAK tooling at **`https://<hostname-or-ip>/cloudtak/`** where appropriate.
- **Plain HTTP:** **`http://<hostname-or-ip>:5000/cloudtak/`**

The faux backend is minimal (no full OpenTAK Server). Map and live features beyond Marti stubs may still return empty data until you extend the shim or attach a full server.

<!--
SPDX-License-Identifier: Apache-2.0
-->
