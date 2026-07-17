# Hardware & requirements

Everything you need to build or buy an AryaOS gateway. This page covers the single-board computer, storage, radios, antennas, GPS, and power for backpack operations — plus the pre-assembled [AirTAK go-kit](../purchase.md) if you would rather skip the shopping list.

!!! tip "Just want it to work?"
    Order an assembled and tested [AirTAK go-kit](../purchase.md). It ships with a Raspberry Pi, the right radios and antennas, GPS, and a field enclosure, all pre-flashed with AryaOS. The rest of this page is for teams building their own.

## What each mission needs

AryaOS runs the same image everywhere; a mission's needs come down to which radios and antennas you attach and which [device role](../config/device-roles.md) you select. Use this table to plan a build.

| Mission | Deploy guide | Radio | Antenna | GPS | Device role |
|---|---|---|---|---|---|
| Aircraft (ADS-B 1090 MHz) | [Aircraft (ADS-B)](../deploy/air-adsb.md) | RTL-SDR | 1090 MHz ADS-B | Optional | `air` |
| Aircraft (UAT 978 MHz, US) | [Aircraft (ADS-B)](../deploy/air-adsb.md) | Second RTL-SDR | 978 MHz (or wideband ADS-B) | Optional | `air` |
| Maritime vessels (AIS) | [Maritime vessels (AIS)](../deploy/maritime-ais.md) | RTL-SDR | VHF marine (161–162 MHz) | Optional | `maritime` |
| Drones (Remote ID / DroneID) | [Counter-UAS (drones)](../deploy/counter-uas.md) | AntSDR (or Wi-Fi/BT sniffer) | 2.4/5.8 GHz per hardware | Optional | `cuas` |
| Own position on the map | [Own position (GPS)](../deploy/own-position-gps.md) | — | — | USB GNSS puck | any |
| Everything at once | [Multi-sensor COP](../deploy/multi-sensor.md) | Multiple SDRs | Per band above | USB GNSS puck | `multi` |
| CoT relay / routing only | [Relay & routing](../deploy/relay-routing.md) | — | — | Optional | `relay` |

