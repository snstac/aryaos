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

### As the ADS-B 1090 front-end

The Lime can replace an RTL-SDR for ADS-B:

```bash
sudo scripts/readsb-use-lime.sh          # driver=lime, gain 40
```

This sets `readsb` to `--device-type soapysdr --soapy-device driver=lime` and restarts it.
CoT then flows through `adsbcot` → Charontak as usual.

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
