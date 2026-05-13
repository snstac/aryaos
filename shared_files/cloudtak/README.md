# CloudTAK standalone shim (AryaOS)

Minimal Docker Compose stack for the upstream **CloudTAK-SA shim** only (no full CloudTAK AWS/API stack).

## Upstream pin

- **Repository:** https://github.com/snstac/CloudTAK-SA  
- **Commit:** `5e21204da12cc997fc57cb5000db5611bc931581` (`copilot/add-shim-for-cloudtak-client` at time of vendoring)  
- **Installed on image:** `/opt/cloudtak` (`docker-compose.yml`, `shim/` build context)

## Ports (published on all interfaces)

| Port | Purpose |
|------|---------|
| 8080 | Injection HTTP API |
| 8089 | CoT over TLS (TAK stream) |
| 8443 | Marti / WebTAK HTTPS API |

## TLS / `shim/certs`

Compose bind-mounts `./shim/certs` → `/app/certs` in the container. On first start the shim generates `ca.crt`, `ca.key`, `server.crt`, and `server.key` (see upstream `shim/lib/ca.ts`). Files persist on disk for later boots; no separate OpenSSL step is required on AryaOS.

## Service

`cloudtak-shim.service` runs `docker compose up -d --build` from `/opt/cloudtak` after Docker is up.

<!--
SPDX-License-Identifier: Apache-2.0
-->
