<img src="https://aryaos.readthedocs.io/en/latest/media/aryaos_logo-25p.png" width="160" height="160" alt="AryaOS logo">

# AryaOS - The Operating System for Modern Situational Awareness

AryaOS is a Linux-based operating system with a suite of situational awareness tools pre-installed.

Features of AryaOS:

* Includes decoders and gateways for [AIS](https://github.com/snstac/aiscot), [ADS-B](https://github.com/snstac/adsbcot) & [Drone Remote ID](https://github.com/snstac/dronecot).
* Works with all TAK Products, including ATAK, WinTAK, iTAK, TAKX & TAK Server.
* Facilitates rapid test & evaluation of edge node sensors.
* Browser based low-code development tool for visual programming & open API.
* Runs on inexpensive COTS & low SWaP-C small board computers, including the Raspberry Pi.
* Compatible with Intel & Arm (amd64 & arm64) architectures.

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
