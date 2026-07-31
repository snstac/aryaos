# SIGINT / wideband SDR (LimeSDR Mini) — "dragonegg"

The **dragonegg** laydown is AryaOS + a **LimeSDR Mini** + GPS: a wideband
(10&nbsp;MHz–3.5&nbsp;GHz) software-defined radio on the edge for spectrum monitoring and
signal-collection tasks, with the box's own position on the map.

AryaOS ships the driver and access layer for the LimeSDR; the collection/analysis application
you point at it is deployment-specific.

## What's on the image

- **`soapysdr-module-lms7`** — the SoapySDR driver for LimeSDR / LMS7002M. Any SoapySDR client
  (readsb, SDR++, SDRangel, GQRX, GNU Radio) can drive the Lime as `driver=lime`.
- **`limesuite`** — LimeSuite tools: `LimeUtil` (find/probe/update), `LimeQuickTest`.
- **`soapysdr-module-remote`** — SoapyRemote, so a remote operator can use the Lime over the
  network (see [Remote access](#remote-access-soapyremote)).
- **`soapysdr-tools`** — `SoapySDRUtil` for enumeration/probing.

## First use

Verify the device and update its gateware (a LimeSDR Mini usually needs a one-time update):

```bash
LimeUtil --find                       # should list "LimeSDR Mini"
SoapySDRUtil --probe="driver=lime"    # full capability probe
sudo LimeUtil --update                # one-time gateware/firmware update
```

!!! warning "Power"
    The LimeSDR Mini is a **heavy, bursty USB draw**. With GPS and a Pi&nbsp;5 this is one of
    the highest-draw laydowns — use a proper **5V/5A (27&nbsp;W)** supply (or a true PoE+
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
entries), so the Lime was invisible to them no matter how it was configured — `-l` listed only
the GPS.

### As the ADS-B 1090 front-end

```bash
sudo scripts/readsb-use-lime.sh          # driver=lime, gain 40
```

This sets `readsb` to `--device-type soapysdr --soapy-device driver=lime` and restarts it.
CoT then flows through `adsbcot` → Charontak as usual. Two `readsb` bugs that made this path
useless are fixed from **3.16.15-4** onward: `--gain` was applied ten times too large on the
SoapySDR path, and a block was filled with a single `readStream()` call, which returns at most
the driver's stream MTU — 2040 samples on a Lime against a 65536-sample buffer.

!!! warning "A bare Lime is not a usable ADS-B receiver"
    Fixing those bugs is necessary but **not sufficient**. Measured on a dragonegg box with a
    1090&nbsp;MHz antenna, after both fixes:

    - SNR sits at roughly **0&nbsp;dB at every gain setting**, with the LNA already pinned at
      its 30&nbsp;dB maximum and only the baseband PGA still moving. PGA amplifies signal and
      noise equally, so it cannot buy sensitivity.
    - Burst analysis at 1090&nbsp;MHz against a 1040&nbsp;MHz control found **18 samples
      >20&nbsp;dB over median versus 0** — real traffic, but very weak.
    - Result: **~2 usable messages**, no position reports.

    The LimeSDR Mini has **no 1090&nbsp;MHz SAW filter and no LNA**, unlike a ProStick-class
    ADS-B dongle, so its own noise floor swamps the signal. For ADS-B on a Lime, fit an
    **inline 1090&nbsp;MHz filtered LNA** ahead of the RX port. An RTL-SDR remains the better
    choice if ADS-B is the box's job.

!!! note "USB stability"
    The FT601 bridge has been observed dropping off the bus under sustained streaming —
    repeated `reset SuperSpeed USB device` messages, then a fallback to high-speed, then a full
    disconnect requiring a reboot or re-plug to recover. If a capture stops without explanation,
    check `lsusb` and `dmesg` before suspecting the decoder. A powered hub is worth trying.

### Remote access (SoapyRemote) {#remote-access-soapyremote}

Expose the Lime to a remote operator running SDR++, SDRangel or GQRX with the SoapyRemote
plugin (they connect to `driver=remote,remote=<host>`):

```bash
SoapySDRServer --bind          # serves the local SDRs over the network
```

!!! danger "Not enabled by default"
    `SoapySDRServer` is **not** started automatically — it opens the SDR to the network
    unauthenticated. Start it manually only when needed, and **bind it to the Tailscale/VPN
    interface, not the open LAN** (see [Firewall](../networking/firewall.md) and
    [VPN](../networking/vpn-tailscale.md)). Stop it when you're done.

### Local capture / analysis

Any SoapySDR/LimeSuite-based tool (GNU Radio, `SoapySDRUtil`, custom collectors) can open the
Lime locally as `driver=lime`. The specific SIGINT collection/analysis application is chosen
per deployment and is outside the base image.

## See also

- [Radios & SDRs](../config/radios-sdr.md) — SDR selection and serials
- [Own position (GPS)](own-position-gps.md) — the GPS half of dragonegg
- [Hardware & requirements](../get-started/hardware.md#power--battery-for-backpack-ops) — power
