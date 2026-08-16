# Changelog

## AryaOS 2 / v2.1.19 — 2026-08-16

AryaOS 2 is a complete rewrite of the April 2024 AryaOS 1.0 image. See the
[launch announcement](docs/launch/aos2/announcement.md),
[complete v1 comparison](docs/launch/aos2/feature-matrix.md), and
[migration FAQ](docs/launch/aos2/faq.md).

### Added

- Conservative first-boot capability discovery, signal-level capability state,
  and air, maritime, C-UAS, multi-sensor, and relay roles.
- ADSBee and SoapySDR receiver support; Wi-Fi and Bluetooth Remote ID;
  DroneScout, DJI DroneID, SiK/MAVLink, SAPIENT, ACARS, and offline APRS paths.
- GDLCOT output for ForeFlight and other GDL90 electronic flight bags.
- COTBridge as the local CoT hub, with structured ingress/egress lanes, a
  validated Cockpit editor, local recording, and normalized runtime health.
- Authenticated TAK data-package import and one-time `tak://` enrollment that
  install shared TLS credentials and configure the COTBridge output lane.
- GPSCOT network position, LINCOT host health/capability beacons, Mesh SA
  neighbor discovery, and GNSS/PPS-disciplined network time.
- HTTPS field command deck and Cockpit controls for device roles, gateways,
  TAK, TLS, radios, hotspot security, Tailscale, EMCON, updates, diagnostics,
  backups, reset, and zeroize.
- Local-only Bluetooth PAN, onboarding-network isolation, persistent radio
  silence, spectrum survey/ZMeta output, SDR retasking, and opt-in rtl_tcp,
  SoapyRemote, and SpyServer sharing.
- One-click updates, redacted support bundles, full/no-secrets configuration
  backup and restore, factory reset, best-effort zeroize, and local CoT
  recording/query/export/purge.
- Brownout/crash-loop safe mode, zram swap, RAM-backed volatile logs, fstrim,
  NVMe guidance, local documentation, and release-image self-download.
- SPDX and CycloneDX SBOMs, signed package delivery, mounted-image verification,
  strict hardware integration tests, lifecycle gates, and burn-in evaluation.

### Changed

- Rebuilt the image on Debian Trixie using pi-gen and shared Ansible roles.
- Optional sensors now ship disabled and start only after deliberate role or
  capability selection; the CoT/GNSS core remains available.
- Local gateways write to the private COTBridge bus. The `site-output` lane owns
  the external Mesh SA or TAK Server destination.
- Cockpit is the administration surface. Node-RED remains optional automation,
  runs unprivileged with empty default flows, binds to loopback, and is exposed
  through HTTPS.
- Tailscale replaces ZeroTier for optional remote access.
- Runtime/package names use COTBridge, GPSCOT, and GDLCOT without legacy service
  aliases.
- Packages install and update from the signed Sensors & Signals apt repository;
  the `aryaos-overlay` package is also attached to image releases.

### Security

- Added a firewalld inbound allowlist, isolated onboarding zones, fail2ban,
  hardened SSH and sysctl settings, and daily Debian security upgrades.
- Release images contain no lab SSH key or lab sudo grant, prohibit root SSH,
  and expire the bootstrap password at first login.
- Each device generates unique web TLS material; TAK keys are protected from
  Node-RED and other unrelated service accounts.
- TAK package import requires authentication; XML parsing is bounded against
  entity-expansion denial of service; the neighbor parser is sandboxed.
- Zeroize removes the active site/COTBridge target and TLS material, replaces
  and expires the `pi` password, locks other local login accounts and root,
  removes authorized keys and shell histories, and restores packaged defaults.
- Restore regenerates missing per-device web TLS material before restarting the
  portal.

### Removed

- Bundled CloudTAK. Use Mesh SA or connect AryaOS to an existing TAK Server.
- Private dhbridge and kraktak components from public builds. The local
  Bluetooth PAN phone-to-box link remains.
- Node-RED's role as the system configuration path and its default demo flows.

### Migration

- AryaOS 1 devices require a fresh flash; an in-place Bookworm-to-Trixie upgrade
  is not supported.
- Preserve authorized TAK credentials, custom Node-RED flows, radio tuning, and
  site settings before replacing the v1 card, then import or recreate them in
  AOS2.
- The downloadable image remains arm64. A dedicated amd64 image is not included.

### Validation

- Overlay `aryaos-overlay_2.1.19_all.deb` passed all 165 local unit tests, shell
  checks, Ansible syntax checks, and strict HIL on four sensor nodes.
- A 5,000-event-per-node paced test ran at approximately 675 events per second
  with zero COTBridge write errors. Extended fleet sampling recorded no probe
  failures, failed units, throttling, or automatic core-service restart growth.

These figures describe the release test fleet, not guaranteed performance or
RF range for every deployment. Zeroize is best-effort on wear-leveled flash and
is not guaranteed forensic erasure.

## AryaOS 1.0.0

Rename of AirTAK OS to AryaOS.

Includes:
* ADS-B Gateway
* AIS Gateway
* Remote ID Gateway

## AirTAK OS R03

- Fixes #38: Upgraded to Debian bookworm.
- Fixes #37: Replace broken comitup/python-networkmanager dependency.
- Fixes #36: Bundle TFR2COT Node-RED Nodes.
- Fixes #34: Add PAR Sit(x) support.
- Fixes #33: COT_URL not updated from web UI.
- Fixes #32: Show AirTAK's IP in Dashboard.
- Fixes #26: Show WiFi QR-Code in Web Dashboard.
- Fixes #22: Set static position.

## AirTAK OS R02

- Fixes #3: Added Web dashboard to monitor, configure & control AirTAK.
- Fixes #2: Fixed bad dump978 config.
- Fixes #4: Added ability to enable, disable & reset WiFi.
- Built mkdocs based documentation site: https://airtak.readthedocs.io/
- Replaced wifi-connect with comitup for managing WiFi Hotspot.
- Default WiFi network has changed to 10.41.0.1/24
- Rewrote AirTAK web page in UIkit.

## AirTAK OS R01

Initial Release
