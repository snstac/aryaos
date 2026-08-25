# Own position & GPS

Put the AryaOS box itself on the map. Share its GPS with your TAK client. This works in **every** role. The position core always runs. So your sensor gateway is also a self-locating node.

AryaOS uses two cooperating tools for position:

- **LINCOT** beacons the *host's own position* to TAK as a CoT marker, so the box shows up on the map like any other unit.
- **GPSCOT** streams `gpsd` position data to the network as CoT and fans out NMEA for WinTAK. Giving a connected phone or laptop a GPS fix even when it has no receiver of its own.

Both feed from **`gpsd`**, which reads a connected GNSS receiver.

!!! note "Always on"
    `cotbridge`, `lincot`, `gpscot`, and `gpsd` are part of the CoT core. They run in every
    [device role](../config/device-roles.md), including `relay`. You do not need a special role to
    share position.

## Hardware

| Part | Notes |
|------|-------|
| USB or UART GNSS receiver | Any `gpsd`-supported GPS/GNSS puck. Give it a clear view of the sky. |
| (Optional) none | If you have no receiver, use a static fallback position (below). |

## How position flows

```mermaid
flowchart LR
    G[GNSS receiver] --> D[gpsd]
    D --> L[LINCOT<br/>host beacon]
    D --> T[GPSCOT<br/>network GPS + NMEA]
    L -->|CoT| H[COTBridge hub]
    T -->|CoT / NMEA| E[ATAK / WinTAK]
    H -->|Mesh SA 239.2.3.1:6969| E
```

- **LINCOT > COTBridge > Mesh SA:** the box appears as a self-marker on every connected EUD.
- **GPSCOT > EUD:** a phone or WinTAK laptop on the AryaOS network uses the box's GPS as its own position source.

## Share the box's position with TAK

The common case needs no configuration. Connect a GNSS receiver and connect your EUD to the AryaOS
hotspot. The box's marker appears through Mesh SA.

To confirm the pipeline:

```bash
systemctl status gpsd lincot gpscot
gpspipe -w -n 5        # raw gpsd JSON - check for TPV with lat/lon
```

!!! tip "Identity on the map"
    The box's marker uses `COT_HOST_ID` (set on first boot to `aryaos-<suffix>`) as its source identity. Override `COT_HOST_ID` in the site config to give a unit a mission-specific callsign.

## Give your EUD a network GPS fix

When your phone or WinTAK machine has no GPS (or a poor one indoors/in a vehicle), point it at GPSCOT:

=== "WinTAK"

    GPSCOT fans out NMEA that WinTAK can consume as an external GPS source. Thus, a laptop with no receiver gets a live fix from the box.

=== "ATAK"

    ATAK can take its position from the network via CoT/GPSCOT when running on a device without its own reliable fix.

See the [GPSCOT](https://github.com/snstac/gpscot) project for client-side setup details. GPS integrity (spoof/jam) can be monitored from the **cockpit-gps** plugin.

## Static position fallback

Set a static position when the box has no GNSS receiver or serves as a fixed site.
LINCOT supports fixed latitude and longitude values. Configure them in the LINCOT Cockpit plugin,
which edits `/etc/default/lincot`.

!!! info "Wildland fire & SAR"
    A self-locating gateway shows each sensor node in the incident COP. This works when the connected EUD is offline.

## Related

- [Offline backpack](./offline-backpack.md) - position sharing over a disconnected hotspot.
- [ForeFlight / GDL90](./foreflight-gdl90.md) - use this device's position as GDL90 ownship.
- [Device roles](../config/device-roles.md) · [Glossary](../reference/glossary.md)
