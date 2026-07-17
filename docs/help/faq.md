# FAQ

Short answers to the questions we hear most, each linking to the page with the full story. If something is broken rather than unclear, start with [Troubleshooting](../troubleshooting.md).

## Getting started

??? question "Do I need internet to use AryaOS?"
    No. AryaOS is designed for disconnected operation — no LTE, no Wi-Fi backhaul. Pair a TAK device to the onboarding hotspot and you see live tracks over local Mesh SA with nothing else connected. Internet is only needed to reach a remote TAK Server or to fetch updates. See [Disconnected / backpack ops](../deploy/offline-backpack.md).

??? question "Which Raspberry Pi do I need?"
    A Raspberry Pi 3, 4, or 5 (`arm64`), with a 16 GB+ microSD card (32 GB recommended). The Pi 4 is the common field build; the Pi 5 has the most headroom. See [Hardware & requirements](../get-started/hardware.md).

??? question "Is amd64 (Intel) supported?"
    Not as an image yet — AryaOS images are `arm64` only today ([#129](https://github.com/snstac/aryaos/issues/129)). But the full gateway suite already installs on any Debian host, including `amd64`, from the [signed apt repository](https://snstac.github.io/packages).

??? question "Can I buy one already assembled?"
    Yes. The [AirTAK go-kit](../purchase.md) ships assembled, tested, and pre-flashed with AryaOS.

## First boot & login

??? question "What is the default password?"
    AryaOS images ship with a publicly known default password for user `pi`. On release images it **expires at first login**, so you must set a new one immediately. See [First boot & first login](../get-started/first-boot.md).

??? question "How do I connect to a new device?"
    Wait ~120 seconds for first boot, join the Wi-Fi network `AryaOS-xxxx`, and open `https://aryaos-xxxx.local` (or `10.41.0.1`). See [First boot & first login](../get-started/first-boot.md).

??? question "Why does my browser warn about the certificate?"
    Each device generates its own self-signed TLS certificate on first boot, so the warning is expected. Proceed to the site. See [Security posture](../security.md).

## Using it

??? question "How do I see aircraft/vessels/drones in TAK?"
    Pick your sensor's mission page — [Aircraft (ADS-B)](../deploy/air-adsb.md), [Maritime (AIS)](../deploy/maritime-ais.md), or [Counter-UAS (drones)](../deploy/counter-uas.md) — attach the right radio and antenna, set the [device role](../config/device-roles.md), and the tracks flow to TAK over Mesh SA. If nothing shows up, see [Troubleshooting](../troubleshooting.md).

??? question "How do I connect AryaOS to a TAK Server?"
    Import your TAK connection **data package** or a `tak://` **enrollment link** from the TAK connection card in **Cockpit → AryaOS Site**. AryaOS installs the certificates and adds a CharonTAK egress lane to the server. See [Connect to a TAK Server](../deploy/connect-tak-server.md).

??? question "How do I show tracks in ForeFlight or another EFB?"
    AryaOS converts CoT to GDL90 via GDLTAK (UDP 4000). Point your EFB at the device. See [ForeFlight & EFBs (GDL90)](../deploy/foreflight-gdl90.md).

??? question "How do I change SDR serial numbers?"
    From **Cockpit → AryaOS Site → Radios**, or run `sudo aryaos-sdr set-serial 0 stx:1090:0`. Replug the dongle (or reboot) afterward. See [Radios & SDRs](../config/radios-sdr.md) and [`aryaos-sdr`](../reference/cli-helpers.md#aryaos-sdr).

??? question "What's the difference between the device roles?"
    Roles select which sensor pipelines run: `multi` (all), `air` (ADS-B/UAT), `maritime` (AIS), `cuas` (drones), `relay` (routing only). The CoT core always runs. Set it in **Cockpit → AryaOS Site → Device role**. See [Device roles](../config/device-roles.md).

## Operating & maintaining

??? question "How do I update AryaOS?"
    Use **Cockpit → AryaOS Site → Software updates** (it keeps running even if you close the browser), or run `sudo aryaos-update apply`. Everything comes from the [signed apt repository](https://snstac.github.io/packages). See [Updates](../operations/updates.md).

??? question "How do I get logs to send to support?"
    Generate a support bundle from **Cockpit → AryaOS Site → Support bundle**, or run `sudo aryaos-support-bundle`. Secrets are automatically redacted. See [Support bundles](../operations/support-bundles.md).

??? question "Do I have to use SSH?"
    No. Everything is available from the Cockpit web admin. SSH is optional and hardened (no root login, `fail2ban`). See [CLI helpers](../reference/cli-helpers.md).

??? question "How do I secure the Node-RED editor?"
    Rotate its default admin password immediately — the editor can run arbitrary code. Use **Cockpit → AryaOS Site → Node-RED admin password** or `aryaos-set-nodered-password`. See [Node-RED dashboard](../node-red.md).

??? question "How do I reach the device remotely?"
    Join it to Tailscale from **Cockpit → AryaOS Site → VPN**. See [VPN (Tailscale)](../networking/vpn-tailscale.md).

??? question "Can I connect over Bluetooth instead of Wi-Fi?"
    Yes. AryaOS runs a Bluetooth PAN (`10.44.0.1/24`); pair a phone and reach AryaOS services over the PAN link. See [Bluetooth PAN](../bluetooth-pan.md).

## See also

<div class="grid cards" markdown>

- :material-help-circle: **Troubleshooting** — When something is broken. [Troubleshooting](../troubleshooting.md)
- :material-book-open: **Glossary** — Terms and acronyms. [Glossary](../reference/glossary.md)
- :material-rocket-launch: **Get started** — From zero to first track. [Overview](../get-started/overview.md)

</div>
