# ADSBee (hardware ADS-B receiver)

The **ADSBee 1090U** is a dedicated ADS-B receiver that replaces *both* RTL-SDR
dongles on an air box. It demodulates 1090 MHz Mode S **and** 978 MHz UAT in its
own silicon (an RP2040 plus a sub-GHz radio) and hands the results to the Pi over
a single USB cable as a Mode S Beast stream.

`readsb` reads that stream directly with `--device-type modesbeast`, so the rest
of the pipeline is completely unchanged:

```
ADSBee --USB serial (Beast)--> readsb --> /run/adsb/aircraft.json --> adsbcot --> CoT
```

## Why fit one

| | 2 × RTL-SDR | ADSBee 1090U |
|---|---|---|
| Bands | 1090 (readsb) + 978 (dump978-fa) | 1090 **and** 978, one device |
| USB ports | 2 | 1 |
| readsb CPU | a large fraction of a core, demodulating | **~0%** — nothing on the Pi demodulates |
| Spare SDR | none | the box's SDR is freed for AIS or ACARS |

The CPU figure is the headline: with an SDR, `readsb` is doing DSP on a 2 MSPS
sample stream. With an ADSBee it is parsing pre-decoded frames off a serial port.
That is the power and heat saving, and on a Pi 5 it is the difference between
comfortable and thermally marginal.

## Setup

Plug it in. That is the whole procedure.

At boot, `aryaos-adsbee.service` runs before `readsb`, finds the device,
configures it, and writes `/run/aryaos/adsbee.env`. `run_readsb.sh` reads that
file and switches `readsb` to the ADSBee automatically, because
[`ARYAOS_ADSB_RECEIVER`](./site-config.md) defaults to `auto`. Plugging one in
after boot works too — a udev rule re-runs provisioning.

Then enable the ADS-B capability as usual:

```bash
sudo aryaos-role caps adsb
```

`dump978-fa` is deliberately **not** started when an ADSBee is in use: the ADSBee
already covers 978 UAT, and dump978-fa would only crash-loop looking for a 978
dongle that is not there.

### Checking it

```bash
sudo aryaos-adsbee info            # what was detected, and its firmware
jq '.aircraft | length' /run/adsb/aircraft.json
```

UAT aircraft appear in `aircraft.json` with `"type": "adsr_icao"`. The ADSBee
encapsulates UAT in Beast **frame type `0xec`**, which readsb unpacks and
converts through `uat2esnt` — so 978 traffic arrives over the same USB cable as
1090, with no extra configuration.

## Choosing the receiver by hand

`ARYAOS_ADSB_RECEIVER` in `/etc/aryaos/aryaos-config.txt`:

| Value | Behaviour |
|---|---|
| `auto` (default) | Use an ADSBee if one is detected, otherwise the SDR settings in `/etc/default/readsb` |
| `adsbee` | Always expect an ADSBee; never fall back to an SDR |
| `rtlsdr`, `soapysdr` | Keep using the SDR even with an ADSBee attached |

```bash
sudo ./scripts/readsb-use-adsbee.sh          # pin to the ADSBee
sudo ./scripts/readsb-use-adsbee.sh --auto   # back to automatic
```

Nothing here edits `/etc/default/readsb`. The SDR line stays exactly as built, so
removing the ADSBee returns the box to its SDR configuration.

## Emissions and privacy

!!! danger "Stock ADSBee firmware is not field-safe out of the box"
    A factory ADSBee ships with **its Wi-Fi access point enabled** (SSID
    `ADSBee1090-<serial>`, password `yummyflowers`) and **four public aggregator
    feeds preconfigured and active** — `feed.whereplane.xyz`, `feed.adsb.lol`,
    `feed.airplanes.live` and `feed.adsb.fi`. Those feeds are dormant only while
    the device has no network of its own. Give it one and it will begin
    reporting this receiver's position and traffic to the internet.

AryaOS provisioning shuts all of that down, every boot:

- Wi-Fi AP off, Wi-Fi station off, Ethernet off
- all ten feed slots set inactive with protocol `NONE`
- console log level silenced (debug text would corrupt the binary Beast stream)

Set `ARYAOS_ADSBEE_RADIO=on` only if you deliberately want the ADSBee on a
network, then re-run `sudo aryaos-adsbee provision`.

The disabled feed slots still *display* their original hostnames in the device's
own settings dump. That is cosmetic: the firmware keeps the last hostname string
even when a slot is cleared. What matters is that each slot reads
`...,0,0,NONE` — port 0, inactive, no protocol.

!!! warning "Do not disable the ESP32"
    `AT+ESP32_ENABLE=0` looks like the tidiest way to silence a box that will
    never use the ADSBee's networking. It is not: it stops the device reporting
    **entirely**, including Beast over USB, which has nothing to do with
    networking. Measured on firmware 0.9.0-rc19: zero bytes in 120 s with the
    ESP32 disabled, 63 Beast frames in the next 120 s with it re-enabled — same
    antenna, same sky, both receivers reporting `ENABLED` the whole time.
    Provisioning therefore pins `ESP32_ENABLE=1`, and disables each radio
    individually instead.

## Troubleshooting

**No aircraft.** Confirm the device was found: `sudo aryaos-adsbee info`. If it
reports nothing, check the cable is a data cable and that `readsb` is stopped
while you probe — the console is a single serial port, so `readsb` and a probe
cannot both hold it. `systemctl stop readsb` first.

**It is not identified.** The ADSBee enumerates with the stock Raspberry Pi Pico
USB id (`2e8a:000a`), shared with every RP2040 board, and it ships silent. So
AryaOS cannot recognise it from USB descriptors or by listening; it identifies
the device by sending `AT+DEVICE_INFO?` and reading the reply. If a probe fails,
the port is usually busy.

**`readsb` runs but reports nothing.** Verify the device is actually emitting:

```bash
sudo systemctl stop readsb
sudo timeout 30 cat /dev/serial/by-id/usb-Raspberry_Pi_Pico_*-if00 | xxd | head
```

You want `1a 32` / `1a 33` (Mode S short/long) and `1a ec` (UAT) frame markers.
Air traffic can genuinely be sparse; listen for a minute or more before
concluding the receiver is at fault, and check the antenna.
