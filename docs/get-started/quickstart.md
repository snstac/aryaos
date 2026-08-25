# Quickstart

Get from a blank microSD card to live tracks on a phone in about 15 minutes. This
guide uses the default **Aircraft (ADS-B)** setup. The same first steps
apply to every mission.

!!! tip "What you need"
    - A Raspberry Pi 4 (or 3/5) and a 16 GB+ microSD card ([details](hardware.md)).
    - A USB [SDR](../reference/glossary.md#sdr) dongle and 1090 MHz antenna for ADS-B.
    - A phone or tablet running [ATAK](../reference/glossary.md#atak) (Android) or
      iTAK (iOS), or a computer running WinTAK.
    - A workstation to flash the card.

## 1. Flash the card

The short way, on **Windows or Linux**, is [**AryaOS
Imager**](https://github.com/snstac/aryaos-imager/releases) - a single-purpose build of Raspberry Pi
Imager that offers only AryaOS. It downloads the image and removes the risk of selecting the wrong
operating system.

1. Install [AryaOS Imager](https://github.com/snstac/aryaos-imager/releases).
2. Insert the microSD card, open the imager, and choose
   **AryaOS (latest release)**.
3. Select the card - **this erases it** - then write and let it verify.

On **macOS**, or if you already have the tools, download the latest
`aryaos-*.img.xz` from [GitHub Releases](https://github.com/snstac/aryaos/releases)
and write it with **Raspberry Pi Imager** (choose *Use custom*) or
**balenaEtcher**. There is no macOS build of AryaOS Imager yet.

Do not fill in the OS-customization prompt if one appears. AryaOS sets its own
hostname and hotspot on first boot, and pre-seeding those settings can conflict.

Full instructions, including verification: [Flash the image](flash-the-image.md).

## 2. Boot the box

1. Insert the card, connect the SDR and antenna, and apply power.
2. The first boot takes about **120 seconds** while AryaOS expands its filesystem,
   assigns a unique hostname (`aryaos-xxxx`), and generates its identity. Later
   boots take about 90 seconds.
3. When it is ready, AryaOS broadcasts a Wi-Fi network named **`AryaOS-xxxx`**
   (the same four characters as the hostname).

See [First boot & first login](first-boot.md) for exactly what happens and how to
set your password.

## 3. Connect a device

=== "Phone / tablet (Wi-Fi)"

    1. On the phone, join the **`AryaOS-xxxx`** Wi-Fi network.
    2. The onboarding hotspot is open by default - you can set a
       [WPA2 password](../networking/wifi-hotspot.md) later from the web console.
    3. Open your browser to **`https://aryaos-xxxx.local:9090/`** (accept the
       self-signed certificate warning - the cert is unique to your device).

    !!! note
        If `aryaos-xxxx.local` does not resolve, browse to the gateway IP
        address. The hotspot uses `10.41.0.0/24`, with the gateway at
        `10.41.0.1`.

=== "Computer (Wi-Fi or Ethernet)"

    1. Join the same Wi-Fi network, or plug the Pi into your LAN with Ethernet.
    2. Open **`https://aryaos-xxxx.local:9090/`** in a browser.
    3. Log in as user **`pi`**. On a release image you will be prompted to change
       the default password on first login.

## 4. Point TAK at the gateway

Configure your TAK end-user device to receive **Mesh SA** - the local multicast
CoT stream AryaOS broadcasts by default.

=== "ATAK / iTAK"

    1. **Settings > Network Preferences > Network Connections**.
    2. Ensure **SA Multicast** (Mesh SA) is enabled - this is on by default in
       most builds.
    3. Return to the map. Aircraft appear as they are received.

=== "WinTAK"

    1. Enable multicast SA in **Settings > Network**.
    2. If your network blocks multicast, use a direct feed instead - see
       [Connect to a TAK Server](../deploy/connect-tak-server.md) or the NMEA/GDL90
       options for [ForeFlight & EFBs](../deploy/foreflight-gdl90.md).

## 5. Confirm you see tracks

- In the AryaOS web console, open **AryaOS Site > Sensor services** and confirm
  `adsbcot` and `readsb` are **active**.
- On the TAK map, aircraft icons will appear within a minute if aircraft are in range
  of your antenna. A local ADS-B map is also served on the box (tar1090).

!!! success "You are live"
    You now have a standalone ADS-B-to-TAK gateway. No internet was required.

## Where to next

<div class="grid cards" markdown>

-   :material-airplane: **[Tune the ADS-B setup](../deploy/air-adsb.md)** - decoder choice, UAT, gain, dual SDRs.
-   :material-map-marker-path: **[Other missions](../deploy/index.md)** - maritime, drones, GPS, multi-sensor.
-   :material-server-network: **[Connect a TAK Server](../deploy/connect-tak-server.md)** - forward the picture upstream.
-   :material-application-cog: **[Tour the web console](../admin/index.md)** - everything you can configure.
-   :material-shield-check: **[Harden for the field](../get-started/first-boot.md#secure-the-device)** - passwords, Wi-Fi, VPN.

</div>
