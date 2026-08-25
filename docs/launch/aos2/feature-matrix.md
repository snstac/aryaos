# AryaOS 2 compared with AryaOS 1

This is the canonical launch comparison between the April 2024 AryaOS 1.0 image
and AryaOS 2 stable release `v2.1.19`.

Status terms:

- **New** did not exist in AryaOS 1.0.
- **Improved** substantially expands or hardens a v1 capability.
- **Changed** replaces a v1 design or workflow.
- **Retained** remains available with no launch-level change claimed.
- **Removed** is deliberately absent from the public AOS2 image.

## Foundation and installation

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| Operating-system base | Changed | Debian Bookworm image | Debian Trixie, rebuilt around pi-gen and shared Ansible roles | A current, reproducible platform rather than accumulated image stages |
| Hardware image | Improved | Raspberry Pi-oriented image | Tested arm64 image for Raspberry Pi 3, 4, and 5 | One supported image across common field hardware |
| AryaOS Imager | New | Manual image download and generic flasher | Purpose-built Windows/Linux imager with stable and dev channels | Less chance of selecting the wrong image |
| First-boot identity | Improved | Static/default-oriented identity | Unique hostname, SSID, CoT host ID, and per-device web certificate | Boxes can coexist and be recognized in a fleet |
| Hardware setup | New | Manual service and device configuration | Conservative capability discovery and automatic first-boot apply | A kitted box configures itself while a bare box stays healthy |
| Package delivery | Changed | Components largely embedded by the image build | Versioned packages from the signed snstac apt repository | Patch individual components without rebuilding every device |
| Software updates | New | Reflash or manual package work | One-click operator updates plus daily Debian security fixes | Maintain fielded nodes without a shell |
| Offline documentation | New | External documentation | Full documentation served from the device | Procedures remain available without internet access |
| Release image backup | New | Not provided | Download the box's own release image for an offline recovery kit | Keep matching recovery media with a deployment |
| Supply-chain inventory | New | No image SBOM | SPDX and CycloneDX SBOMs attached to releases | Inspect and scan exactly what ships |

## Sensors, signals, and outputs

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| ADS-B 1090 MHz | Improved | ADS-B gateway with RTL-oriented decoder setup | readsb or dump1090-fa with RTL-SDR, ADSBee, SoapySDR, and HackRF paths | More receiver choices and cleaner switching |
| UAT 978 MHz | Improved | Bundled dump978 path | Role-managed dump978-fa with stable per-radio selection | Simultaneous US 978/1090 coverage with two receivers |
| Aircraft classification | Improved | Basic aircraft feed | AIRCOT-backed classification and unified runtime feed | More useful TAK symbology |
| ForeFlight/GDL90 | New | Not provided | GDLCOT rebroadcasts the TAK air picture to EFBs | Share traffic with aviation users outside TAK |
| AIS vessels | Improved | AIS gateway | Serial dAISy protocol assignment or over-the-air SDR decoding | Supports dedicated and general-purpose receivers |
| Wi-Fi Remote ID | Improved | General Remote ID gateway | Dedicated monitor-mode DroneCOT instance with adapter preparation and health | Receive ASTM Remote ID and operator position over 802.11 |
| Bluetooth Remote ID | New | Not available on the onboard radio | Dedicated BLE Remote ID capability | Adds a sensor without another USB receiver |
| Dedicated Remote ID receiver | New | Not explicitly integrated | Protocol-validated DroneScout MAVLink receiver support | Reliable integration without mistaking arbitrary serial adapters |
| DJI DroneID | New | Not integrated as a managed capability | AntSDR/DJICOT path, console access, and feed health | Adds DJI aircraft and pilot/home information where broadcast |
| SiK/MAVLink telemetry | New | Not integrated | SiKW00FCOT managed capability | Put local UAS telemetry into TAK |
| SAPIENT | New | Not integrated | BSI Flex 335 DetectionReport gateway and Cockpit page | Bridge compatible C-UAS sensor/fusion systems into TAK |
| ACARS | New | Not integrated | VHF decoder plus ACARSCOT for supported position reports | Add position-bearing aviation messages from wideband SDR builds |
| APRS over RF | Improved | APRS listed as a bundled gateway | Offline RTL-SDR to Dire Wolf to APRSCOT path | Receive local amateur-radio position traffic without APRS-IS |
| Own position | Improved | Static/GPS position support | LINCOT host beacon with gpsd position, HAE, CE/LE, motion, and health | The gateway is a visible, self-describing TAK node |
| Network GPS | New | Not provided | GPSCOT sends CoT position and NMEA to ATAK/WinTAK clients | Share one receiver with connected end-user devices |
| GNSS integrity | New | Basic position display | Cockpit GPS status includes live receiver data and spoof/jam integrity indicators | Distinguish a fix from a fix that needs operator attention |
| Multi-sensor operation | Improved | Multiple gateway stages installed together | Explicit capabilities, contention handling, and a unified CoT hub | Combine signals without hidden radio conflicts |

