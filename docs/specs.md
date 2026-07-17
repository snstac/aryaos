# Specifications

The technical specifications of AryaOS: operating system, supported hardware, protocols, standards, and device identity. For a shopping list, see [Hardware & requirements](get-started/hardware.md).

## Operating system

| Item | Specification |
|---|---|
| Base | Debian **trixie** |
| Architecture | `arm64` (Intel/amd64 planned — [#129](https://github.com/snstac/aryaos/issues/129)) |
| Image builder | pi-gen (Docker) |
| Package source | [Signed snstac apt repository](https://snstac.github.io/packages) |
| Updates | Debian-security unattended-upgrades; one-click full-upgrade via [`aryaos-update`](reference/cli-helpers.md#aryaos-update) |
| SBOM | SPDX + CycloneDX attached to every GitHub Release |

## Supported hardware

| Item | Specification |
|---|---|
| Single-board computer | Raspberry Pi 3, 4, 5 (`arm64`) |
| Storage | microSD, 16 GB minimum, 32 GB recommended |
| Radios | RTL-SDR (RTL2832U) for ADS-B / UAT / AIS; AntSDR for drones |
| GPS | Any `gpsd`-compatible USB GNSS receiver |
| Networking | Wi-Fi hotspot (comitup), Ethernet, Bluetooth PAN, Tailscale VPN |

See [Hardware & requirements](get-started/hardware.md).

## Footprint

| Interface | Address / port | Notes |
|---|---|---|
| Web admin (Cockpit) | HTTPS 9090 | Also via portal proxy on 443 → `/admin` |
| Wi-Fi hotspot | `10.41.0.1/24`, SSID `AryaOS-xxxx` | comitup portal on 9080 |
| Bluetooth PAN | `10.44.0.1/24` (`pan0`) | Local NAP, DHCP, no NAT |
| Local CoT hub | `udp://127.0.0.1:28087` | CharonTAK ingress |
| Mesh SA | multicast `239.2.3.1:6969` | Default egress |

Full list: [Ports & protocols](reference/ports.md).

## Protocols & standards supported

| Domain | Protocol / standard | On AryaOS via |
|---|---|---|
| Air | ADS-B (RTCA DO-260 family), 1090 MHz | `readsb` / `dump1090-fa` → [ADSBCOT](reference/software-suite.md) |
| Air | UAT, 978 MHz | `dump978-fa` → ADSBCOT |
| Air | APRS | [APRSCOT](reference/software-suite.md) |
| Maritime | AIS (VHF) | `ais-catcher` → [AISCOT](reference/software-suite.md) |
| Drone | Remote ID / Open Drone ID (ASTM) | [DroneCOT](reference/software-suite.md) |
| Drone | DJI DroneID | DJICOT |
| Drone | MAVLink (SiK radio telemetry) | SiKW00FCOT |
| Position | NMEA / `gpsd` | [GPSTAK](reference/software-suite.md), LINCOT |
| TAK | Cursor on Target (CoT) — XML & Protobuf | [PyTAK](reference/software-suite.md#pytak) / all gateways |
| TAK | Mesh SA multicast | [CharonTAK](reference/software-suite.md#charontak) |
| TAK | TAK Server streaming (TLS/TCP) | CharonTAK lanes |
| EFB | GDL90 | [GDLTAK](reference/software-suite.md) |

Definitions for each: [Glossary](reference/glossary.md).

## TAK compatibility

Works with all TAK products: **ATAK, WinTAK, iTAK, TAKX, and TAK Server**. Devices onboard to a TAK Server by data package or `tak://` enrollment link — see [Connect to a TAK Server](deploy/connect-tak-server.md).

## Device identity

| Item | Specification |
|---|---|
| Machine ID | RFC 4122 UUID (`/etc/machine-id`) |
| Device suffix | [`DEVICE_SUFFIX`](reference/glossary.md#device_suffix) — 4 hex chars from machine-id (or MAC) |
| Hostname / mDNS | `aryaos-xxxx` / `aryaos-xxxx.local` |
| Wi-Fi SSID | `AryaOS-xxxx` |
| CoT source id | `COT_HOST_ID=aryaos-xxxx` |

## Security posture

Per-device web TLS, hardened `sshd` (no root, `MaxAuthTries 4`), `fail2ban`, sysctl hardening, `firewalld` allowlist, Debian-security unattended-upgrades, and JSON-logged sudo. The default `pi` password expires at first login on release images. Full detail: [Security posture](security.md).

## See also

<div class="grid cards" markdown>

- :material-cart: **Buy hardware** — The assembled AirTAK go-kit. [Buy hardware](purchase.md)
- :material-package: **Software suite** — What ships in the box. [Software suite](reference/software-suite.md)
- :material-lan: **Ports & protocols** — The network footprint. [Ports & protocols](reference/ports.md)

</div>
