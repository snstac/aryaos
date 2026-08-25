# AryaOS 2 / v2.1.19 release notes

AryaOS 2 is a complete rewrite and the first stable release of the current
field platform. These notes summarize the public change from AryaOS 1.0 rather
than every intermediate development image.

## Highlights

- Rebuilt on Debian Trixie for Raspberry Pi 3, 4, and 5 arm64 systems.
- Added conservative first-boot hardware discovery, signal capabilities, and
  air, maritime, C-UAS, multi-sensor, and relay roles.
- Expanded sensor support to ADSBee and broad SoapySDR receivers, Wi-Fi and BLE
  Remote ID, DroneScout, DJI DroneID, SiK/MAVLink, SAPIENT, ACARS, and offline
  APRS in addition to ADS-B/UAT, AIS, and GNSS.
- Added GDLCOT output for ForeFlight and other GDL90 electronic flight bags.
- Routed local CoT through COTBridge with structured lanes, shared TLS, data
  package import, and `tak://` enrollment.
- Replaced Node-RED system configuration with an authenticated Cockpit console.
  retained Node-RED as optional, unprivileged automation behind HTTPS.
- Added fleet discovery, normalized gateway health, resilient transport
  reconnects, support bundles, updates, backup/restore, factory reset, and
  best-effort zeroize.
- Added hotspot and Bluetooth PAN isolation, Tailscale, persistent EMCON,
  per-device web TLS, firewall/fail2ban/SSH hardening, security updates, safe
  mode, and media-longevity controls.
- Added signed package delivery, mounted-image verification, SPDX/CycloneDX
  SBOMs, hardware integration tests, lifecycle gates, and burn-in evaluation.

## Breaking changes

- AryaOS 1 devices require a fresh flash. There is no supported in-place upgrade
  from the Bookworm-based v1 image to AOS2.
- Local gateways now send to COTBridge's private bus. Configure external Mesh SA
  or TAK Server destinations in the `site-output` lane rather than independently
  On every feeder.
- Tailscale replaces ZeroTier.
- Cockpit replaces Node-RED as the administration surface. Default Node-RED
  flows are empty. legacy flows remain available for manual import.
- Bundled CloudTAK is removed.
- Private dhbridge and kraktak components are removed from public images.
- Current runtime and package names are COTBridge, GPSCOT, and GDLCOT. legacy
  service aliases are not retained.

## Security notes

- Release images contain no lab SSH key or passwordless lab sudo grant and force
  The bootstrap password to change at first login.
- Zeroize now replaces and expires the `pi` password, locks other interactive
  local accounts and root, removes authorized SSH keys and shell histories,
  removes the active site and COTBridge target, and restores packaged defaults.
- Restoring configuration regenerates missing per-device Lighttpd TLS material
  before services restart.
- Zeroize remains best-effort on wear-leveled flash and is not guaranteed
  forensic erasure.

## Validation summary

- Current overlay: `aryaos-overlay_2.1.19_all.deb`.
- All 165 local unit tests, shell checks, and Ansible syntax validation passed
  for the closing implementation.
- Strict hardware integration tests passed on four lab nodes covering ADS-B,
  AIS, Remote ID, ACARS, GNSS, TAK enrollment, and lifecycle operations.
- A paced test delivered 5,000 generated CoT events per node at approximately
  675 events per second with zero COTBridge write errors.
- Extended sampling recorded no probe failures, failed units, throttling, or
  automatic core-service restart growth.

The test figures characterize the release fleet and are not throughput, range,
or availability guarantees for every hardware and network configuration.

## Download

- [AryaOS Imager](https://github.com/snstac/aryaos-imager/releases)
- [AryaOS v2.1.19 on GitHub](https://github.com/snstac/aryaos/releases/tag/v2.1.19)
- [Flashing instructions](../../get-started/flash-the-image.md)
- [Migration FAQ](faq.md)