## Hardware intelligence and RF tools

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| Sensors off by default | Changed | Installed sensor services can start without matching hardware | Optional receivers remain disabled until declared or detected | Missing hardware does not make the appliance look broken |
| Mission roles | New | Fixed image/service layout | Air, maritime, C-UAS, multi-sensor, and relay roles | Repurpose a box without reflashing it |
| Capability model | New | Product/stage-oriented setup | Signal names report active, enabled, and available state | Operators see what a box can do and what it is doing |
| Radio contention | New | Manual avoidance | Discovery reports when one receiver is claimed by competing jobs | Prevent decoders from fighting over a device |
| GPS/AIS serial classification | New | Manual device paths | Checksum-valid NMEA and SiRF probing with stable by-id assignment | Receiver swaps and USB enumeration changes are safer |
| ADSBee discovery | New | Not supported | Device-specific read-only protocol check and Beast-source configuration | A generic Pico is not falsely claimed as an ADSBee |
| DroneScout discovery | New | Not supported | Full MAVLink frame validation on candidate serial ports | Avoids destructive or false serial assignments |
| SDR inventory and serial writing | New | Shell/manual EEPROM tooling | Cockpit inventory plus validated EEPROM serial changes | Assign 1090 and 978 radios from the browser |
| Universal SDR enumeration | New | RTL-centric | RTL-SDR, Airspy, HackRF, and LimeSDR through SoapySDR | Reuse broader receiver hardware |
| Live SDR retasking | New | Reconfigure services manually | Persisted ADS-B, UAT, AIS, APRS, or off jobs | Change missions without reserializing a receiver |
| Network SDR sharing | New | Not provided | Opt-in rtl_tcp, SoapyRemote, and SpyServer modes | Give trusted remote analysts raw receiver control |
| Spectrum survey | New | Not provided | Band occupancy scan with optional ZMeta observation output | Rapidly characterize local RF activity |
| General demodulation | New | Not provided | NBFM and experimental AM output from SoapySDR receivers | Support specialist analysis beyond packaged decoders |

Raw SDR sharing is unauthenticated and closed by the firewall by default. It is
for a trusted LAN or VPN, not walk-up public access. AM mode is explicitly
experimental.

## CoT routing and TAK connectivity

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| CoT architecture | Changed | Gateways generally targeted Mesh SA directly | Feeders write to a private COTBridge bus. Lanes own external egress | Configure routing once for the whole site |
| Multiple routes | New | Per-service destinations | Structured ingress/egress lanes for Mesh SA, TAK Server, and other networks | Send one local picture to several consumers |
| Lane editor | New | Raw configuration | Validated Cockpit editor plus advanced raw INI escape hatch | Catch bad URLs, UDP directions, and bind conflicts before save |
| TAK data-package import | New | Manual certificate/config work | Authenticated `.zip`/`.dpk` import provisions TLS and the output lane | Connect the appliance, not every daemon |
| `tak://` enrollment | New | Not provided | One-time enrollment URL with certificate-chain and hostname validation | Faster, safer TAK Server onboarding |
| Shared TLS | Improved | Service-by-service configuration | Site certificate, key, CA, and verification policy inherited by gateways | One credential operation across the sensor suite |
| Transport resilience | Improved | Failures commonly depended on service restart behavior | In-process reconnect supervision for transient network failures | Keep gateway PIDs and state through recoverable outages |
| Runtime health contract | New | Service-up/down observations | Normalized input, output, health, counters, staleness, and retry state | Distinguish “running” from “moving data” |
| Nearby-node discovery | New | Not provided | Structured AryaOS beacons and Mesh SA neighbor cache | A local fleet discovers itself without a cloud inventory |
| Host telemetry beacon | New | Basic host marker | Load, memory, storage, temperature, throttle, clock, Bluetooth, roles, and capabilities | Remote operators see the condition of the edge node |
| Local recording | New | Legacy Node-RED recorder helpers | COTBridge lane recording with status, queries, CSV export, coverage/dropout analysis, and purge | Retain selected CoT history for review without claiming a full replay UI |

## Browser operations and networking

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| Landing page | Improved | Basic UIkit dashboard | HTTPS field command deck for gateways, GNSS, host, power, radios, and links | Immediate status on a phone-sized screen |
| Admin surface | Changed | Node-RED-centered configuration | Authenticated Cockpit site page and gateway plugins | Use a system administration tool for system administration |
| Per-gateway controls | New | Mixed configuration paths | Dedicated Cockpit pages for core sensor gateways | Common service, TLS, config, and log workflow |
| Node-RED | Changed | Default dashboard/configuration flows | Optional low-code automation, empty by default, loopback behind HTTPS | Retain extensibility without making it a privileged dependency |
| Wi-Fi onboarding | Improved | Comitup hotspot | Unique SSID, configurable WPA2 password, and isolated firewall zone | Easier and safer walk-up setup |
| Bluetooth PAN | New | Not provided | Local DHCP link to AryaOS with no NAT or forwarding | Reach a disconnected box without emitting Wi-Fi |
| Remote access | Changed | ZeroTier | Tailscale managed from Cockpit | Supported remote administration without port forwarding |
| EMCON | New | Wi-Fi controls only | Persistent rfkill of onboard Wi-Fi and Bluetooth before network startup | Prevent unintended onboard-radio emissions |
| Hotspot isolation | New | Broad local connectivity | Wi-Fi and Bluetooth onboarding clients cannot reach wired networks | A walk-up client reaches the appliance, not the upstream LAN |
| Network time | New | GPS time helper | Chrony time server with GNSS/PPS discipline where available | Share trustworthy local time in disconnected deployments |
| Offline position view | New | Text/static position | Packaged North America basemap and current GNSS position in Cockpit | Confirm location without fetching map tiles |

