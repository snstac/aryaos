# Node-RED (ops dashboard)

Node-RED runs as **`nodered.service`** on port **1880**. The **Dashboard** UI is at **`http://<host>:1880/ui`** (or HTTPS if proxied).

## What it still does

| Tab / flow | Purpose |
|------------|---------|
| **Dashboard** | Admin links to portal, Cockpit, and Comitup |
| **TAK / Maps** | Mesh SA visualization (`tak2wm`, world map) — read-only ops |
| **TFR** | Injects TFR CoT from **`TFR_STATE`** file |
| **Recorder** | Optional logging under **`/var/www/html/recorder/`** |
| **ADS-B** | Decoder stats display (when JSON feeds are present) |
| **Debug Logs** | Operator debug channel |

Flow editor: **`http://<host>:1880/`** (restrict access on production gateways).

## What was removed (legacy config sunset)

The following Dashboard tabs and flows were **removed**; do not expect them on current images:

- **Config** — edited **`aryaos-config.txt`**, **`/etc/default/*`**, PyTAK TLS fields
- **Update** — `.deb` upload / **`dpkg -i`**
- **OS Status** — host/GNSS/service polling (superseded by the [HTTPS portal](portal.md))
- **Control / Admin** — **`systemctl`**, reboot/shutdown, WiFi **`wifi-nuke`**

**Use instead:**

| Need | Surface |
|------|---------|
| Status | [Portal](portal.md) **`GET /cgi-bin/aryaos-portal-status`** |
| Services | Cockpit → Services |
| Charontak upstream | Cockpit → Charontak fields → **`/etc/charontak.ini`** |
| Feeders | Cockpit **`adsbcot`** / **`aiscot`** + **`/etc/default/*`** |
| WiFi | Comitup **`:9080`** |

## Security

- **`node-red`** is **not** in the **`sudo`** group.
- No passwordless **`sudo`** rules for **`node-red`** (see **`/etc/sudoers.d/aryaos`**).
- Regenerate flows from [`shared_files/node-red/aryaos_flows.json`](../shared_files/node-red/aryaos_flows.json) via pi-gen / Ansible stage-node-red.

## Known gaps (no Node-RED replacement)

| Gap | Workaround |
|-----|------------|
| SDR serial / decoder choice | SSH, Ansible, [#21](https://github.com/snstac/AryaOS/issues/21), [`readsb-use-rtl-serial.sh`](../scripts/readsb-use-rtl-serial.sh) |
| **cockpit-lincot** UI | Edit **`/etc/default/lincot`** until upstream packages **`cockpit-lincot`** |
| Feeder restart helper | Manual **`systemctl restart charontak adsbcot aiscot lincot dronecot`** after config edits ([config.md](config.md)) |

## Dev / lab

Mirror flows to the lab Pi with **`./scripts/sync-to-dev-pi.sh`** (full tree). Node-RED picks up **`flows.json`** on service restart: **`sudo systemctl restart nodered`**.

Source: [`scripts/strip-node-red-config-flows.py`](../scripts/strip-node-red-config-flows.py) documents the sunset transform applied to **`aryaos_flows.json`**.