!!! info "One SDR per band"
    Each radio decodes one band at a time. To watch 1090 MHz and 978 MHz simultaneously (or add AIS), fit one RTL-SDR per band and give each a unique serial — see [Re-serializing radios](#re-serializing-radios).

## Single-board computer

AryaOS is a Debian trixie–based, `arm64` operating system built with pi-gen. It targets the Raspberry Pi and is tested on the following models.

| Model | Architecture | Status | Notes |
|---|---|---|---|
| Raspberry Pi 5 | `arm64` | Recommended | Fastest; best headroom for multi-sensor builds |
| Raspberry Pi 4 | `arm64` | Supported & tested | The most common field build |
| Raspberry Pi 3 | `arm64` | Supported & tested | Works for single-sensor loadouts |

!!! note "Intel/amd64 is planned, not shipping yet"
    AryaOS images are `arm64` only today ([#129](https://github.com/snstac/aryaos/issues/129)). The full gateway suite already installs on any Debian host from the [signed apt repository](https://snstac.github.io/packages), so you can run the software on `amd64` even before a dedicated image exists.

## microSD card

You write the AryaOS image to a microSD card and boot from it.

| Spec | Requirement |
|---|---|
| Minimum capacity | 16 GB |
| Recommended capacity | 32 GB |
| Class | A1/A2 application-class recommended for responsiveness |

The image resizes its filesystem to fill the card on [first boot](first-boot.md), so a larger card gives you room for logs, support bundles, and Node-RED flows without any manual steps.

## Radios (SDR dongles)

AryaOS decodes signals with software-defined radio (SDR) dongles on USB.

=== "ADS-B / UAT / AIS"

    **RTL-SDR** dongles (RTL2832U) cover the three most common bands:

    | Band | Frequency | Decoder | AryaOS serial convention |
    |---|---|---|---|
    | ADS-B | 1090 MHz | `readsb` / `dump1090-fa` | `stx:1090:0` |
    | UAT (US) | 978 MHz | `dump978-fa` | `stx:978:0` |
    | AIS | 161–162 MHz (VHF) | `ais-catcher` | assign a distinct serial |

    A blog-favorite is the Nooelec NESDR series; the factory UAT preset on AryaOS matches the NESDR Nano 3 "978" EEPROM serial `stx:978:0`.

=== "Drones (Remote ID / DroneID)"

    Drone detection uses a wider-band radio such as the **AntSDR** to capture DJI DroneID and other Remote ID signals, feeding [DroneCOT](../reference/software-suite.md) and DJICOT. See [Counter-UAS (drones)](../deploy/counter-uas.md) for the supported capture hardware and setup.

!!! warning "Give each dongle a unique serial"
    AryaOS tells the ADS-B, UAT, and AIS decoders apart by USB serial (`stx:1090:0`, `stx:978:0`, and so on). If you install two identical dongles with the same factory serial, decoders will fight over the same device. Re-serialize before deploying.

### Re-serializing radios

Set serials from **Cockpit → AryaOS Site → Radios**, or from a shell with [`aryaos-sdr`](../reference/cli-helpers.md):

```bash
sudo aryaos-sdr list
sudo aryaos-sdr set-serial 0 stx:1090:0
```

Replug the dongle (or reboot) for the new serial to take effect. See [Radios & SDRs](../config/radios-sdr.md) for the full workflow.

## Antennas

The right antenna does more for range than anything else in the kit.

| Band | Antenna | Notes |
|---|---|---|
| ADS-B 1090 MHz | Tuned 1090 MHz ADS-B antenna | A tuned whip or collinear outperforms the bundled telescopic; height and line of sight matter most |
| UAT 978 MHz | 978 MHz or wideband ADS-B antenna | US-only band; a wideband ADS-B antenna covers both 978 and 1090 acceptably |
| AIS (VHF) | Marine VHF antenna (161–162 MHz) | A proper VHF marine antenna dramatically improves vessel range |

!!! example "Range in the field"
    In a San Diego backpack test with no internet, a tuned ADS-B setup reached **55 miles** of aircraft coverage. See [Introduction](overview.md) for the full CONOP.

## GPS / GNSS

A USB GNSS puck gives the gateway its own position, which AryaOS publishes to TAK via [GPSTAK and LINCOT](../reference/software-suite.md) — useful for backpack and vehicle operations where the box is on the move.

- Any `gpsd`-compatible USB GNSS receiver works (the popular u-blox 7/8-class pucks are common choices).
- GPS is optional for fixed-site installs but recommended for mobile and dismounted use.
- See [Own position (GPS)](../deploy/own-position-gps.md) to put the gateway on the map.

## Power & battery for backpack ops

AryaOS is designed for disconnected, dismounted use — no LTE, no Wi-Fi backhaul required.

- Power the Pi from a good-quality USB power bank; use one that meets the Pi model's current draw (a Pi 4/5 wants a solid 5V/3A source).
- SDRs draw additional current — size the battery for the Pi **plus** every attached radio.
- A powered USB hub can help when running multiple SDRs on a Pi 3/4.

See [Disconnected / backpack ops](../deploy/offline-backpack.md) for the full field loadout.

## The pre-built AirTAK go-kit

If assembling and tuning your own kit is not how you want to spend the week, the **AirTAK go-kit** is an assembled, tested, turnkey gateway with AryaOS pre-installed.

<div class="grid cards" markdown>

- :material-package-variant-closed: **Buy assembled** — Pi, radios, antennas, GPS, enclosure, and AryaOS in one box. [Buy hardware](../purchase.md)
- :material-tools: **Build your own** — Use the tables above, then [flash the image](flash-the-image.md).

</div>

## Next steps

<div class="grid cards" markdown>

- :material-download: **Flash the image** — Write AryaOS to your microSD card. [Flash the image](flash-the-image.md)
- :material-power: **First boot** — What happens on first power-on, and how to log in. [First boot & first login](first-boot.md)
- :material-cart: **Buy hardware** — The assembled AirTAK go-kit. [Buy hardware](../purchase.md)

</div>