## Lifecycle, resilience, and security

| Capability | Status | AryaOS 1.0 | AryaOS 2 | Why it matters |
|---|---|---|---|---|
| Support bundles | New | Manual troubleshooting | Downloadable, redacted diagnostic archive with TLS keys excluded | Give support evidence without giving away credentials |
| Configuration backup | New | Manual copies | Full or no-secrets snapshot of site, gateway, network, decoder, and Node-RED state | Migrate or recover a configured appliance |
| Configuration restore | New | Manual rebuild | Validated additive restore with web TLS reconciliation | Recover configuration without leaving the portal offline |
| Factory reset | New | Reflash | Restore packaged defaults, identity, radio discovery, and first-boot behavior | Return a box to service without new media |
| Zeroize | New | Reflash/manual deletion | Remove operational targets, credentials, keys, histories, recordings, and local accounts before clean bootstrap | Decommission or recover a potentially captured node |
| Power safe mode | New | Repeated brownouts can crash-loop | After repeated short boots, cut USB power and withhold sensors while keeping admin access | Diagnose a weak supply instead of losing the box |
| Media longevity | New | Conventional swap/log behavior | zram swap, RAM-backed volatile logs, fstrim, and bounded audit logging | Reduce write amplification on SD/NVMe media |
| Firewall | New | No appliance-wide allowlist | Enabled firewalld services and zones with explicit inbound exposure | Minimize the network surface |
| SSH defenses | Improved | SSH enabled | No root login, bounded auth attempts, fail2ban, and first-login expiry | Safer field bootstrap and remote access |
| Web TLS | Improved | Shared/generated certificate behavior | Unique key and certificate generated per device | Avoid shipping one web private key across the fleet |
| Service privilege | Improved | Node-RED and helpers had broad ownership/access | Node-RED unprivileged. TAK keys protected by a dedicated group. Parsers sandboxed | Limit the result of a service compromise |
| Security updates | New | Manual | Daily Debian security updates without surprise appliance-stack upgrades or reboot | Patch the base while preserving operator control |
| Image verification | New | Build success was the primary gate | Mounted-image assertions for packages, services, files, permissions, versions, and release security mode | Test what is actually flashed |
| Hardware HIL | New | Ad hoc field tests | Strict per-role integration suite plus lifecycle and burn-in gates | Exercise the complete appliance on real receivers |

Zeroize is best-effort on wear-leveled flash. It is not a claim of guaranteed
forensic erasure, crypto-erase, FIPS validation, or STIG compliance.

## Migration and removals

| Change | Status | AryaOS 1.0 | AryaOS 2 consequence |
|---|---|---|---|
| Upgrade path | Changed | Existing v1 install | Fresh flash required. No supported in-place upgrade |
| Base distribution | Changed | Debian Bookworm | Debian Trixie. Do not mix package sets across the boundary |
| External CoT destination | Changed | Set destinations on individual gateways | Keep feeders on the private bus and configure COTBridge `site-output` |
| Remote VPN | Changed | ZeroTier | Re-enroll the device in Tailscale if remote access is needed |
| System configuration | Changed | Node-RED and service files | Use Cockpit for routine configuration. Import custom Node-RED flows separately |
| Bundled CloudTAK | Removed | Appeared during the v1-era development line | Connect to an existing TAK Server or use Mesh SA |
| dhbridge and kraktak | Removed | Private components appeared in development builds | Not part of the public image. Bluetooth PAN remains |
| amd64 image | Unchanged limitation | Not a supported image | Still planned. The downloadable AOS2 image is arm64 |
| Unified browser COP | Not shipped | Separate sensor views | AOS2 fuses data into TAK. A native all-sensor browser map remains roadmap |
| Track replay UI | Not shipped | Legacy helpers | Recording/query/export ship. An integrated browser replay workflow remains roadmap |

## Product configurations

The launch uses these names as examples, not as separate AOS2 editions:

| Configuration | Typical capabilities |
|---|---|
| **AryaAir / AirTAK** | ADS-B, UAT, GNSS, GDL90 |
| **AryaSea** | AIS and GNSS |
| **AryaUAS** | Wi-Fi/BLE/dedicated Remote ID, DJI DroneID, SiK/MAVLink, SAPIENT |
| **DragonEgg** | LimeSDR, ACARS, broad SoapySDR analysis, and GNSS |

The exact receiver, antenna, power, and regulatory requirements still depend on
The mission and jurisdiction. See [Hardware and requirements](../../get-started/hardware.md).
