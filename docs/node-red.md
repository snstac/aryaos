# Node-RED dashboard

AryaOS ships [Node-RED](https://nodered.org/) as an optional low-code
automation and visualization surface. It runs as **`nodered.service`** on port
**1880**; the read-only **Dashboard** is at **`http://<host>:1880/ui`** and the
flow editor at **`http://<host>:1880/`**.

!!! warning "Rotate the Node-RED admin password before fielding a unit"
    Node-RED ships with a **publicly known default admin password** and its
    editor can run code on the device. Change it from **AryaOS Site → Node-RED
    admin password** (see [AryaOS Site](admin/aryaos-site.md)) or with
    `sudo aryaos-set-nodered-password`. Restrict access to the flow editor on any
    production gateway.

## What it does

| Tab / flow | Purpose |
|------------|---------|
| **Dashboard** | Admin links to the portal, Cockpit, and the onboarding hotspot |
| **TAK / Maps** | Mesh SA visualization (world map) — read-only ops picture |
| **TFR** | Injects Temporary Flight Restriction CoT from a `TFR_STATE` file |
| **Recorder** | Optional CoT logging under `/var/www/html/recorder/` |
| **ADS-B** | Decoder stats display when JSON feeds are present |
| **Debug Logs** | Operator debug channel |

## Node-RED is not the admin surface

Earlier AryaOS builds used Node-RED to edit configuration. That role has moved
entirely to the [web console](admin/index.md) — Node-RED is now for
visualization and custom automation only. Configure the system here instead:

| Need | Where |
|------|-------|
| Site TAK destination, TLS, role, updates | [AryaOS Site page](admin/aryaos-site.md) |
| Where CoT flows (Mesh SA / TAK Server) | [Charontak lane editor](admin/charontak-lanes.md) |
| Per-sensor settings | [Gateway pages](admin/gateways.md) → `/etc/default/<svc>` |
| SDR serials & decoder | [Radios & SDRs](config/radios-sdr.md) |
| Wi-Fi / hotspot | [Wi-Fi & onboarding hotspot](networking/wifi-hotspot.md) |
| Services (start/stop/restart) | Cockpit → Services, or each gateway page |

## Security

- The **`node-red`** user is **not** in the `sudo` group and has no passwordless
  `sudo` rules (see `/etc/sudoers.d/aryaos`).
- Node-RED owns only its own configuration, not the AryaOS TLS material.
- Flows are provisioned at build time from
  [`shared_files/node-red/`](https://github.com/snstac/aryaos/tree/main/shared_files/node-red);
  Node-RED loads `flows.json` on restart: `sudo systemctl restart nodered`.

See the [security posture](security.md) for the full picture.
