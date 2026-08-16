# AryaOS 2: from sensor gateway to field platform

**AryaOS 2 is here. The operating system that began as AirTAK has been rebuilt
into a self-configuring, multi-sensor, fleet-ready edge platform for TAK.**

In a disconnected backpack test in San Diego, an AryaOS air node delivered a
live aircraft picture from as far as 55 miles away without an internet
connection. That original idea remains at the center of AryaOS 2: put useful
local information in front of the people who need it, even when the cloud and
the backhaul are gone.

What changed is everything around it.

AryaOS 1 proved that an inexpensive Raspberry Pi could turn ADS-B aircraft,
AIS vessels, Remote ID drones, and APRS traffic into Cursor on Target. AryaOS 2
takes the next step. One image can now discover its attached hardware, select
the right sensor pipelines, route their data through a resilient CoT hub, join
a TAK Server, report its own health and position, and support an entire field
lifecycle from a touch-friendly browser.

This is not a collection of scripts with a dashboard. It is an operating
platform for building and operating a Common Operating Picture.

[Flash AryaOS 2](https://www.aryaos.org/get-started/flash-the-image/){ .md-button .md-button--primary }
[Build or buy a gateway](https://www.aryaos.org/get-started/hardware/){ .md-button }

## One image, many missions

AryaOS 2 is capability-first. Attach the receivers a mission needs and the box
works out what it can do.

- **Wildland fire and aviation:** receive ADS-B on 1090 MHz and UAT on 978 MHz,
  classify aircraft, send the picture to TAK, and rebroadcast it as GDL90 for
  ForeFlight and other electronic flight bags.
- **Search and rescue:** carry the node in a backpack, connect over its own
  Wi-Fi or local Bluetooth PAN, share the box's GNSS fix, and keep operating
  without internet service.
- **Maritime awareness:** receive AIS from a dAISy-style serial receiver or an
  SDR and turn vessel traffic into native TAK tracks.
- **Counter-UAS:** receive ASTM Remote ID over Wi-Fi, Bluetooth, or a dedicated
  DroneScout receiver; receive DJI DroneID through AntSDR; and ingest MAVLink
  or SAPIENT sensor reports.
- **Multi-sensor sites:** combine aircraft, vessel, drone, radio, and ownship
  data in one TAK picture.
- **Relay nodes:** move CoT between local networks, Mesh SA, and TAK Server even
  when no sensor is attached.

AryaAir, AryaSea, AryaUAS, and DragonEgg are examples of those configurations.
They share one AryaOS 2 foundation instead of becoming separate operating
systems.

## It configures itself, carefully

A stock AryaOS 2 image starts quiet. Every optional sensor is disabled until
the first-boot capability scan finds hardware that can support it. A bare box
therefore boots as a healthy TAK node instead of producing a screen full of
failed radio services.

Discovery is based on evidence, not wishful matching. AryaOS can distinguish
GPS and AIS data by protocol, validate a DroneScout's MAVLink frames, identify
an ADSBee instead of treating every Raspberry Pi Pico as one, and preserve
stable device paths across reboots. If one SDR could serve two roles, AryaOS
reports the conflict instead of silently letting two decoders fight for it.

Operators can switch among air, maritime, counter-UAS, multi-sensor, and relay
roles from the web console. Advanced users can retask an SDR between ADS-B,
UAT, AIS, and APRS; survey spectrum occupancy; demodulate narrowband FM or
experimental AM; or share a receiver over a trusted network.

## One CoT hub, every destination

In AryaOS 1, gateways were largely independent producers. AryaOS 2 routes the
local sensor suite through COTBridge. Feeders write to a private local bus;
COTBridge owns the external lanes.

That architecture makes one box useful in several ways at once. The same local
picture can go to Mesh SA, a TAK Server, another network, or a recording lane
without reconfiguring each sensor. The structured lane editor validates CoT
URLs, TLS settings, UDP direction, and bind conflicts before applying them.

Connecting a TAK Server no longer means provisioning every gateway by hand.
Import an ATAK/iTAK connection package or paste a one-time `tak://` enrollment
URL. AryaOS installs the shared client credentials, validates the server
identity, and updates the COTBridge output lane as one operation.

The current PyTAK and COTBridge stack also recovers in process from transient
network and firewall failures. A temporary TAK outage degrades the lane and
starts a bounded retry; it does not have to turn into a systemd restart loop.

## A field console, not a configuration file

Routine operation happens in the browser.

The HTTPS landing page is a glanceable command deck for sensor state, CoT
connectivity, GNSS fix, accuracy and integrity warnings, CPU temperature, load,
power health, and attached radios. Cockpit provides the authenticated admin
surface for:

- device roles and detected capabilities;
- TAK destinations, enrollment, and shared TLS credentials;
- COTBridge lanes and individual gateway configuration;
- Wi-Fi, hotspot protection, Bluetooth PAN, and Tailscale;
- radio assignment, EMCON, and safe-mode recovery;
- software updates, backups, support bundles, reset, and zeroize; and
- nearby AryaOS nodes, including their health, roles, position, and admin link.

Node-RED remains available for custom automation, but it is no longer in the
critical path. It starts with empty flows, runs as an unprivileged user, binds
to loopback, and is reached through the authenticated HTTPS surface.

## Designed for the disconnected edge

AryaOS 2 carries its own network and its own operating information.

When no known Wi-Fi is available, it broadcasts a uniquely named onboarding
hotspot. A paired device can also reach the box over a local-only Bluetooth PAN.
Neither onboarding path routes a user onto the wired network. Tailscale provides
the remote path when backhaul is available, and persistent EMCON can block both
onboard transmitting radios before the network stack comes up.

GNSS can discipline the box's clock and make it a local time source. GPSCOT can
give a connected ATAK or WinTAK device a network position fix. The documentation
ships on the image, and the box can download a copy of its own release image for
an offline recovery kit.

No cloud is required. No subscription is required. Routine setup and operation
do not require a shell.

## Built for day two

The largest AOS2 changes appear after the first successful mission.

- **One-click updates** combine the signed Sensors & Signals package repository
  with Debian security updates. Update jobs continue if the browser closes.
- **Support bundles** collect system, service, radio, network, and package state
  while redacting passwords and tokens and excluding private TLS keys.
- **Backup and restore** preserve site, gateway, network, Node-RED, decoder, and
  certificate configuration; a no-secrets mode creates a shareable copy.
- **Factory reset** returns the appliance to packaged defaults without requiring
  a reflash.
- **Zeroize** removes operational configuration, credentials, keys, histories,
  and recorded tracks before restoring a clean bootstrap state.
- **Local CoT recording** can retain selected lanes for later query, CSV export,
  coverage analysis, dropout review, or secure purge.
- **Nearby-node discovery** lets a group of AryaOS boxes find and report one
  another on Mesh SA without a central inventory service.

Zeroize is intentionally described as best-effort on flash media. Wear leveling
means overwrite and TRIM cannot provide the same guarantee as destroying an
encryption key or the physical device.

## Hardened and tested as an appliance

Release images expire the bootstrap password at first login, prohibit root SSH,
limit authentication attempts, enable fail2ban, apply sysctl hardening, and use
a firewalld allowlist. Each device creates its own web TLS key on first boot.
Untrusted CoT parsers are bounded and sandboxed, TAK package import requires
authentication, and Node-RED does not own TAK credentials.

The core gateway stack and AryaOS overlay are delivered through the signed
Sensors & Signals package repository, and each image release publishes SPDX and
CycloneDX software bills of materials. The release pipeline mounts the finished
image and verifies its packages, units, files, permissions, security mode, and
version floors before publication.

The closing AOS2 candidate was then exercised on a four-node hardware fleet
covering ADS-B, AIS, Remote ID, ACARS, GNSS, TAK enrollment, backup and restore,
support bundles, reset behavior, and real service health. Load testing delivered
5,000 generated CoT events per node at roughly 675 events per second with zero
COTBridge write errors. Longer soak testing recorded no failed units,
throttling, probe failures, or automatic core-service restart growth.

Those figures are release evidence, not a performance guarantee for every
hardware and network combination. They show the standard AryaOS 2 expects of
itself: validate the whole appliance, not just each package in isolation.

## Moving from AryaOS 1

AryaOS 2 is a complete operating-system rewrite based on Debian Trixie. Moving
from an AryaOS 1 device requires a fresh flash; there is no supported in-place
upgrade.

Before reflashing, record the existing TAK destination, save any connection
package and certificate material you are authorized to retain, and export any
Node-RED flows or local data you need. After installing AOS2, let first boot
detect the hardware, change the bootstrap password, and use the TAK connection
card to import or enroll again.

Other important changes:

- Tailscale replaces ZeroTier for optional remote access.
- COTBridge replaces direct per-sensor external routing with a shared hub and
  output lanes.
- Cockpit replaces Node-RED as the system administration surface.
- Bundled CloudTAK was removed; connect AOS2 to an existing TAK Server or use
  Mesh SA.
- Private dhbridge and kraktak components are not part of the public image.
- The downloadable image is arm64 for Raspberry Pi 3, 4, and 5. An amd64 image
  remains future work.

## Available now

AryaOS 2 is open source under the Apache License 2.0. The stable `v2.1.19`
release is available through AryaOS Imager and GitHub Releases. Teams can build
their own Raspberry Pi gateway or start with an assembled AirTAK configuration.

[Flash AryaOS 2](https://www.aryaos.org/get-started/flash-the-image/){ .md-button .md-button--primary }
[Choose hardware](https://www.aryaos.org/get-started/hardware/){ .md-button }
[View the complete v1 comparison](feature-matrix.md){ .md-button }

AryaOS is developed by [Sensors & Signals LLC](https://www.snstac.com/), with
support from the
[Colorado Center of Excellence for Advanced Technology Aerial Firefighting](https://www.cofiretech.org/feature-projects/team-awareness-kit-tak)
and the [USDA Forest Service](https://www.fs.usda.gov/).
