# Software suite

AryaOS ships the full [Sensors & Signals](https://www.snstac.com) open-source suite of Team Awareness Kit (TAK) gateways and Cursor on Target (CoT) tools, plus a touch-friendly [Cockpit](https://cockpit-project.org/) web plugin for each one. Every gateway is built on [PyTAK](#pytak) and, on AryaOS, feeds the [CharonTAK](#charontak) hub, which owns egress to Mesh SA and any TAK Servers.

!!! info "How the pieces fit together"
    Local feeders (adsbcot, aiscot, dronecot, lincot, gdltak, gpstak) send CoT to CharonTAK at `udp+wo://127.0.0.1:28087`. CharonTAK listens on `udp+ro://127.0.0.1:28087` and forwards to the default Mesh SA multicast `udp+wo://239.2.3.1:6969` plus optional TAK Server lanes. See [Ports & protocols](ports.md) and [Relay & routing](../deploy/relay-routing.md).

## Foundation

| Project | What it does |
|---|---|
| [PyTAK](https://github.com/snstac/pytak) {#pytak} | Python framework for building TAK and Cursor on Target (CoT) integrations. Every gateway below is built on it. ([docs](https://pytak.readthedocs.io/)) |
| [CharonTAK](https://github.com/snstac/charontak) {#charontak} | The CoT "ferryman" — bridges and routes CoT between the local hub, Mesh SA multicast, and TAK Servers. On AryaOS it is the single egress point every feeder writes to. |

## Air — aircraft

<div class="grid cards" markdown>

- :material-airplane: **[ADSBCOT](https://github.com/snstac/adsbcot)** — Displays live aircraft from ADS-B receivers in ATAK, WinTAK, and iTAK. ([docs](https://adsbcot.readthedocs.io/)) · Deploy: [Aircraft (ADS-B)](../deploy/air-adsb.md)
- :material-shape: **[AIRCOT](https://github.com/snstac/aircot)** — Classifies aircraft into TAK/CoT types from ADS-B and Mode S data. ([docs](https://aircot.readthedocs.io/))
- :material-satellite-uplink: **[APRSCOT](https://github.com/snstac/aprscot)** — Displays amateur-radio APRS stations in TAK. ([docs](https://aprscot.readthedocs.io/))
- :material-satellite-variant: **[INRCOT](https://github.com/snstac/inrcot)** — Displays Garmin inReach satellite-tracker positions in TAK.

</div>

## Maritime — vessels

<div class="grid cards" markdown>

- :material-ferry: **[AISCOT](https://github.com/snstac/aiscot)** — Displays ships and maritime vessel traffic from AIS in TAK. ([docs](https://aiscot.readthedocs.io/)) · Deploy: [Maritime vessels (AIS)](../deploy/maritime-ais.md)

</div>

## Drone — counter-UAS

<div class="grid cards" markdown>

- :material-quadcopter: **[DroneCOT](https://github.com/snstac/dronecot)** — Detects and tracks drones (Remote ID / Open Drone ID) in TAK for counter-UAS awareness.
- :material-drone: **[DJICOT](https://github.com/snstac/djicot)** — Detects and tracks DJI drones (DroneID) in TAK. ([docs](https://djicot.readthedocs.io/))
- :material-radio-tower: **[SiKW00FCOT](https://github.com/snstac/sikw00fcot)** — Converts SiK-radio MAVLink drone telemetry to Cursor on Target.

</div>

Deploy: [Counter-UAS (drones)](../deploy/counter-uas.md).

## Position — own location

<div class="grid cards" markdown>

- :material-crosshairs-gps: **[GPSTAK](https://github.com/snstac/gpstak)** — Streams `gpsd` position data to TAK as CoT, with NMEA fan-out for WinTAK.
- :material-map-marker: **[LINCOT](https://github.com/snstac/lincot)** — Sends a Linux device's own position (GPS) to TAK.

</div>

Deploy: [Own position (GPS)](../deploy/own-position-gps.md).

## Routing — bridge & relay

<div class="grid cards" markdown>

- :material-transit-connection-variant: **[CharonTAK](https://github.com/snstac/charontak)** — Bridges and relays CoT between networks and TAK Servers; the AryaOS egress hub. Deploy: [Relay & routing](../deploy/relay-routing.md)

</div>

## EFB — electronic flight bag

<div class="grid cards" markdown>

- :material-airplane-takeoff: **[GDLTAK](https://github.com/snstac/gdltak)** — Converts CoT into GDL90 so aircraft tracks appear in ForeFlight and other electronic flight bags (EFBs). Deploy: [ForeFlight & EFBs (GDL90)](../deploy/foreflight-gdl90.md)

</div>

## Onboarding

<div class="grid cards" markdown>

- :material-qrcode: **[QRTAK](https://github.com/snstac/qrtak)** — Onboard end-user devices to a TAK Server by scanning a QR code. See [Connect to a TAK Server](../deploy/connect-tak-server.md).

</div>

## Web admin — Cockpit plugins

Every gateway on AryaOS is managed from a browser UI built on [Cockpit](https://cockpit-project.org/) (HTTPS on port 9090, also reachable via the portal proxy). Each plugin edits its service's `/etc/default/<svc>`; the **AryaOS Site** plugin edits the site config and TAK TLS.

| Plugin | Manages |
|---|---|
| [cockpit-aryaos](https://github.com/snstac/cockpit-aryaos) | The AryaOS Site page: TAK destination, site TAK TLS, device role, radios, updates, support bundles, Node-RED password, VPN, nearby nodes |
| [cockpit-adsbcot](https://github.com/snstac/cockpit-adsbcot) | ADSBCOT (aircraft) |
| [cockpit-aiscot](https://github.com/snstac/cockpit-aiscot) | AISCOT (vessels) |
| [cockpit-dronecot](https://github.com/snstac/cockpit-dronecot) | DroneCOT (drones) |
| [cockpit-lincot](https://github.com/snstac/cockpit-lincot) | LINCOT (host position) |
| [cockpit-gps](https://github.com/snstac/cockpit-gps) | GPS / `gpsd` |
| [cockpit-gpstak](https://github.com/snstac/cockpit-gpstak) | GPSTAK (network GPS) |
| [cockpit-charontak](https://github.com/snstac/cockpit-charontak) | CharonTAK lane editor (routing) |
| [cockpit-aiscatcher](https://github.com/snstac/cockpit-aiscatcher) | AIS-catcher decoder |

All plugins share the [@snstac/cockpit-shared](https://github.com/snstac/cockpit-shared) component library for a consistent, glove-friendly UI.

## See also

<div class="grid cards" markdown>

- :material-book-open: **Glossary** — Definitions of every term above. [Glossary](glossary.md)
- :material-console: **CLI helpers** — The `aryaos-*` commands behind the web cards. [CLI helpers](cli-helpers.md)
- :material-view-dashboard: **AryaOS Site page** — The single admin surface. [AryaOS Site page](../admin/aryaos-site.md)

</div>
