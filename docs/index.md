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

    Detect and track drones via Remote ID and DJI DroneID for airspace awareness.

    [:octicons-arrow-right-24: Counter-UAS](deploy/counter-uas.md)

-   :material-sitemap: **Multi-sensor COP**

    ---

    Fuse air, maritime, and drone feeds into one picture — or relay CoT between
    networks and a TAK Server.

    [:octicons-arrow-right-24: Multi-sensor](deploy/multi-sensor.md)

</div>

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
