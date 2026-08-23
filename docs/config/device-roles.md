# Device roles

A **device role** selects which sensor pipelines run on an AryaOS unit - aircraft, vessels, drones, all of them, or none. Roles are runtime-selectable and persisted, so you can repurpose a box in the field without re-flashing. Set the role from the [Device role](../admin/aryaos-site.md#device-role) card or with the `aryaos-role` CLI helper.

## The CoT core is always on

Whatever role you choose, the **CoT core never stops**:

- `cotbridge` - the CoT hub / router
- `lincot` - this host's own beacon
- `gpscot` - network GPS to TAK clients
- `gpsd` - the GNSS receiver

Roles only toggle the **sensor** units on top of that core. This means a unit always beacons its position and routes CoT, even in the sensor-free `relay` role.

## The five roles

| Role | Purpose | Sensor units enabled |
|------|---------|----------------------|
| `multi` | All pipelines (default) | ADS-B + AIS + drones |
| `air` | Aircraft only (ADS-B 1090/978) | `<decoder>`, `dump978-fa`, `adsbcot`, `gdlcot` |
| `maritime` | Vessels only (AIS) | `ais-catcher`, `aiscot` |
| `cuas` | Counter-UAS (drones) | `dronecot-dji`, `sikw00fcot`, `sapientcot` |
| `relay` | CoT routing only | *(none)* |

`<decoder>` is the 1090 MHz decoder chosen by [`ARYAOS_ADSB_DECODER`](./site-config.md#ads-b-radios): `readsb` (default) or `dump1090-fa`.

The exact unit sets, from `aryaos-role`:

| Group | Units |
|-------|-------|
| ADS-B (`air`, `multi`) | `readsb` **or** `dump1090-fa`, `dump978-fa`, `adsbcot`, `gdlcot` |
| AIS (`maritime`, `multi`) | `ais-catcher`, `aiscot` |
| Drones / C-UAS (`cuas`, `multi`) | `dronecot-dji`, `sikw00fcot`, `sapientcot` |

!!! note "Units missing from your image are skipped"
    Applying a role enables the role's units and disables all other managed units. Missing optional units are skipped without error. The full managed set includes `readsb`, `dump1090-fa`, `dump978-fa`, `adsbcot`, `gdlcot`, `ais-catcher`, `aiscot`, the explicit `dronecot-*` instances, `sikw00fcot`, and `sapientcot`.

    `sapientcot` bridges a [SAPIENT (BSI Flex 335)](https://github.com/snstac/sapientcot) C-UAS sensor/fusion network into TAK. Point `SAPIENT_HOST`/`SAPIENT_PORT` in `/etc/default/sapientcot` at your SAPIENT node. It retries while the node is unreachable.

!!! tip "The unused ADS-B decoder is always disabled"
    Applying a role also disables whichever 1090 MHz decoder you are *not* using. That is why re-applying the role is the way to make a decoder change in the site config take effect - see [Radios & SDRs](./radios-sdr.md).

## How switching works

Applying a role does three things, in order:

1. **Enable and start** the role's sensor units (`systemctl enable --now`).
2. **Disable and stop** every other managed sensor unit (`systemctl disable --now`), so they do not come back at boot.
3. **Persist** the choice as `ARYAOS_ROLE` in `/etc/aryaos/aryaos-config.txt`.

Because the units are *disabled*, the role sticks across reboots.

=== "Web console"
    On the [AryaOS Site page](../admin/aryaos-site.md#device-role), choose a role from the **Role** drop-down. The card previews the exact units that will be enabled ("Sensor services for this role: ..."). Press **Apply role** and confirm - services outside the role are stopped and disabled.

=== "CLI"
    ```bash
    # See available roles, their units, and the current role (JSON)
    sudo aryaos-role list

    # Switch role
    sudo aryaos-role set air
    ```
    The helper prints each `enable`/`disable` action it takes. See [CLI helpers](../reference/cli-helpers.md).

!!! warning "Applying a role disables other sensors"
    Switching to `air` stops and disables the AIS and drone units; switching to `relay` stops **all** sensor units. This is intentional - pick the role that matches the mission. The CoT core keeps running regardless.

## Capability discovery

A box can work out what it is. `aryaos-capability-scan` probes the attached
hardware and maps it to capabilities:

```sh
sudo aryaos-role discover           # report what's present, change nothing
sudo aryaos-role discover --apply   # enable what the hardware supports
```

Example on a single-SDR node:

```
Detected hardware capabilities: adsb
  adsb      yes        1 SDR(s): LimeSDR Mini [USB 3.0] 1DBB4189078E3F
  ais       yes*       1 SDR(s) could run AIS
                       * shares a radio with 'adsb'; enable manually with
                         `aryaos-role caps ais` (or add a second receiver)
  wifi-rid  no         no external Wi-Fi adapter
  sapient   manual     network sensor - configure deliberately, never auto-detected
```

**This runs automatically once, at first boot.** The image ships every sensor
disabled, so a bare unit stays quiet while a kitted one comes up configured. The
marker `/etc/aryaos/.capabilities-autodetected` makes it a one-shot: a later
deliberate `aryaos-role caps ...` is never overwritten.

### What it will not guess

Auto-apply is deliberately conservative, because enabling the wrong thing is
worse than enabling nothing:

- **Contended radios.** One SDR cannot serve ADS-B *and* AIS at once, so only
  the higher-priority capability (`adsb`) is auto-enabled; the other is reported
  as available with the reason it was held back.
- **Generic serial adapters.** DroneScout receivers can appear as generic
  ESP32-S3 USB CDC (`303a:1001`) or behind a generic USB-UART bridge such as a
  PL2303. AryaOS validates complete MAVLink frames and requires `ADSB_VEHICLE`
  or `OPEN_DRONE_ID_MESSAGE_PACK`. A silent, stuck-low,
  busy, or unrelated MAVLink port is `AMBIGUOUS`, never auto-enabled.
- **Silent dAISy receivers.** A quiet AIS channel produces no NMEA evidence.
  AryaOS accepts one narrow hardware layout by elimination: one CH340 serial
  adapter beside a separately verified GPS, with no AntSDR present. This
  matches the AryaSea kit while avoiding the identical CH340 used for an
  AntSDR maintenance console. Any less specific layout remains unassigned.
- **Generic Raspberry Pi Picos.** ADSBee uses the stock Pico USB identity
  (`2e8a:000a`), so that identity alone is not sufficient. The scanner sends a
  read-only ADSBee bias-tee query and requires the device-specific response.
  `discover --apply` then selects readsb's `modesbeast` serial input and does not
  start the independent 978 MHz decoder.
- **SAPIENT.** A network sensor with no local hardware signature; never
  auto-detected.

### Beacons advertise availability

Each capability in the AryaOS beacon carries `active` (running now),
`enabled` (in the capability set) and `available` (hardware detected). A fleet
view can therefore spot a node with a Wi-Fi Remote ID adapter that is switched
off, or a service running that nobody declared.

## Persistence and precedence

- The current role lives in `ARYAOS_ROLE` in the site config. When unset, the effective role is `multi`.
- Editing `ARYAOS_ROLE` by hand does **not** change which units run - the enable/disable actions happen when you *apply* a role. Always apply through the card or `aryaos-role set` so systemd state and the config key stay in sync.

## See also

- [Multi-sensor COP](../deploy/multi-sensor.md) - running all pipelines at once
- [Relay & routing](../deploy/relay-routing.md) - the `relay` role in practice
- [Site configuration](./site-config.md) - `ARYAOS_ROLE` and the decoder key
- [Radios & SDRs](./radios-sdr.md) - decoder selection
