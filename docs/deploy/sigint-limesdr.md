# SIGINT / wideband SDR (LimeSDR Mini) - "dragonegg"

The **dragonegg** laydown is AryaOS + a **LimeSDR Mini** + GPS: a wideband
(10&nbsp;MHz-3.5&nbsp;GHz) software-defined radio on the edge for spectrum monitoring and
signal-collection tasks, with the box's own position on the map.

AryaOS ships the driver and access layer for the LimeSDR; the collection/analysis application
you point at it is deployment-specific.

## What one LimeSDR can receive

Everything below was measured on a dragonegg box with an outdoor antenna, not
inferred from datasheets. **One SDR does one band at a time** - these are
alternatives, not a simultaneous list.

| Capability | Band | Verified result |
|---|---|---|
| **ADS-B** | 1090 MHz | 5,173 usable messages, 711 positions, 10 aircraft tracked |
| **UAT** | 978 MHz | aircraft decoded (`N93214`, light aircraft) |
| **AIS** | 162 MHz | 15 vessels, incl. USCG base stations at −27 dBFS |
| **APRS** | 144.39 MHz | 20 packets from 7 stations, MIC-E position reports |
| **ACARS** | 130-132 MHz | 5 aircraft, incl. routes (`KSFO KABQ`) and ARINC-622 |
| **Band survey** | 100 kHz-3.5 GHz | occupancy, noise floor, carrier detection |

!!! warning "The antenna decides, not the SDR"
    This is the single most important fact about the laydown. The same box, same
    software and same SDR produced **0 usable ADS-B messages on a short indoor
    whip and 5,173 on an outdoor antenna**.

    A 1090 MHz ADS-B antenna is nearly deaf at 131 MHz ACARS, and a VHF antenna
    is poor at 1090. Budget for the antenna and its feedline before anything
    else, and expect to swap it when you change bands.

    Because the box **cannot see what antenna is attached**, SDR capabilities are
    never auto-enabled - see [Device roles](../config/device-roles.md).

## What's on the image

- **`soapysdr-module-lms7`** - the SoapySDR driver for LimeSDR / LMS7002M. Any SoapySDR client
  (readsb, SDR++, SDRangel, GQRX, GNU Radio) can drive the Lime as `driver=lime`.
