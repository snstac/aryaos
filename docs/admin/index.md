# The web console

AryaOS is administered entirely from a web browser. There is no need to open an SSH session for normal setup and operation: everything a field operator or TAK admin needs — TAK destinations, sensor roles, radios, updates, VPN, and support bundles — lives in a point-and-click console served by the device itself.

!!! tip "No SSH required"
    AryaOS follows a **no-SSH philosophy**: the console covers day-to-day administration so you can field, configure, and troubleshoot a unit from a phone or laptop without a terminal. SSH remains available on the image for advanced recovery, but you should not need it for anything on the pages that follow.

## How to reach it

Every AryaOS device runs [Cockpit](https://cockpit-project.org/), a web-based system management console, on HTTPS. It is exposed two ways:

| Address | Serves | Notes |
|---------|--------|-------|
| `https://aryaos-xxxx.local:9090/` | Cockpit directly | Cockpit's own port |
| `https://aryaos-xxxx.local/admin/` | Cockpit via lighttpd | `lighttpd` on `:443` proxies `/admin` → Cockpit |
| `https://aryaos-xxxx.local/` | Landing portal | Read-only live status page |

Replace `xxxx` with your device's four-character suffix — the same hex characters that appear in the hostname `aryaos-xxxx` and the onboarding Wi-Fi SSID `AryaOS-xxxx`. Before first-boot personalization the factory hostname is simply `aryaos` (`https://aryaos.local/`).

=== "On the onboarding hotspot"
    When no known Wi-Fi is in range, the device broadcasts its `AryaOS-xxxx` hotspot. Join it, then browse to `https://aryaos-xxxx.local/admin/`. See [Wi-Fi & onboarding hotspot](../networking/wifi-hotspot.md).

=== "On your LAN"
    Once the device has joined your network, reach it at the same `aryaos-xxxx.local` name (mDNS/Bonjour) or by its IP address from the landing portal.

=== "Over VPN"
    If the unit is joined to your Tailscale tailnet, use its tailnet name or IP. See [VPN (Tailscale)](../networking/vpn-tailscale.md).

!!! warning "Self-signed certificate"
    Each AryaOS unit generates its own per-device web TLS certificate at first boot, so your browser will warn that the connection is not trusted the first time you connect. This is expected. Confirm the exception to continue. The certificate protects the session between your browser and *this* device.

### Logging in

Log in as the **`pi`** user with the device password.

!!! danger "The default password expires at first login"
    Release images ship with a well-known default `pi` password that is **expired at first login** — you will be forced to set a new one. Choose a strong password and record it: there is no password-recovery feature. See [Security posture](../security.md).

## The landing portal

Browsing to `https://aryaos-xxxx.local/` (no `/admin`) shows the **landing portal** — a lightweight, read-only status page served by `lighttpd`, independent of Cockpit and Node-RED. It is the fastest way to confirm a unit is healthy before you dig into administration.

The portal polls a JSON status endpoint (`/cgi-bin/aryaos-portal-status`) every 8 seconds and shows:

- **TAK gateway strip** — live up/down/degraded state of `charontak`, `adsbcot`, `aiscot`, `lincot`, `dronecot`, and `sikw00fcot`.
- **System health** — CPU temperature, load average, memory, and Raspberry Pi power/throttle state.
- **Connection & status** — hostname, FQDN, primary IP, the full IPv4 address block, and uptime.
- **GNSS** — the gpsd position fix: latitude/longitude, MSL and HAE altitude, CE/LE accuracy, Maidenhead grid, and satellites in view/used.
- **Radios / RF** — an inventory of Wi-Fi, Bluetooth, and USB SDR hardware plus decoder service state.

The portal is for reading; all **writes** happen in Cockpit (and, for Wi-Fi onboarding, Comitup). See [HTTPS landing portal](../portal.md) for the full status schema.

## Map of the admin surfaces

Cockpit's left-hand menu lists standard system pages (Overview, Logs, Storage, Networking, Software Updates, Accounts, Services, Terminal) plus the AryaOS-specific plugins installed from the signed snstac package repository. The pages below are the ones you will use most:

<div class="grid cards" markdown>

- :material-tune-vertical: **AryaOS Site** — The flagship page. TAK destination, site-wide TLS, TAK Server enrollment, device role, radios, updates, VPN, support bundles, and more, all writing the shared [site configuration](../config/site-config.md). [Open the reference](./aryaos-site.md)

- :material-transit-connection-variant: **Charontak lane editor** — The CoT router. Define the ingress/egress lanes that carry Cursor on Target (CoT) from local feeders out to Mesh SA and TAK Servers. [Edit lanes](./charontak-lanes.md)

- :material-cog-transfer: **Gateway pages** — One Cockpit plugin per sensor gateway (adsbcot, aiscot, dronecot, lincot, gps, gpstak, aiscatcher). Per-service tuning, service controls, TLS, and logs. [See the pattern](./gateways.md)

- :material-map-marker-radius: **Node-RED dashboard** — Maps, TFR injection, and optional recording. Deprecated for configuration. [Node-RED](../node-red.md)

</div>

### Where each thing is configured

If you are not sure which surface owns a setting, start with the [configuration model](../config/index.md), which explains the inheritance from the site config down to each `/etc/default/<svc>` file.

<div class="grid cards" markdown>

- :material-file-cog: **Site configuration** — The keys in `/etc/aryaos/aryaos-config.txt` inherited by every gateway. [Reference](../config/site-config.md)

- :material-account-switch: **Device roles** — Which sensor pipelines run on this unit. [Roles](../config/device-roles.md)

- :material-radio-tower: **Radios & SDRs** — RTL-SDR serial conventions and decoder selection. [Radios](../config/radios-sdr.md)

</div>

!!! info "Getting here for the first time"
    If you have not yet flashed and booted a device, start with the [Quickstart](../get-started/quickstart.md). To point the unit at a TAK Server, see [Connect to a TAK Server](../deploy/connect-tak-server.md).
