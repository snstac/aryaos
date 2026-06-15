# dhbridge config payload

AryaOS-specific configuration for [snstac/dhbridge](https://github.com/snstac/dhbridge)
(`dhbridge.ini`, Bluetooth readiness helper, systemd drop-ins), applied by
**stage-dhbridge**.

The `dhbridge` package itself installs from the signed
[snstac apt repository](https://snstac.github.io/packages) via
`manifests/aryaos-sensor-packages.yml` (stage-pytak) — no vendored `.deb` here
since dhbridge went public with v0.3.2.