- **`limesuite`** - LimeSuite tools: `LimeUtil` (find/probe/update), `LimeQuickTest`.
- **`soapysdr-module-remote`** - SoapyRemote, so a remote operator can use the Lime over the
  network (see [Remote access](#remote-access-soapyremote)).
- **`soapysdr-tools`** - `SoapySDRUtil` for enumeration/probing.

## First use

Verify the device and update its gateware (a LimeSDR Mini usually needs a one-time update):

```bash
LimeUtil --find                       # should list "LimeSDR Mini"
SoapySDRUtil --probe="driver=lime"    # full capability probe
sudo LimeUtil --update                # one-time gateware/firmware update
```

!!! warning "Power"
    The LimeSDR Mini is a **heavy, bursty USB draw**. With GPS and a Pi&nbsp;5 this is one of
    the highest-draw laydowns - use a proper **5V/5A (27&nbsp;W)** supply (or a true PoE+
    802.3at source). On a marginal supply the box can brown out; AryaOS will flag under-voltage
    (power-health) and, if it crash-loops, drop into
    [safe mode](../get-started/hardware.md#safe-mode).

## Using the LimeSDR

### As the AIS receiver

`AIS-catcher` is built with SoapySDR from **0.68-snstac3** onward, so it can drive the Lime
directly:

```bash
AIS-catcher -gu DEVICE driver=lime ANTENNA LNAW GAIN LNA=30 -s 1536000 -v
```

Note the syntax: `SOAPYSDR:` in `AIS-catcher -h` is a section heading, not part of the
argument, and passing `-d SOAPYSDR` sends it looking for a device with the literal serial
`SOAPYSDR` instead of using the one you selected.

Earlier builds were compiled **without** SoapySDR (`readelf -d` showed zero `libSoapySDR`
entries), so the Lime was invisible to them no matter how it was configured - `-l` listed only
the GPS.

### As the ADS-B 1090 front-end

```bash
sudo scripts/readsb-use-lime.sh          # driver=lime, gain 40
```

This sets `readsb` to `--device-type soapysdr --soapy-device driver=lime` and restarts it.
CoT then flows through `adsbcot` > Charontak as usual. Two `readsb` bugs that made this path
useless are fixed from **3.16.15-4** onward: `--gain` was applied ten times too large on the
SoapySDR path, and a block was filled with a single `readStream()` call, which returns at most
the driver's stream MTU - 2040 samples on a Lime against a 65536-sample buffer.

!!! success "The antenna decides this, not the SDR"
    With both fixes and an **outdoor antenna**, a LimeSDR Mini v2 decodes ADS-B properly.
    Measured on a dragonegg box, 70&nbsp;seconds at gain 40:

    - **5,173 usable messages**, **711 airborne position reports**
    - **10 aircraft tracked, all 10 with position** - RSSI −42 to −48&nbsp;dBFS, altitudes
      3,200 to 39,000&nbsp;ft

    The same box, same software, on a short indoor whip produced **0-2 usable messages and no
    positions at all**. Nothing changed but the antenna.

    So budget for the antenna and its feedline before reaching for anything else. An inline
    1090&nbsp;MHz filtered LNA may still help at a site with strong out-of-band transmitters
    nearby, but it is **not** required, and it will not rescue a receiver that cannot hear the
    band in the first place.

    An RTL-SDR remains a reasonable choice for a dedicated ADS-B box - it is cheaper and its
    front end is already tuned for 1090 - but "the Lime cannot do ADS-B" is not true.

!!! note "USB stability"
    The FT601 bridge has been observed dropping off the bus under sustained streaming -
    repeated `reset SuperSpeed USB device` messages, then a fallback to high-speed, then a full
    disconnect requiring a reboot or re-plug to recover. If a capture stops without explanation,
    check `lsusb` and `dmesg` before suspecting the decoder. A powered hub is worth trying.

### As the ACARS receiver

ACARS is the VHF datalink airliners use for operational traffic: flight plans,
position and weather reports, engine data, gate requests and crew messages.

```bash
sudo aryaos-role caps <existing caps> acars
```

That enables two units - `acarsdec` demodulates VHF, `acarscot` turns its JSON
into CoT - mirroring the `readsb`/`adsbcot` split. Frequencies live in
`/etc/default/acarsdec`; the defaults are the common US channels.

**ARINC-622 is decoded** from `acarsdec 4.6-snstac2` onward, via
[libacars](https://github.com/snstac/libacars): FANS-1/A **ADS-C** and **CPDLC**,
MIAM, OHMA and Media Advisory. Verified on live traffic:

```
Aircraft reg: B-KPD   Flight id: CX0880
/OAKODYA.DIS..B-KPD804741
ADS-C disconnect request:
```

Cathay Pacific talking to Oakland Oceanic. Without libacars that line is an
opaque string.

!!! note "Most ACARS messages have no position"
    Measured over San Francisco: **0 parseable positions in 48 messages**. The
    payloads were mostly airline engine and maintenance blobs.

    So `acarscot` emits nothing to the map for the majority of traffic, and that
    is correct rather than broken - it refuses to invent a position. What ACARS
    reliably adds is the operational context ADS-B cannot give you: tail number,
    flight ID and route.

### Audio-band decoders (APRS, pagers)

`aryaos-sdr-fm` demodulates NBFM from any SoapySDR receiver and writes PCM to
stdout, which is what `direwolf` and `multimon-ng` consume. Without it those
decoders only work with an RTL dongle, since their usual front end is `rtl_fm`.

```bash
# APRS
aryaos-sdr-fm --freq 144.390M --antenna LNAW | direwolf -r 48000 -b 16 -n 1 -

# POCSAG pagers
aryaos-sdr-fm --freq 152.0075M | multimon-ng -t raw -a POCSAG1200 -

# listen (NOAA weather radio)
aryaos-sdr-fm --freq 162.400M | aplay -f S16_LE -r 48000 -c 1
```

`--mode am` handles aviation voice and other AM signals; it is **experimental**,
with a documented level-settling caveat. De-emphasis is off by default because
it distorts AFSK tone balance - use it only when a human is listening.

Tune the output level against the decoder, not by ear: `direwolf` prints
`audio level = N` per packet and wants roughly 50.

### Remote access (SoapyRemote) {#remote-access-soapyremote}

Expose the Lime to a remote operator running SDR++, SDRangel or GQRX with the SoapyRemote
plugin (they connect to `driver=remote,remote=<host>`):

```bash
SoapySDRServer --bind          # serves the local SDRs over the network
```

!!! danger "Not enabled by default"
    `SoapySDRServer` is **not** started automatically - it opens the SDR to the network
    unauthenticated. Start it manually only when needed, and **bind it to the Tailscale/VPN
    interface, not the open LAN** (see [Firewall](../networking/firewall.md) and
    [VPN](../networking/vpn-tailscale.md)). Stop it when you're done.

### Band occupancy survey

`aryaos-spectrum-survey` sweeps a band plan and reports how busy each band is. It answers
"what is active here" without needing a decoder for any of it, which is the question a
wideband box can always answer.

```bash
sudo aryaos-spectrum-survey --antenna LNAW --gain 25
sudo aryaos-spectrum-survey --bands fmbcast,adsb1090 --json
```

```
  fmbcast    98.000 MHz  floor= -16.9 dBFS  occ=  0.000%  OCCUPIED [continuous]  carrier +46.7dB @ 97.357 MHz
  adsb1090 1090.000 MHz  floor= -66.2 dBFS  occ=  0.233%  quiet    [none]
```

It reports **measurements, never identifications**. A band being busy does not tell you what
is transmitting, and the tool will not guess - the band names are operator context only.

Each band is classified as `bursty`, `continuous`, both, or neither, because those need
different tests: a packetised emitter shows up as excursions above the band's noise floor,
while a steady carrier *is* the floor and has to be found in the frequency domain instead.

!!! warning "`occupied` is a convenience flag; the number is the measurement"
    The `OCCUPIED` threshold is 0.5% of samples more than 20&nbsp;dB above the band's own
    median. That is tuned for continuously busy bands and it **under-reports short bursts**.

    Measured case: with an outdoor antenna, 1090&nbsp;MHz surveys at **0.301% - below the
    threshold, so it prints `quiet`** - while `readsb` on the same box at the same time decoded
    **5,173 messages and tracked 10 aircraft**. ADS-B bursts are about 120&nbsp;µs against a
    2-second dwell, so low occupancy is the correct measurement and the boolean is what
    misleads. Read `occupancy_pct`, and compare a band against a known-quiet control rather
    than against the flag.

!!! note "dBFS is not dBm"
    All levels are relative to the receiver's own full scale, not absolute power. The same
    signal moved the reported floor from −31.9 to −13.4&nbsp;dBFS purely by changing gain.
    Comparing two bands in one sweep is meaningful; comparing to another receiver, or to a
    published dBm figure, is not.

Pass `--zmeta` to emit [ZMeta](https://github.com/JTC-byte/zmeta-spec) `OBSERVATION_EVENT`
records (newline-delimited JSON) instead of the table, for feeding a metadata bus rather than
a human.

### Local capture / analysis

Any SoapySDR/LimeSuite-based tool (GNU Radio, `SoapySDRUtil`, custom collectors) can open the
Lime locally as `driver=lime`. The specific SIGINT collection/analysis application is chosen
per deployment and is outside the base image.

## See also

- [Radios & SDRs](../config/radios-sdr.md) - SDR selection and serials
- [Own position (GPS)](own-position-gps.md) - the GPS half of dragonegg
- [Hardware & requirements](../get-started/hardware.md#power-battery-for-backpack-ops) - power
