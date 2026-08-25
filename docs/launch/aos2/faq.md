# AryaOS 2 launch FAQ

## What is AryaOS 2?

AryaOS 2 is an arm64 operating-system image that turns a Raspberry Pi into a multi-sensor gateway
for the Team Awareness Kit ecosystem. It receives local aircraft, vessel, drone, radio. GNSS
information. Converts or routes it as Cursor on Target for ATAK, WinTAK, iTAK, TAKX, or TAK Server.

It is the complete rewrite of AryaOS 1 and the AirTAK lineage. The first stable
AOS2 artifact is `v2.1.19`. “AryaOS 2” is the public generation name.

## Is it available now?

Yes. Use [AryaOS Imager](https://github.com/snstac/aryaos-imager/releases) or
download the stable image from the
[v2.1.19 GitHub release](https://github.com/snstac/aryaos/releases/tag/v2.1.19).
Do not field an image whose tag ends in `-dev`. Development images contain lab
access and are published as prereleases.

## Is AryaOS free or subscription-based?

AryaOS is open source under the Apache License 2.0. It does not require a cloud service or
subscription. Sensors & Signals also offers assembled hardware for teams that do not want to source.
Integrate their own Raspberry Pi, radios, antennas, GPS, power, and enclosure.

## Which computers are supported?

The downloadable image is arm64 and is tested on Raspberry Pi 3, 4, and 5.
Raspberry Pi 5 is recommended for multi-sensor builds. Pi 4 is the most common
field platform. Pi 3 is appropriate for lighter single-sensor use.

An amd64 image does not ship today. Individual gateway packages can run on
Debian amd64 systems, but that is not the same as a supported AryaOS appliance
image.

## Can I upgrade an AryaOS 1 card in place?

No. AryaOS 2 is a full rewrite and moves the base system from Debian Bookworm
to Trixie. Back up the information you need, flash a new card, boot AOS2 with
The receivers attached, and re-import or re-enroll the TAK connection.

Do not try to transplant the complete v1 filesystem or apt sources into AOS2.

## What should I save before replacing v1?

- The TAK Server hostname, port, and protocol.
- An authorized copy of the TAK connection package or enrollment information.
- Client certificate, key, and CA material you are authorized to retain.
- Callsigns, static position, custom gateway settings, and tuned radio values.
- Custom Node-RED flows and credentials.
- Any locally recorded data that must be retained.

The AOS2 backup helper cannot run retroactively on a v1 image. Preserve v1
settings with the tools available on that system, then recreate or import them
through the AOS2 web console.

## What happens on first boot?

AryaOS expands the filesystem, generates a unique device suffix, hostname,
hotspot SSID, CoT host identity, and web TLS certificate, then examines the
attached hardware. Supported capabilities are enabled conservatively. Ambiguous
or competing devices are reported for operator review instead of being guessed.

On a release image, the published bootstrap password must be changed at the
first login.

The onboarding hotspot is open by default so a new box remains reachable.
Set a unique WPA2 hotspot password from the AryaOS Site page before fielding it.

## Does every sensor start automatically?

No. AOS2 ships optional sensor services disabled. The first-boot capability
scan enables receivers it can identify safely. Operators can then choose exact
capabilities or apply an air, maritime, C-UAS, multi-sensor, or relay role.

Network-only sensors such as SAPIENT are not auto-detected. One SDR also cannot
decode several frequencies simultaneously. Add receivers or retask the one you
have.

## Which signals can it receive?

Depending on attached hardware and configuration:

- ADS-B on 1090 MHz and UAT on 978 MHz.
- marine AIS.
- ASTM Remote ID over Wi-Fi and Bluetooth.
- Remote ID through a dedicated MAVLink receiver such as DroneScout.
- DJI DroneID through a compatible AntSDR integration.
- SiK/MAVLink telemetry.
- SAPIENT BSI Flex 335 reports.
- position-bearing ACARS messages.
- APRS over local RF.
- GNSS position and time.

It can also convert CoT aircraft tracks into GDL90 for ForeFlight and other
electronic flight bags.

The packaged APRS RF default is 144.39 MHz for North America. Operators in
other regions must use the locally authorized frequency and configuration.

## Does the “55-mile” result mean every AOS2 system has that range?

No. It records one San Diego backpack test using a tuned ADS-B setup and no
internet connection. RF range depends on the receiver, antenna, frequency,
mounting height, terrain, interference, and transmitter. It demonstrates the
offline operating concept, not a guaranteed specification.

## Does AryaOS need the internet?

No for local sensing, Mesh SA, onboarding, administration, local documentation,
GNSS, and TAK operation among nearby devices. Internet or another backhaul is
needed for a remote TAK Server, Tailscale, package updates, and online feeds.

## Does it include a TAK Server?

No. Bundled CloudTAK was removed. AryaOS can use Mesh SA locally. It can connect
to a TAK Server through a package, an enrollment URL, or a COTBridge lane.

## What is COTBridge?

COTBridge is the local CoT hub. Sensor gateways write to a private loopback bus,
and COTBridge forwards that combined stream through named lanes. The default
`site-output` lane targets Mesh SA or the TAK Server selected in the AryaOS Site
page. Additional lanes can bridge other networks or record selected traffic.

## Can one node send to Mesh SA and TAK Server at the same time?

Yes. Add separate COTBridge egress lanes. Avoid pointing each local sensor at
The same upstream independently, which creates duplicated configuration and can
duplicate traffic.

## Is all administration really browser-based?

Routine onboarding, network, role, TAK, TLS, gateway, service, update, support,
backup, lifecycle, and radio operations have browser interfaces. Specialist
work such as spectrum surveys, prebuilt track queries, and some SDR demodulation
or sharing controls remains command-line oriented.

## What happened to Node-RED?

Node-RED remains installed for optional low-code automation. It is no longer
The system configuration surface or a dependency of the landing page. It runs
as an unprivileged account, starts with empty flows, listens on loopback, and is
served through the HTTPS proxy at `/nr/`. Legacy example flows can be imported
manually.

Rotate the Node-RED admin password before fielding a unit.

## How do nearby AryaOS boxes find each other?

Each node adds a structured `__aryaos` detail block to its CoT host beacon. A
local listener caches those Mesh SA beacons, and the web console shows each
neighbor's hostname, roles, capabilities, health, position, age, and admin link.
No cloud inventory service is required.

## What is EMCON mode?

EMCON persistently rfkill-blocks onboard Wi-Fi and Bluetooth before the network
stack starts. Wired Ethernet remains available. Receive-only SDR sensor services
continue because they are not RF emitters. stop or unplug them if the mission
also requires removing receiver power.

## Is Bluetooth PAN a route to the upstream network?

No. Bluetooth PAN gives a paired client a local address for reaching AryaOS.
Like the Wi-Fi onboarding zone, it does not NAT, bridge, or forward the client
onto the wired network.

## What does zeroize guarantee?

Zeroize removes operational configuration, TAK targets and TLS material, authorized SSH keys, shell
histories, recorded tracks, local support/backup files. Usable local login credentials before
restoring clean defaults and rebooting.

It is best-effort on SD and NVMe flash. Wear leveling means filesystem overwrite
and TRIM cannot guarantee that every prior physical flash cell is unrecoverable.
AryaOS 2 does not claim crypto-erase or certified forensic destruction.

## Is AryaOS 2 FIPS validated or STIG compliant?

No. The image includes significant appliance hardening and documents a FIPS/STIG
roadmap, but roadmap work is not certification. Do not represent AOS2 as FIPS
validated or STIG compliant.

## Does AOS2 include a unified browser map and track replay?

Not yet. AOS2 fuses its sensor data into TAK, provides local ADS-B and status
views, and can record/query/export selected CoT lanes. A native all-sensor web
COP and integrated browser replay workflow remain roadmap items.

## Where should I start?

- [Fifteen-minute quickstart](../../get-started/quickstart.md)
- [Hardware and requirements](../../get-started/hardware.md)
- [Flash the image](../../get-started/flash-the-image.md)
- [Choose a deployment](../../deploy/index.md)
- [Complete AOS2 feature comparison](feature-matrix.md)
