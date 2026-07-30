<img src="docs/brand/logo/mark-aryaos.svg" width="160" height="160" alt="AryaOS Signal Block mark">

# AryaOS — the situational awareness operating system for TAK

AryaOS turns an inexpensive single-board computer into a turn-key sensor gateway. It listens to
the radio traffic around it — aircraft, vessels, drones, radios — and puts what it hears onto any
[TAK](https://www.aryaos.org/reference/glossary/#tak) device as
[Cursor on Target](https://www.aryaos.org/reference/glossary/#cot): ATAK, WinTAK, iTAK, TAKX, or a
TAK Server.

No cloud. No subscription. No command line. Flash a card, boot the box, connect a phone —
everything else is configured from a touch-friendly web console.

[**Get started in 15 minutes →**](https://www.aryaos.org/get-started/quickstart/)

## What you can build with it

| Mission | What AryaOS does |
|---------|------------------|
| **Aerial firefighting & wildland fire** | Puts the local ADS-B and UAT air picture in front of crews on the ground, with no dependence on connectivity. The original AirTAK use case, funded by the Colorado Center of Excellence and the USDA Forest Service. |
| **Search & rescue** | A backpack-sized node that broadcasts its own Wi-Fi and shares aircraft, vessel, and team position with every phone in range. |
| **Maritime domain awareness** | Live vessel traffic from an over-the-air AIS receiver or an online feed. |
| **Counter-UAS & airspace security** | Detects drones by Remote ID (Wi-Fi and Bluetooth), DJI DroneID, and purpose-built receivers — reporting the aircraft *and* the operator's location. |
| **Range & site security** | A fixed multi-sensor node fusing air, maritime, and drone feeds into a single common operating picture. |
| **CoT relay & bridging** | Moves Cursor on Target between isolated networks, radios, and a TAK Server. |
| **Electronic flight bag** | Feeds ADS-B traffic to ForeFlight and other GDL 90 apps. |

## What it can hear

Capabilities are named after the signal, not after a product — `adsb`, `ais`,
`wifi-rid`, `ble-rid`, `rid`, `dji`, `sik`, `sapient`. They are exactly the names
you type, the names the box reports, and the names on the map.

Each capability is a receiver AryaOS turns into TAK tracks. The image ships with every sensor
**switched off**; on first boot the box works out what is actually plugged in and enables what it
finds, then reports anything it could do but did not turn on — so you always know what the hardware
is capable of.

| Capability | Enable with | What appears on the map | Hardware needed |
|------------|-------------|-------------------------|-----------------|
| **ADS-B / UAT** | `adsb` | Crewed aircraft on 1090 MHz and 978 MHz | **SDR** — RTL-SDR, or any SoapySDR device |
| **AIS** | `ais` | Ships and vessels | dAISy NMEA receiver, or a spare **SDR** |
| **Remote ID** — Wi-Fi | `wifi-rid` | ASTM F3411 Remote ID over 802.11, plus operator location | Monitor-mode Wi-Fi adapter (e.g. Atheros AR9271) |
| **Remote ID** — Bluetooth | `ble-rid` | ASTM F3411 Remote ID over Bluetooth LE | **None** — the board's own radio |
| **Remote ID** — receiver | `rid` | Remote ID via a dedicated receiver, over **MAVLink** | BlueMark DroneScout DS110 |
| **DJI DroneID** | `dji` | DJI aircraft and the pilot's position | AntSDR E200 |
| **MAVLink telemetry** | `sik` | Drone telemetry from a SiK radio | SiK / SiKW00F radio |
| **SAPIENT C-UAS** | `sapient` | Counter-UAS sensors speaking BSI Flex 335 | Networked sensor |

Two things are **not** capabilities, because they are not optional receivers:
**GPS** (a USB receiver, shared with every connected device via gpsd) and
**APRS** (an RTL-SDR plus Dire Wolf, configured on its own). Both are documented
under configuration.

Mix them freely: one box can run an air picture and a drone picture at once, and tells you when two
capabilities want the same radio.

## Why teams choose it

* **Works with every TAK product** — ATAK, WinTAK, iTAK, TAKX, and TAK Server, over the open
  Cursor on Target standard.
* **Runs offline.** Boots on a Raspberry Pi, broadcasts its own Wi-Fi, and needs no internet to put
  a picture on a phone in a backpack.
* **Quiet by default.** A stock image ships with every sensor disabled and only starts what the
  attached hardware supports, so a box with no radios is a working TAK node rather than a wall of
  errors.
* **No terminal required.** Network, radios, TAK certificates, VPN, updates, and diagnostics all
  live in the browser.
* **Open source, end to end.** Every gateway is built on [PyTAK](https://github.com/snstac/pytak)
  and licensed Apache 2.0.
* **Inexpensive, low SWaP-C hardware.** Built for Arm (arm64) single-board computers such as the
  Raspberry Pi 4 and 5. Intel/amd64 support is planned
  ([#129](https://github.com/snstac/aryaos/issues/129)) — the full gateway suite already installs on
  any Debian host from the [signed apt repository](https://snstac.github.io/packages).

## AryaOS Software Suite

AryaOS ships with the full [Sensors & Signals](https://www.snstac.com) open-source suite of Team Awareness Kit (TAK) gateways and Cursor on Target (CoT) tools:

| Project | What it does |
|---------|--------------|
| [PyTAK — Python Team Awareness Kit (TAK) library](https://github.com/snstac/pytak) | Python framework for building TAK & Cursor on Target (CoT) integrations. ([PyTAK documentation](https://pytak.readthedocs.io/)) |
| [ADSBCOT — ADS-B to TAK gateway](https://github.com/snstac/adsbcot) | Displays live aircraft from ADS-B receivers in ATAK, WinTAK & iTAK. ([ADSBCOT documentation](https://adsbcot.readthedocs.io/)) |
| [AISCOT — AIS to TAK gateway](https://github.com/snstac/aiscot) | Displays ships & maritime vessel traffic from AIS in TAK. ([AISCOT documentation](https://aiscot.readthedocs.io/)) |
| [DroneCOT — Drone Remote ID to TAK gateway](https://github.com/snstac/dronecot) | Detects & tracks drones (Remote ID / Open Drone ID) in TAK for counter-UAS awareness. |
| [AIRCOT — aircraft classification for TAK](https://github.com/snstac/aircot) | Classifies aircraft into TAK/CoT types from ADS-B & Mode S data. ([AIRCOT documentation](https://aircot.readthedocs.io/)) |
| [DJICOT — DJI drone detection for TAK](https://github.com/snstac/djicot) | Detects & tracks DJI drones (DroneID) in TAK. ([DJICOT documentation](https://djicot.readthedocs.io/)) |
| [GPSTAK — network GPS for TAK](https://github.com/snstac/gpstak) | Streams gpsd position data to TAK as CoT, with NMEA fan-out for WinTAK. |
| [LINCOT — Linux GPS to TAK gateway](https://github.com/snstac/lincot) | Sends Linux device position (GPS) to TAK. |
| [APRSCOT — APRS to TAK gateway](https://github.com/snstac/aprscot) | Displays amateur radio APRS stations in TAK. ([APRSCOT documentation](https://aprscot.readthedocs.io/)) |
| [INRCOT — Garmin inReach to TAK gateway](https://github.com/snstac/inrcot) | Displays Garmin inReach satellite tracker positions in TAK. |
| [SiKW00FCOT — MAVLink drone telemetry to TAK](https://github.com/snstac/sikw00fcot) | Converts SiK-radio MAVLink drone telemetry to Cursor on Target. |
| [CharonTAK — Cursor on Target ferryman](https://github.com/snstac/charontak) | Bridges & relays CoT between networks and TAK servers. |
| [QRTAK — TAK onboarding with QR codes](https://github.com/snstac/qrtak) | Onboard devices to TAK Server by scanning a QR code. |

Every gateway on AryaOS is managed from a touch-friendly browser UI built on [Cockpit](https://cockpit-project.org/), including [cockpit-aryaos](https://github.com/snstac/cockpit-aryaos), [cockpit-adsbcot](https://github.com/snstac/cockpit-adsbcot), [cockpit-aiscot](https://github.com/snstac/cockpit-aiscot), [cockpit-dronecot](https://github.com/snstac/cockpit-dronecot), [cockpit-gpstak](https://github.com/snstac/cockpit-gpstak) & [cockpit-lincot](https://github.com/snstac/cockpit-lincot).

## Development (contributors & agents)

| Topic | Doc |
|-------|-----|
| Image build (Docker pi-gen) | [docs/build.md](docs/build.md), [AGENTS.md](AGENTS.md) |
| Lab Pi sync & portal deploy | [docs/dev-pi.md](docs/dev-pi.md), [docs/portal.md](docs/portal.md) |
| Runtime / SDR / readsb | [docs/config.md](docs/config.md) |

**Quick lab portal update** (from repo root, SSH to `aryaos-dev-pi`):

```bash
ARYAOS_SSH=aryaos-dev-pi ./scripts/sync-portal-review.sh
```

Agent handoff and open tasks: [docs/agent-handoff.md](docs/agent-handoff.md).

# Stakeholders

This work is funded by the [Colorado Center of Excellence for Advanced Technology Aerial Firefighting](https://www.cofiretech.org/feature-projects/team-awareness-kit-tak) and the [USDA Forest Service (USFS)](https://www.fs.usda.gov/managing-land/fire).

<p>
<a href="https://www.cofiretech.org/feature-projects/team-awareness-kit-tak"><img src="https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/3eaaf2d1-60d4-4883-b944-8a02f1836664/coe+logo.png?format=105" width="140" height="auto" alt="Colorado Center of Excellence logo"></a>
&nbsp;
<img src="https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/f72561b6-0cf4-4b7f-ac41-75d4bbc076d8/Logo_of_the_United_States_Department_of_Agriculture.svg.png?format=100" width="120" height="auto" alt="USDA logo">
&nbsp;
<img src="https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/61bde71a-14a1-455c-a8ef-90ba685f27c7/Logo_of_the_United_States_Forest_Service.svg+%281%29.png?format=100" width="120" height="auto" alt="US Forest Service logo">
</p>

# License & Copyright

Copyright [Sensors & Signals LLC](https://www.snstac.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
