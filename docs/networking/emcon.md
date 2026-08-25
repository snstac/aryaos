# EMCON & radio control

An AryaOS box has two onboard radios that emit RF: **Wi-Fi** (the `aryaos-xxxx`
onboarding hotspot, and any Wi-Fi client link) and **Bluetooth** (the PAN
onboarding path). For low-probability-of-intercept / low-probability-of-detection
(**LPI/LPD**) operation you often want to silence them - or just turn off the
Wi-Fi hotspot once a unit is fielded on ethernet. The `aryaos-radio` helper and
The **Radios** controls in Cockpit > AryaOS Site do both.

!!! info "Wired ethernet is never affected"
    EMCON and the AP controls only touch the *onboard radios*. The wired
    ethernet link keeps working, so a box you reach over ethernet (or
    [Tailscale](vpn-tailscale.md) over ethernet) stays reachable.

## Disable the Wi-Fi hotspot

Once a box is fielded on Ethernet, you can stop it from broadcasting `aryaos-xxxx`
at all. Disabling the hotspot stops the broadcast and keeps it off across reboots.

=== "In Cockpit"

    **AryaOS Site > Radios > Wi-Fi hotspot > Disable.** Re-enable from the same
    card.

=== "From the shell"

    ```bash
    sudo aryaos-radio ap off      # stop the aryaos-xxxx broadcast (persists across reboot)
    sudo aryaos-radio ap on       # bring it back
    sudo aryaos-radio ap status
    ```

The Wi-Fi radio itself stays available (e.g. to join a Wi-Fi network as a
client). Only the onboarding hotspot is turned off. To silence the radio
entirely, use EMCON below.

## EMCON (radio silence)

EMCON blocks **both Wi-Fi and Bluetooth** at the `rfkill` level, so the onboard
radios stop transmitting entirely. The block **persists across reboots**.
`aryaos-radio-silence.service` applies `/etc/aryaos/emcon` before the network
starts. Thus, an EMCON device emits no RF during boot.

=== "In Cockpit"

    **AryaOS Site > Radios > EMCON / radio silence > On.** The hotspot drops and
    The Wi-Fi/Bluetooth adapters go dark. Toggle **Off** to restore.

=== "From the shell"

    ```bash
    sudo aryaos-radio silence on      # rfkill-block Wi-Fi + Bluetooth (persists)
    sudo aryaos-radio silence off     # unblock and restore the hotspot
    sudo aryaos-radio silence status  # show EMCON flag + rfkill state
    ```

!!! warning "SDR receivers are not silenced by EMCON"
    Software-defined radios (ADS-B/AIS/drone dongles) are **receive-only** - they
    do not transmit, so they present no emissions signature and EMCON leaves them
    running. If you want them powered down anyway, stop their services (e.g.
    `sudo systemctl stop adsbcot dronecot`) or unplug them.

## Hotspot clients cannot reach the wired network

Independent of EMCON, AryaOS **never bridges or routes** a wireless onboarding
client onto the wired ethernet. The firewalld default zone ships with no
intra-zone forwarding. A hotspot or Bluetooth PAN client can reach the device's
onboarding and administration services. The firewall never routes that client
to `eth0` or the upstream network. This rule also applies when the host enables
`net.ipv4.ip_forward`. See
[Firewall](firewall.md) for the zone details.

## Related

<div class="grid cards" markdown>

- :material-wifi: **Wi-Fi & onboarding** - the hotspot and how a box joins Wi-Fi. [Wi-Fi & onboarding hotspot](wifi-hotspot.md)
- :material-wall-fire: **Firewall** - the zone allowlist and AP/PAN isolation. [Firewall](firewall.md)
- :material-radio-tower: **Radios & SDRs** - SDR dongle management. [Radios & SDRs](../config/radios-sdr.md)

</div>
