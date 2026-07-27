---
hide:
  - navigation
  - toc
---

# AryaOS

**The all-in-one operating system for building a Common Operating Picture.**

AryaOS turns an inexpensive single-board computer into a turn-key gateway that
puts live aircraft, vessels, and drones onto any [TAK](reference/glossary.md#tak)
device — ATAK, WinTAK, iTAK, or a TAK Server — with no cloud, no subscription,
and no command line required. Sensors in, [Cursor on Target](reference/glossary.md#cot)
out, managed entirely from a touch-friendly web console.

ADS-B and UAT aircraft, AIS vessels, drone Remote ID over Wi-Fi and Bluetooth,
DJI DroneID, APRS, and your own GPS position — on one box, in one picture.

[Get started in 15 minutes](get-started/quickstart.md){ .md-button .md-button--primary }
[What is AryaOS?](get-started/overview.md){ .md-button }

---

## Pick your mission

<div class="grid cards" markdown>

-   :material-airplane: **Aircraft**

    ---

    Display ADS-B and UAT air traffic in TAK. The original AirTAK use case —
    proven in wildland fire and SAR.

    [:octicons-arrow-right-24: Aircraft (ADS-B)](deploy/air-adsb.md)

-   :material-ferry: **Maritime**

    ---

    Track ships and vessels from AIS, over the air or from an online feed.

    [:octicons-arrow-right-24: Maritime (AIS)](deploy/maritime-ais.md)

-   :material-quadcopter: **Counter-UAS**

    ---

    Detect and track drones by Remote ID — over Wi-Fi *and* over Bluetooth — plus
    DJI DroneID. Reports the aircraft and the operator's location.

    [:octicons-arrow-right-24: Counter-UAS](deploy/counter-uas.md)

-   :material-sitemap: **Multi-sensor COP**

    ---

    Fuse air, maritime, and drone feeds into one picture — or relay CoT between
    networks and a TAK Server.

    [:octicons-arrow-right-24: Multi-sensor](deploy/multi-sensor.md)

</div>

## What it can hear

Each capability is a receiver AryaOS knows how to turn into TAK tracks. The image
ships with every sensor **switched off**; on first boot the box detects what is
actually plugged in and enables what it finds, then reports anything it could do
but did not turn on. Mix them freely — it will tell you when two capabilities
want the same radio.

| Capability | What appears on the map | Typical receiver |
|------------|-------------------------|------------------|
| **ADS-B / UAT** | Crewed aircraft on 1090 MHz and 978 MHz | RTL-SDR or any SoapySDR device |
| **AIS** | Ships and vessels | dAISy NMEA receiver, or a spare SDR |
| **Wi-Fi Remote ID** | ASTM F3411 Remote ID over 802.11, plus operator location | Monitor-mode adapter (e.g. Atheros AR9271) |
| **Bluetooth Remote ID** | ASTM F3411 Remote ID over Bluetooth LE | **None — the board's own radio** |
| **DJI DroneID** | DJI aircraft and the pilot's position | AntSDR E200 |
| **DroneScout DS101** | Remote ID via a dedicated receiver | BlueMark DS101 |
| **SiK telemetry** | MAVLink drone telemetry | SiK radio |
| **SAPIENT** | Counter-UAS sensors speaking BSI Flex 335 | Network sensor |
| **APRS** | Amateur radio stations and trackers | RTL-SDR |
| **GPS** | The node's own position, shared with every connected device | USB GPS receiver |

[:octicons-arrow-right-24: Choosing hardware](get-started/hardware.md) &nbsp;·&nbsp;
[:octicons-arrow-right-24: Capabilities and device roles](config/device-roles.md)

## Start here

<div class="grid cards" markdown>

-   :material-rocket-launch: **Quickstart**

    ---

    Flash a card, boot the box, connect a phone, see tracks.

    [:octicons-arrow-right-24: 15-minute quickstart](get-started/quickstart.md)

-   :material-content-save: **Flash the image**

    ---

    Write AryaOS to a microSD card with Raspberry Pi Imager or Etcher.

    [:octicons-arrow-right-24: Flash the image](get-started/flash-the-image.md)

-   :material-application-cog: **Web admin**

    ---

    Everything is configurable from the browser — no SSH needed.

    [:octicons-arrow-right-24: Tour the web console](admin/index.md)

-   :material-server-network: **Connect to TAK Server**

    ---

    Import a data package or enrollment URL and forward your feeds upstream.

    [:octicons-arrow-right-24: Connect a TAK Server](deploy/connect-tak-server.md)

</div>

## Why AryaOS

- **Runs anywhere, offline.** Boots on a Raspberry Pi, broadcasts its own Wi-Fi,
  and needs no internet to put a picture on a phone in a backpack.
- **Never touch a terminal.** Network, radios, TAK certificates, VPN, updates,
  device role, and diagnostics all live in the web console.
- **Quiet by default.** A stock image ships with every sensor disabled and only starts
  what the attached hardware supports, so a box with no radios is a working TAK node —
  not a wall of errors.
- **Built on open standards.** Every gateway is powered by
  [PyTAK](reference/glossary.md#pytak) and speaks Cursor on Target to the whole
  TAK ecosystem. See the [software suite](reference/software-suite.md).
- **Hardened for the field.** Firewalled, brute-force protected, per-device TLS,
  first-login password expiry, and a published [security posture](security.md).

!!! info "Who builds AryaOS"
    AryaOS is developed by [Sensors &amp; Signals LLC](https://www.snstac.com/) and
    funded by the [Colorado Center of Excellence for Advanced Technology Aerial
    Firefighting](https://www.cofiretech.org/) and the
    [USDA Forest Service](https://www.fs.usda.gov/). It is in active use by
    wildland fire, security, safety, and response organizations worldwide.
