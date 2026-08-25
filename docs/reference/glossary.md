# Glossary

Definitions of the terms used throughout the AryaOS documentation. Each term has a stable anchor so other pages can deep-link to it - for example [`#device_suffix`](#device_suffix) or [`#cot`](#cot).

## ADS-B {#ads-b}

**Automatic Dependent Surveillance-Broadcast.** Aircraft broadcast GPS-derived position,
altitude, velocity, and identity. They usually use **1090 MHz** worldwide or **978 MHz** UAT in the
United States. AryaOS decodes ADS-B and converts it to TAK tracks. See [Aircraft (ADS-B)](../deploy/air-adsb.md).

## AIS {#ais}

**Automatic Identification System.** Vessels broadcast position, course, speed, and identity over
VHF at 161-162 MHz. AryaOS decodes AIS with `ais-catcher` and publishes vessels through AISCOT.
See [Maritime vessels (AIS)](../deploy/maritime-ais.md).

## ATAK {#atak}

**Android Team Awareness Kit.** The Android TAK client (also referred to as ATAK-CIV in its civilian form). One of the TAK end-user devices that displays the tracks AryaOS produces. AryaOS also works with WinTAK, iTAK, TAKX, and TAK Server.

## COTBridge {#cotbridge}

The CoT "ferryman." On AryaOS, COTBridge is the single egress hub. Every local feeder sends CoT to it on `udp+ro://127.0.0.1:28087`. COTBridge forwards to the default [Mesh SA](#mesh-sa) multicast and to any configured [TAK Server](#tak-server) lanes. Its routing lanes are edited in `/etc/cotbridge.ini` via the [COTBridge lane editor](../admin/cotbridge-lanes.md). See [COTBridge](../reference/software-suite.md#cotbridge).

## Cockpit {#cockpit}

The open-source, browser-based server management UI that AryaOS uses as its **single admin surface**. Cockpit serves HTTPS on port 9090 (also reachable through the portal proxy on 443). AryaOS adds a plugin for each gateway plus the "AryaOS Site" plugin. See [AryaOS Site page](../admin/aryaos-site.md).

## COP {#cop}

**Common Operating Picture.** A shared, real-time view of aircraft, vessels, drones, friendly
positions, and other mission data. A COP combines information from multiple sensors. Building a
COP for TAK is a core purpose of AryaOS. See [Multi-sensor COP](../deploy/multi-sensor.md).

## CoT {#cot}

**Cursor on Target.** The XML and Protobuf message format that TAK uses to represent an event.
An event can describe an aircraft, vessel, drone, marker, or friendly position. It includes a
location, type, and time. Every AryaOS gateway produces CoT. Write **Cursor on Target (CoT)** on
the first use in each page.

## cUAS {#cuas}

**Counter-Unmanned Aircraft Systems** (also counter-UAS or C-UAS). Detecting, tracking, and maintaining awareness of drones. On AryaOS the `cuas` [device role](#device_suffix) runs the drone pipelines ([DroneCOT](../reference/software-suite.md), DJICOT, SiKW00FCOT). See [Counter-UAS (drones)](../deploy/counter-uas.md).

## DEVICE_SUFFIX {#device_suffix}

`DEVICE_SUFFIX` is four lowercase hexadecimal characters derived on first boot from the last four
characters of `/etc/machine-id`. Alternatively, from the primary network interface MAC address if
machine-id is unavailable. `aryaos-firstboot.service` writes it to `/etc/aryaos/aryaos-config.txt`
and sets the system hostname to `aryaos-xxxx` (the same `xxxx`).

Used for:

- System hostname: `aryaos-xxxx`
- mDNS name: `aryaos-xxxx.local`
- Comitup Wi-Fi hotspot SSID: `AryaOS-xxxx`
- Default CoT source id: `COT_HOST_ID=aryaos-xxxx`

!!! warning "Do not edit `DEVICE_SUFFIX` after first boot"
    Changing it separates the hostname, mDNS name (`aryaos-xxxx.local`), and captive Wi-Fi SSID.
    Legacy images can contain an unused `NODE_ID=` line in `aryaos-config.txt`. AryaOS no longer
    writes or reads that line.

See [First boot & first login](../get-started/first-boot.md).

## GDL90 {#gdl90}

**GDL90** is the datalink format that electronic flight bags (EFBs) such as ForeFlight consume for traffic and weather. AryaOS's [GDLCOT](../reference/software-suite.md) converts CoT into GDL90 (default UDP port 4000) so aircraft tracks appear directly in an EFB. See [ForeFlight & EFBs (GDL90)](../deploy/foreflight-gdl90.md).

## Mesh SA {#mesh-sa}

**Mesh Situational Awareness.** TAK's serverless, peer-to-peer mode: clients and gateways exchange CoT over a UDP multicast group without a central server. AryaOS's default egress is Mesh SA on multicast `239.2.3.1:6969` (`udp+wo://239.2.3.1:6969`). This lets phones on the hotspot see tracks with no TAK Server required. See [Relay & routing](../deploy/relay-routing.md).

## PyTAK {#pytak}

**Python Team Awareness Kit.** The Python framework that every AryaOS gateway is built on. It handles CoT construction, TAK Server TLS. CoT transport URLs like `udp+wo://` and `tls://`. See [PyTAK docs](https://pytak.readthedocs.io/) and [Software suite](software-suite.md#pytak).

## Remote ID {#remote-id}

The regulatory broadcast standard that drones use to announce identity, position, and operator
location. AryaOS captures Remote ID and DJI DroneID. It publishes drones to TAK through DroneCOT
and DJICOT. See [Counter-UAS (drones)](../deploy/counter-uas.md).

## SDR {#sdr}

**Software-Defined Radio.** A radio whose software performs signal demodulation. AryaOS uses SDRs
for [ADS-B](#ads-b), [UAT](#uat), and [AIS](#ais). It identifies each SDR by its USB serial.
Manage them from [Radios & SDRs](../config/radios-sdr.md).

## TAK {#tak}

**Team Awareness Kit.** A family of situational-awareness applications (ATAK, WinTAK, iTAK, TAKX) and the [TAK Server](#tak-server) that share a common map and the [CoT](#cot) message format. AryaOS is a gateway that feeds sensor data into TAK.

## TAK Server {#tak-server}

The central TAK component that relays CoT, manages users and channels, and issues client TLS
certificates. AryaOS can connect through a data package or `tak://` enrollment link. It can use a
TAK Server with or instead of [Mesh SA](#mesh-sa). See [Connect to a TAK Server](../deploy/connect-tak-server.md).

## UAT {#uat}

**Universal Access Transceiver.** The **978 MHz** datalink used by some US aircraft (typically below 18,000 ft) as an alternative to 1090 MHz [ADS-B](#ads-b). AryaOS decodes UAT with `dump978-fa` on a dedicated SDR serialized `stx:978:0`. See [Aircraft (ADS-B)](../deploy/air-adsb.md).

## See also

<div class="grid cards" markdown>

- :material-package: **Software suite** - Every gateway and plugin. [Software suite](software-suite.md)
- :material-lan: **Ports & protocols** - Where these protocols listen. [Ports & protocols](ports.md)
- :material-file-document: **Specifications** - Standards and identity. [Specifications](../specs.md)

</div>
