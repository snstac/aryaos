# Troubleshooting

Symptom-to-fix checks for the problems you are most likely to hit in the field. Each section lists the likely cause and the concrete thing to check — most from the web admin, no shell required.

!!! tip "Two tools solve most cases"
    - **Sensor services card** (Cockpit → AryaOS Site) shows at a glance which gateways are running.
    - **Support bundle** (Cockpit → AryaOS Site → Support bundle, or `sudo aryaos-support-bundle`) captures redacted logs, service status, and config for support. See [Support bundles](operations/support-bundles.md).

## No tracks in TAK

Aircraft, vessels, or drones are not appearing on the TAK map.

!!! warning "Most common cause: the TAK client is not on Mesh SA"
    AryaOS sends tracks to the **Mesh SA** multicast group `239.2.3.1:6969` by default. Your ATAK/WinTAK/iTAK device must be joined to the AryaOS hotspot **and** have Mesh SA enabled to receive them.

Check, in order:

1. **Is the TAK client on the right network?** Confirm the phone/laptop is joined to `AryaOS-xxxx`, not another Wi-Fi.
2. **Is Mesh SA enabled in the TAK client?** In ATAK, enable the Mesh SA / multicast input.
3. **Is the sensor running?** Open the **Sensor services** card. The relevant gateway (`adsbcot`, `aiscot`, `dronecot`) should be active.
4. **Is the right role selected?** The [device role](config/device-roles.md) must include your sensor — e.g. `air` or `multi` for aircraft. Set it in the **Device role** card.
5. **Is the radio decoding?** For ADS-B, the aircraft feed lives at `/run/adsb/aircraft.json`; if it is empty, the SDR or antenna is the problem (see [SDR not detected](#sdr-not-detected)).

See [Aircraft (ADS-B)](deploy/air-adsb.md), [Maritime (AIS)](deploy/maritime-ais.md), [Counter-UAS](deploy/counter-uas.md).

## Can't reach the web console

`https://aryaos-xxxx.local` or `10.41.0.1` will not load.

1. **Give first boot time.** A new device needs ~120 seconds before the hotspot and web console come up.
2. **Are you on the hotspot?** Join `AryaOS-xxxx` first.
3. **Try the IP.** If `aryaos-xxxx.local` fails (mDNS resolver issue), use `https://10.41.0.1`.
4. **Accept the certificate.** The per-device certificate is self-signed; the browser warning is expected — proceed. See [Security posture](security.md).
5. **Try the direct Cockpit port.** The portal proxies 443 → Cockpit; you can also reach Cockpit directly on `https://<host>:9090`.
6. **Firewall.** If you changed the firewall, confirm Cockpit/portal are still allowed in [Firewall](networking/firewall.md).

## No Wi-Fi hotspot

The `AryaOS-xxxx` network never appears.

1. **Wait out first boot** (~120 s on a new device).
2. **Confirm the suffix.** The SSID is `AryaOS-xxxx` where `xxxx` matches the hostname; look carefully — it may not be the name you expect. See [`DEVICE_SUFFIX`](reference/glossary.md#device_suffix).
3. **Already joined to another Wi-Fi?** comitup runs the hotspot only when not connected as a client. If the box joined a known network, the AP may be down by design. See [Wi-Fi & onboarding hotspot](networking/wifi-hotspot.md).
4. **Reach it another way.** Connect over Ethernet or the [Bluetooth PAN](bluetooth-pan.md) to investigate.

## SDR not detected {#sdr-not-detected}

A radio is plugged in but the decoder sees nothing.

1. **List the dongles.** In **Radios** (or `sudo aryaos-sdr list`) confirm the dongle enumerates.
2. **Check the serial.** Each SDR needs a unique serial: `stx:1090:0` for ADS-B, `stx:978:0` for UAT. Two dongles with the same serial collide. Fix with **Radios** or [`aryaos-sdr set-serial`](reference/cli-helpers.md#aryaos-sdr), then **replug or reboot**.
3. **Power.** Multiple SDRs can exceed the Pi's USB budget — use a powered hub and a stronger power supply. See [Hardware & requirements](get-started/hardware.md).
4. **Antenna.** No detections despite a working dongle usually means an antenna/placement problem — check the connector and line of sight.

## Box keeps rebooting, or all sensors are stopped (safe mode) {#safe-mode}

If the box reboots in a loop, or comes up with every sensor stopped and USB peripherals dead, it has almost certainly **browned out under load on an under-spec'd power supply** — and AryaOS has latched **safe mode** to keep it reachable instead of crash-looping.

1. **Confirm.** Run `aryaos-safe-mode status`, or look for the red banner on the **AryaOS Site** Cockpit page. `safe-mode: ON` with a `crash-loop` reason means it tripped after 3 consecutive short boots.
2. **Fix the power** — nearly always the cause. See [Power & battery](get-started/hardware.md#power--battery-for-backpack-ops): a Pi 5 needs a **5V/5A (27&nbsp;W)** supply; a big GaN charger that only does 5V/3A, or a PoE HAT on plain 802.3af, will not sustain it.
3. **Restore.** On a good supply, clear safe mode from **Cockpit → AryaOS Site → Safe mode** ("Restore now" or "Restore &amp; reboot"), or `sudo aryaos-safe-mode off` — this re-powers USB and restarts the sensors.
4. **Check under-voltage** any time with `vcgencmd get_throttled` (`0x0` is clean); the AryaOS Site page also shows this as a live power-health warning.

## A service won't start

A gateway shows as failed or keeps restarting.

1. **Sensor services card** — identify which unit is down.
2. **Read the logs.** The support bundle includes each service's recent journal. Generate one from **Support bundle** (or `sudo aryaos-support-bundle`), which redacts secrets automatically. See [Support bundles](operations/support-bundles.md).
3. **Check the role.** A unit disabled by the current [device role](config/device-roles.md) is expected to be stopped — that is not a failure. Switch roles in **Device role** if you need it running.
4. **From a shell** (optional): `systemctl status <unit>` and `journalctl -u <unit>` show the failure reason.

## TAK Server won't connect

Tracks reach Mesh SA but not your TAK Server.

1. **Re-import the connection.** Import the TAK **data package** or `tak://` enrollment link again from the **TAK connection** card. AryaOS installs the certs and writes a CharonTAK lane. See [Connect to a TAK Server](deploy/connect-tak-server.md).
2. **Certificate/CA.** A bad or expired client certificate, or the wrong CA in the package, stops the TLS handshake — get a fresh package from your TAK admin.
3. **Reachability.** The device must be able to reach the server host and port (the connect string in the package). On a disconnected box, add a route: Ethernet, an upstream Wi-Fi client connection, or the [VPN](networking/vpn-tailscale.md).
4. **CharonTAK lane.** Confirm the `lane:local-to-takserver` lane is enabled in the [Charontak lane editor](admin/charontak-lanes.md).

## GPS has no fix

The device's own position is missing or wrong.

1. **Is the puck detected?** GPS uses `gpsd`; confirm the USB GNSS receiver is recognized (the support bundle captures a `gpsd` snapshot).
2. **Sky view.** GNSS needs a clear view of the sky; a cold start can take minutes indoors or under cover.
3. **Is the position gateway running?** `gpstak`/`lincot` publish position; both are part of the always-on CoT core. Check the **Sensor services** card. See [Own position (GPS)](deploy/own-position-gps.md).

## Still stuck?

<div class="grid cards" markdown>

- :material-archive: **Support bundle** — Redacted diagnostics for support. [Support bundles](operations/support-bundles.md)
- :material-frequently-asked-questions: **FAQ** — Quick answers. [FAQ](help/faq.md)
- :material-github: **Report an issue** — [github.com/snstac/aryaos](https://github.com/snstac/aryaos/issues)

</div>
