# Gateway pages

Each sensor gateway on AryaOS has its own Cockpit plugin for fine-tuning. Where the [AryaOS Site page](./aryaos-site.md) sets defaults for the whole device, a gateway page edits **one** service's own settings, controls that service, and shows its logs. All the gateway plugins share the same layout, so once you know one you know them all.

Open any of them from Cockpit's left menu.

## Which plugin manages which service

| Cockpit plugin | Service | Config file | Feeds |
|----------------|---------|-------------|-------|
| adsbcot | `adsbcot` | `/etc/default/adsbcot` | ADS-B aircraft → CoT |
| aiscot | `aiscot` | `/etc/default/aiscot` | AIS vessels → CoT |
| dronecot | `dronecot` | `/etc/default/dronecot` | Remote ID drones → CoT |
| lincot | `lincot` | `/etc/default/lincot` | This host's position/beacon → CoT |
| gps | *(gpsd)* | — | On-board GNSS receiver |
| gpstak | `gpstak` | `/etc/default/gpstak` | Network GPS to ATAK/WinTAK |
| aiscatcher | `ais-catcher` | `/etc/default/ais-catcher` | Over-the-air AIS receiver |

The AIS receiver (`ais-catcher`) demodulates RF AIS and hands messages to `aiscot`; `aiscot` is the CoT feeder. Likewise `readsb`/`dump1090-fa`/`dump978-fa` decode ADS-B/UAT and `adsbcot` feeds the CoT.

!!! note "cockpit-lincot packaging"
    On some images a `cockpit-lincot` plugin may not be published yet; until it lands, edit `/etc/default/lincot` with Cockpit's generic file editor or over SSH. See [Software suite](../reference/software-suite.md).

## The common layout

Every gateway plugin (using **aiscot** as the representative example) shows the same cards, top to bottom:

### Service card

At the top, a **service management** card shows the service's current state and gives you **start / stop / restart / enable** controls. Enabling a service makes it start at boot; the [device role](../config/device-roles.md) also manages enable/disable across the whole sensor set.

### TLS card

A **TLS upload** card installs PEM client credentials for *this* service. For aiscot they go under `/etc/aiscot/tls`, and the plugin fills in the matching `PYTAK_TLS_CLIENT_CERT` / `PYTAK_TLS_CLIENT_KEY` / `PYTAK_TLS_CLIENT_CAFILE` config keys.

!!! tip "Prefer site-wide TLS"
    In most deployments you install **one** set of certs once, on the [AryaOS Site page](./aryaos-site.md#site-wide-tak-tls-certificates), and every gateway inherits it. Use the per-gateway TLS card only when a single service needs a *different* client identity from the rest.

### Configuration card

The **Configuration** card is a form generated from the gateway's environment-variable definitions. Each row shows the variable name, a description, its default, and an input appropriate to its type (text, number, boolean drop-down, or enum drop-down). Required fields are marked. Values are validated as you type — for example `COT_URL` must match a supported scheme, ports must be in range, and enums must be one of the listed options — and invalid fields block the save.

Tick **Restart *service* after save** and press **Validate & Save** to write `/etc/default/<svc>` and (optionally) restart the service.

A representative slice of the aiscot form:

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `COT_URL` | url | `udp+wo://239.2.3.1:6969` | CoT destination for this feeder |
| `LOG_LEVEL` | enum | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `LISTEN_PORT` | number | `5050` | UDP port for over-the-air AIS input |
| `FEED_URL` | url | *(empty)* | Online AIS aggregator feed |
| `IGNORE_ATON` | boolean | `false` | Drop Aids-to-Navigation |
| `UNDERWAY_ONLY` | boolean | `false` | Drop anchored/moored vessels |
| `COT_STALE` | number | `3600` | CoT stale timeout (seconds) |

The other gateways expose their own variables, but the mechanics are identical.

### Debug / logs card

A **Debug Logs** card shows live `systemctl status` output and gives you **Show Logs**, **Follow Logs**, and **Stop Following** buttons that stream the service's journal (`journalctl -u <svc>`).

### Advanced card

An **Advanced Details** card shows the raw contents of the service's `/etc/default/<svc>` file for reference.

## Inheritance: site config, then per-service override

This is the key to how AryaOS gateways are configured:

1. Every gateway's systemd unit reads `/etc/aryaos/aryaos-config.txt` (the site config) via `EnvironmentFile=` **first**.
2. Then it reads its own `/etc/default/<svc>` file.

Because the per-service file is read second, **anything you set on a gateway page overrides the site default** for that one service. Anything you leave unset falls through to the site value.

!!! example "How the default CoT route works"
    The site config sets `COT_URL=udp+wo://127.0.0.1:28087` (the Charontak hub). Each gateway inherits that, so out of the box **every** feeder sends CoT to Charontak — you did not set `COT_URL` on the gateway page. If you *do* set `COT_URL` on, say, the aiscot page, only aiscot changes; the rest keep going through the hub.

This is why the CoT routing invariant holds without per-service configuration: **feeders → charontak → Mesh SA / TAK Server**. Leave each feeder's `COT_URL` unset (inheriting the hub) and control the upstream in the [Charontak lane editor](./charontak-lanes.md).

!!! warning "Setting COT_URL per gateway bypasses Charontak"
    Overriding `COT_URL` on a gateway page routes *that* feeder around the hub. That is occasionally useful for debugging, but it means the feeder no longer benefits from Charontak's fan-out to Mesh SA and TAK Servers. Prefer configuring destinations as Charontak lanes.

## See also

- [Configuration model](../config/index.md) — the full inheritance picture
- [Site configuration](../config/site-config.md) — the keys every gateway inherits
- [Charontak lane editor](./charontak-lanes.md) — where upstream destinations live
- [Software suite](../reference/software-suite.md) — every gateway and what it does
