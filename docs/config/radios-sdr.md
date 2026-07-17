# Radios & SDRs

AryaOS uses software-defined radio (SDR) dongles to receive ADS-B (1090 MHz) and UAT (978 MHz) aircraft signals, and over-the-air AIS for vessels. Because a unit often has more than one dongle, AryaOS tells them apart by a stable **EEPROM serial** rather than USB port order. This page covers the serial convention, re-serializing a dongle, and choosing the 1090 MHz decoder.

## The serial convention

AryaOS selects dongles by a serial string written to each dongle's EEPROM:

| Serial | Band | Consumer |
|--------|------|----------|
| `stx:1090:0` | ADS-B 1090 MHz | `readsb` or `dump1090-fa` |
| `stx:978:0` | UAT 978 MHz | `dump978-fa` |

The UAT serial is the value of [`ARYAOS_UAT_RTL_SERIAL`](./site-config.md#ads-b-radios) in the site config (default `stx:978:0`).

!!! warning "The 1090 and UAT serials must differ"
    A 1090 MHz dongle and a 978 MHz dongle cannot share a serial. Pre-assembled AryaOS units ship with this factory pairing already written; Nooelec NESDR Nano 3 "978" sticks come pre-programmed as `stx:978:0`. If you build your own device or replace a dongle, write distinct serials before both bands will work.

## Enumerate and re-serialize dongles

You can list dongles and write new serials from the web console or the CLI.

=== "Radios card (recommended)"
    On the [AryaOS Site page](../admin/aryaos-site.md#radios-rtl-sdr), the **Radios (RTL-SDR)** card lists each detected dongle with its index, device string, and current serial. Type a new serial into the **New serial** field for a dongle and press **Write**; confirm the prompt. Use the refresh (↻) icon to rescan.

    Serials must be **1–32 characters** from `A-Z a-z 0-9 : . _ -`.

=== "CLI"
    ```bash
    # List detected dongles (JSON: index, vendor, product, serial)
    sudo aryaos-sdr list

    # Write a new serial to a dongle by index
    sudo aryaos-sdr set-serial 0 stx:1090:0
    ```
    Under the hood the helper enumerates with `rtl_test` and writes with `rtl_eeprom`. See [CLI helpers](../reference/cli-helpers.md).

!!! danger "Replug the dongle after writing a serial"
    Writing a serial **stops the SDR services** that were using the device (`readsb`, `dump1090-fa`, `dump978-fa`, `ais-catcher`), writes the EEPROM, then restarts the ones that were running. **The new serial is not visible until you physically replug the dongle (or reboot)**, then rescan. This is a hardware limitation of RTL-SDR EEPROM writes.

## Choosing the 1090 MHz decoder

AryaOS runs exactly **one** 1090 MHz decoder at a time:

- **readsb** (image default) — rebuilt with RTL-SDR, SoapySDR (Airspy and other Soapy devices), and native HackRF support.
- **dump1090-fa** (FlightAware) — RTL-SDR.

Both decoders write the same unified JSON feed at `/run/adsb/aircraft.json` (directory set by `ARYAOS_ADSB_JSON_DIR`), and `adsbcot` always reads that path. **You never change `adsbcot`'s feed when switching decoders.**

Selecting the decoder is a two-part operation today:

1. **Record the choice.** Set the **ADS-B decoder** drop-down on the [AryaOS Site page](../admin/aryaos-site.md#tak-destination) (writes `ARYAOS_ADSB_DECODER` = `readsb` or `dump1090_fa`).
2. **Switch the services.** Setting the key alone does not start or stop systemd units. **Re-apply the [device role](./device-roles.md)** — the role logic enables the selected decoder and disables the other.

=== "Via role re-apply (recommended)"
    After changing the decoder drop-down, open the [Device role](../admin/aryaos-site.md#device-role) card and press **Apply role** again. The role enables the chosen decoder and disables the unused one.

=== "Manual service switch"
    ```bash
    # Example: switch to dump1090-fa
    sudo systemctl disable --now readsb
    sudo systemctl enable --now dump1090-fa
    sudo systemctl restart adsbcot   # no FEED_URL change needed
    ```
    Reverse the steps to return to readsb.

## Multi-SDR setups

A common AryaOS build carries two dongles — one at `stx:1090:0` for ADS-B and one at `stx:978:0` for UAT — plus optionally an AIS receiver. The serial pairing is what lets `readsb`/`dump1090-fa` and `dump978-fa` each claim the correct hardware regardless of USB order. When you add or swap a dongle:

1. `aryaos-sdr list` (or the Radios card) to find its current serial and index.
2. Write the band-appropriate serial (`stx:1090:0` or `stx:978:0`), keeping the two bands distinct.
3. Replug or reboot, then rescan.

The [landing portal](../portal.md) and the portal's **Radios / RF** panel show a live inventory of Wi-Fi, Bluetooth, and USB SDR hardware plus decoder service state, which is handy for confirming a dongle is seen.

## Gain, PPM, and other tuning

Fine-tuning such as gain and frequency correction (PPM) is **not** exposed in the Radios card today — that card manages serials only. These live in the decoder's own config file:

- **readsb** — `/etc/default/readsb` (`RECEIVER_OPTIONS`, `DECODER_OPTIONS`)
- **dump1090-fa** — `/etc/default/dump1090-fa`
- **dump978-fa** — `/etc/default/dump978-fa`

Edit them with Cockpit's file editor or over SSH, then `sudo systemctl restart <decoder>`. Because `readsb` is `apt-mark hold` on the image, updates will not silently overwrite a tuned decoder.

!!! note "On current images"
    Serial management is in the Radios card; gain/PPM and SoapySDR/HackRF/Airspy backends are configured in the decoder's `/etc/default/<decoder>` file. See the [ADS-B deployment guide](../deploy/air-adsb.md) for antenna and receiver guidance.

## See also

- [Site configuration](./site-config.md) — `ARYAOS_ADSB_DECODER`, `ARYAOS_UAT_RTL_SERIAL`, `ARYAOS_ADSB_JSON_DIR`
- [Device roles](./device-roles.md) — how a role apply switches decoders
- [Aircraft (ADS-B)](../deploy/air-adsb.md) — deploying the aircraft pipeline
- [CLI helpers](../reference/cli-helpers.md) — `aryaos-sdr`
