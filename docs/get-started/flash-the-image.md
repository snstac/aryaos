# Flash the image

Write the AryaOS image to a microSD card, then boot your Raspberry Pi from it. This takes a few minutes with either Raspberry Pi Imager or balenaEtcher, and both verify the write before you unplug.

!!! danger "Flashing erases the card"
    Writing an image overwrites everything on the target microSD card. Double-check the drive you select before you start.

## Before you begin

- A supported Raspberry Pi and a microSD card of at least **16 GB** (32 GB recommended) — see [Hardware & requirements](hardware.md).
- A workstation running Windows, macOS, or Linux.
- The AryaOS image file (next section).

## Get the image

| Source | Where | When to use |
|---|---|---|
| GitHub Releases | [github.com/snstac/aryaos/releases](https://github.com/snstac/aryaos/releases) | The stable, recommended download |
| CI artifacts | GitHub Actions build artifacts on the repo | Testing an unreleased build your team pointed you to |

Download the AryaOS image (published as a compressed `.img.xz`). Both flashing tools below read `.img.xz` directly — you do not need to decompress it first.

!!! info "Every release is signed and bill-of-materials'd"
    Each image build attaches an SPDX and CycloneDX software bill of materials (SBOM) to its GitHub Release, and all AryaOS packages install from the [signed apt repository](https://snstac.github.io/packages). See [SBOM & supply chain](../operations/sbom.md).

## Flash the card

=== "Raspberry Pi Imager"

    [Raspberry Pi Imager](https://www.raspberrypi.com/software/) is the recommended tool. It runs on Windows, macOS, and Linux.

    1. Install Raspberry Pi Imager if you do not already have it.
    2. Insert the microSD card into your workstation.
    3. Open Raspberry Pi Imager.
    4. Under **Choose OS**, scroll to the bottom and select **Use custom**, then pick the downloaded AryaOS `.img.xz`.
    5. Under **Choose Storage**, select the microSD card. **Confirm the device — this erases the card.**
    6. Click **Next**, confirm, and wait for the write and verify steps to finish.

    !!! warning "Skip the OS customization prompt"
        If Imager offers to apply hostname, Wi-Fi, or user settings, choose **No** / skip it. AryaOS personalizes its own hostname and hotspot on [first boot](first-boot.md); pre-seeding those settings can conflict.

=== "balenaEtcher"

    [balenaEtcher](https://etcher.balena.io/) also writes AryaOS cards on Windows, macOS, and Linux.

    1. Download and install [balenaEtcher](https://etcher.balena.io/).
    2. Insert the target microSD card.
    3. Open balenaEtcher.
    4. Select **Flash from file** and choose the AryaOS image.
    5. Select the target microSD card.
    6. Click **Flash**.

    ![balenaEtcher writing an AryaOS image](../install/balenaEther_screenshot.png){ width="720" }

    When the write finishes, balenaEtcher verifies the image automatically and then ejects the card.

## Boot the Pi

1. Eject the microSD card from your workstation.
2. Insert it into the powered-off Raspberry Pi.
3. Attach any radios, antennas, and GPS you plan to use (see [Hardware & requirements](hardware.md)).
4. Apply power.

Within a few seconds the AryaOS device flashes its green and red LEDs as it starts up.

!!! note "First boot takes about 120 seconds"
    A brand-new AryaOS device spends roughly two minutes on its first boot resizing the filesystem, choosing a unique identity, and generating its own web certificate. This only happens once. See [First boot & first login](first-boot.md) for exactly what happens and how to connect.

## Next step

<div class="grid cards" markdown>

- :material-power: **First boot & first login** — Connect to the hotspot, log in, and secure the device. [First boot & first login](first-boot.md)

</div>
