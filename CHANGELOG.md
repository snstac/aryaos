## AryaOS (Unreleased)

- dhbridge (DroneHone Bluetooth bridge) and kraktak removed from public builds
  while their source is private. The Bluetooth PAN phone-to-box link stays:
  `stage-dhbridge` is now `stage-bt-pan` (payload in `shared_files/bt-pan/`),
  and `verify-image.sh` now fails if dhbridge artifacts ship in an image.
- Hardening (see [docs/security.md](docs/security.md)): firewalld inbound
  allowlist (managed via Cockpit → Networking → Firewall), fail2ban sshd jail,
  sshd tightening (no root login), sysctl hardening, daily unattended Debian
  security upgrades (no auto-reboot; snstac stack stays operator-driven),
  per-device web TLS key minted at first boot, and `/etc/aryaos/tls` no longer
  owned by the Node-RED user.
- One-click updates: `aryaos-update {check|apply|status}` +
  `aryaos-update.service`, driven by the new *Software updates* card in
  Cockpit → AryaOS Site (cockpit-aryaos ≥ 1.1). `cockpit-packagekit` remains
  for per-package work.
- `aryaos-overlay` bumped to 2.1 and now attached as a `.deb` release asset so
  deployed units can upgrade the overlay itself from the snstac apt repo.
- New image checks in `scripts/verify-image.sh` and runtime checks in
  `scripts/aryaos-test/tests/09-security.sh`.
- Set `COT_HOST_ID` to `aryaos-<suffix>` on first boot (in `aryaos-config.txt`,
  alongside `DEVICE_SUFFIX`) so the PyTAK *cot tools stamp a functional source id
  into their CoT `_flow-tags_` and remarks.

## AryaOS 2.0.0

Complete re-write of AryaOS to support both Ansible and Pi-Gen.

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
