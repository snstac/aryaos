# Device roles

A **device role** selects which sensor pipelines run on an AryaOS unit — aircraft, vessels, drones, all of them, or none. Roles are runtime-selectable and persisted, so you can repurpose a box in the field without re-flashing. Set the role from the [Device role](../admin/aryaos-site.md#device-role) card or with the `aryaos-role` CLI helper.

## The CoT core is always on

Whatever role you choose, the **CoT core never stops**:

- `charontak` — the CoT hub / router
- `lincot` — this host's own beacon
- `gpstak` — network GPS to TAK clients
- `gpsd` — the GNSS receiver

Roles only toggle the **sensor** units on top of that core. This means a unit always beacons its position and routes CoT, even in the sensor-free `relay` role.

## The five roles

| Role | Purpose | Sensor units enabled |
|------|---------|----------------------|
| `multi` | All pipelines (default) | ADS-B + AIS + drones |
| `air` | Aircraft only (ADS-B 1090/978) | `<decoder>`, `dump978-fa`, `adsbcot`, `gdltak` |
| `maritime` | Vessels only (AIS) | `ais-catcher`, `aiscot` |
| `cuas` | Counter-UAS (drones) | `dronecot`, `sikw00fcot` |
| `relay` | CoT routing only | *(none)* |

`<decoder>` is the 1090 MHz decoder chosen by [`ARYAOS_ADSB_DECODER`](./site-config.md#ads-b-radios): `readsb` (default) or `dump1090-fa`.

The exact unit sets, from `aryaos-role`:

| Group | Units |
|-------|-------|
| ADS-B (`air`, `multi`) | `readsb` **or** `dump1090-fa`, `dump978-fa`, `adsbcot`, `gdltak` |
| AIS (`maritime`, `multi`) | `ais-catcher`, `aiscot` |
| Drones (`cuas`, `multi`) | `dronecot`, `sikw00fcot` |

!!! note "Units missing from your image are skipped"
    Applying a role enables the role's units and disables all other managed units. Optional units that are not installed on your image (for example a decoder you did not build) are simply skipped — not errors. The full managed set the helper touches is: `readsb`, `dump1090-fa`, `dump978-fa`, `adsbcot`, `gdltak`, `ais-catcher`, `aiscot`, `dronecot`, `sikw00fcot`.

!!! tip "The unused ADS-B decoder is always disabled"
    Applying a role also disables whichever 1090 MHz decoder you are *not* using. That is why re-applying the role is the way to make a decoder change in the site config take effect — see [Radios & SDRs](./radios-sdr.md).

## How switching works

Applying a role does three things, in order:

1. **Enable and start** the role's sensor units (`systemctl enable --now`).
2. **Disable and stop** every other managed sensor unit (`systemctl disable --now`), so they do not come back at boot.
3. **Persist** the choice as `ARYAOS_ROLE` in `/etc/aryaos/aryaos-config.txt`.

Because the units are *disabled*, the role sticks across reboots.

=== "Web console"
    On the [AryaOS Site page](../admin/aryaos-site.md#device-role), choose a role from the **Role** drop-down. The card previews the exact units that will be enabled ("Sensor services for this role: …"). Press **Apply role** and confirm — services outside the role are stopped and disabled.

=== "CLI"
    ```bash
    # See available roles, their units, and the current role (JSON)
    sudo aryaos-role list

    # Switch role
    sudo aryaos-role set air
    ```
    The helper prints each `enable`/`disable` action it takes. See [CLI helpers](../reference/cli-helpers.md).

!!! warning "Applying a role disables other sensors"
    Switching to `air` stops and disables the AIS and drone units; switching to `relay` stops **all** sensor units. This is intentional — pick the role that matches the mission. The CoT core keeps running regardless.

## Persistence and precedence

- The current role lives in `ARYAOS_ROLE` in the site config. When unset, the effective role is `multi`.
- Editing `ARYAOS_ROLE` by hand does **not** change which units run — the enable/disable actions happen when you *apply* a role. Always apply through the card or `aryaos-role set` so systemd state and the config key stay in sync.

## See also

- [Multi-sensor COP](../deploy/multi-sensor.md) — running all pipelines at once
- [Relay & routing](../deploy/relay-routing.md) — the `relay` role in practice
- [Site configuration](./site-config.md) — `ARYAOS_ROLE` and the decoder key
- [Radios & SDRs](./radios-sdr.md) — decoder selection
