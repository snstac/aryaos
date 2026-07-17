# First boot & first login

What happens the first time an AryaOS device powers on, how to connect and log in, and — importantly — how to secure the unit before you field it.

## The first-boot sequence (~120 seconds)

A brand-new AryaOS device runs `aryaos-firstboot.service` once, on its first power-on. This takes about **120 seconds**; every boot after that takes about **90 seconds**. During first boot the device:

1. **Resizes its filesystem** to fill the whole microSD card.
2. **Derives [`DEVICE_SUFFIX`](../reference/glossary.md#device_suffix)** — four lowercase hex characters taken from the last four characters of `/etc/machine-id` (or the primary NIC MAC if machine-id is unavailable).
3. **Sets the hostname** to `aryaos-xxxx`, where `xxxx` is the `DEVICE_SUFFIX`. This is also the mDNS name `aryaos-xxxx.local`.
4. **Names the Wi-Fi hotspot** `AryaOS-xxxx` (same suffix) via comitup.
5. **Stamps the CoT source id** `COT_HOST_ID=aryaos-xxxx`, used in Cursor on Target (CoT) flow-tags and remarks.
6. **Regenerates a per-device web TLS certificate** for the portal and Cockpit HTTPS proxy, so every unit has its own certificate rather than the shared build-time one.
7. **Expires the default `pi` password** on release images, forcing a password change at first login (see [Secure the device](#secure-the-device)).

All of this is written to the site config at `/etc/aryaos/aryaos-config.txt`.

!!! warning "Do not edit `DEVICE_SUFFIX` by hand"
    `DEVICE_SUFFIX` ties together the hostname, the mDNS name (`aryaos-xxxx.local`), and the hotspot SSID. Changing it after first boot desynchronizes those. See [`DEVICE_SUFFIX`](../reference/glossary.md#device_suffix) in the glossary.

## LED behavior

Within a few seconds of applying power, an AryaOS device flashes its **green and red** LEDs as it starts up. Give a new device the full ~120 seconds before expecting the hotspot to appear.

## Connect to the device

Once first boot completes, the device brings up an onboarding Wi-Fi hotspot.

1. On your phone or laptop, look for a Wi-Fi network named **`AryaOS-xxxx`** (the `xxxx` matches the hostname).
2. Join it. On current images the onboarding hotspot is **open by default** until you set a password (see below).
3. Open the web admin at **`https://aryaos-xxxx.local`** (or the hotspot gateway IP `10.41.0.1`).

!!! note "Untrusted-certificate warning is expected"
    The per-device certificate generated on first boot is self-signed, so your browser warns about it. That is expected on a fresh device; proceed to the site. See [Security posture](../security.md).

Other ways to reach the box are covered in [Wi-Fi & onboarding hotspot](../networking/wifi-hotspot.md) and [Bluetooth PAN](../bluetooth-pan.md).

## First login

Log in as user **`pi`** with the published default password for AryaOS images.

!!! danger "The default password is public"
    Because the default `pi` password ships in every published image, release images **expire it at first login** — you are required to set a new password immediately. Do not skip this. If your build did not force a change (for example a lab build), change it yourself right away.

## Secure the device {#secure-the-device}

Before you field a unit, walk this checklist. Each item links to the fuller page. All of it can be done from the web admin — SSH is optional.

- [ ] **Change the `pi` login password.** Forced at first login on release images. Set a strong password.
- [ ] **Set a Wi-Fi hotspot (WPA2) password.** The onboarding hotspot is open by default. In **Cockpit → AryaOS Site → Onboarding hotspot password**, set a WPA2 passphrase of 8–63 characters. See [Wi-Fi & onboarding hotspot](../networking/wifi-hotspot.md).
- [ ] **Rotate the Node-RED admin password.** AryaOS ships Node-RED with a publicly known default admin password, and the Node-RED editor can run arbitrary code. Rotate it in **Cockpit → AryaOS Site → Node-RED admin password** (or run [`aryaos-set-nodered-password`](../reference/cli-helpers.md#aryaos-set-nodered-password)). See [Node-RED dashboard](../node-red.md).
- [ ] **(Optional) Join a VPN.** For remote management, join the device to Tailscale from **Cockpit → AryaOS Site → VPN**. See [VPN (Tailscale)](../networking/vpn-tailscale.md).

!!! tip "Review the full security posture"
    AryaOS ships hardened out of the box — a hardened SSH daemon, fail2ban, sysctl hardening, per-device TLS, firewalld, and Debian-security unattended-upgrades. See [Security posture](../security.md) for the complete picture.

## Self-assembled devices: set SDR serials

If you built the device yourself, assign each RTL-SDR a unique serial so the decoders can tell them apart. Do this from **Cockpit → AryaOS Site → Radios** or with [`aryaos-sdr`](../reference/cli-helpers.md#aryaos-sdr):

```bash
sudo aryaos-sdr list
sudo aryaos-sdr set-serial 0 stx:1090:0
```

See [Radios & SDRs](../config/radios-sdr.md) for details.

## Next steps

<div class="grid cards" markdown>

- :material-cog: **Pick a mission** — Deploy for aircraft, vessels, drones, or position. [Deploy guides](../deploy/index.md)
- :material-view-dashboard: **Web admin tour** — The AryaOS Site page and gateway plugins. [AryaOS Site page](../admin/aryaos-site.md)
- :material-help-circle: **Something wrong?** — Symptom-to-fix checks. [Troubleshooting](../troubleshooting.md)

</div>
