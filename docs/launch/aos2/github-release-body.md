# AryaOS 2: v2.1.19

AryaOS 2 is the complete, field-ready rewrite of the operating system that
began as AirTAK. One arm64 image can discover its attached hardware, activate
the right sensor capabilities, route them through COTBridge, connect to TAK,
and support the appliance from first boot through update, backup, reset, and
decommissioning.

## Highlights

- ADS-B/UAT, AIS, Wi-Fi and Bluetooth Remote ID, DroneScout, DJI DroneID,
  SiK/MAVLink, SAPIENT, ACARS, offline APRS, and GNSS.
- Conservative hardware discovery and air, maritime, C-UAS, multi-sensor, and
  relay roles.
- COTBridge routing to Mesh SA, TAK Server, other networks, and local recording.
- Authenticated TAK data-package import and one-time `tak://` enrollment.
- HTTPS landing page and Cockpit administration for routine field operations.
- Isolated Wi-Fi and Bluetooth PAN, Tailscale, persistent EMCON, and power-safe
  recovery.
- One-click updates, support bundles, backup/restore, factory reset, and
  best-effort zeroize.
- Signed core packages, SPDX and CycloneDX SBOMs, mounted-image verification,
  hardware integration tests, and lifecycle burn-in gates.

## Before flashing

This is a hardened **release image**: it contains no lab SSH key or lab sudo
grant, and the bootstrap password expires at first login.

Moving from AryaOS 1 requires a **fresh flash**. There is no supported in-place
Bookworm-to-Trixie upgrade. Preserve authorized TAK credentials, custom
Node-RED flows, radio tuning, and other required settings before replacing the
v1 card.

The image supports Raspberry Pi 3, 4, and 5 arm64 systems. A dedicated amd64
image does not ship in this release.

## Start here

- [Read the AryaOS 2 reveal](https://www.aryaos.org/launch/aos2/announcement/)
- [Compare AOS2 with AryaOS 1](https://www.aryaos.org/launch/aos2/feature-matrix/)
- [Read the migration FAQ](https://www.aryaos.org/launch/aos2/faq/)
- [Flash with AryaOS Imager](https://www.aryaos.org/get-started/flash-the-image/)
- [Choose hardware or an assembled gateway](https://www.aryaos.org/get-started/hardware/)

Release assets include the compressed field image, AryaOS overlay package,
`image-info.json` with image hashes and sizes, and SPDX/CycloneDX SBOMs.

AryaOS is open source under Apache 2.0 and is developed by
[Sensors & Signals LLC](https://www.snstac.com/) with support from the
[Colorado Center of Excellence for Advanced Technology Aerial Firefighting](https://www.cofiretech.org/feature-projects/team-awareness-kit-tak)
and the [USDA Forest Service](https://www.fs.usda.gov/).
