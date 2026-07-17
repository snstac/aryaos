# SBOM & supply chain

Every AryaOS image build emits a **Software Bill of Materials (SBOM)** — a
machine-readable inventory of everything installed in the image — in both SPDX
and CycloneDX formats, attached to the GitHub Release. This page explains what
an SBOM is, why it matters for government deployments, and how to fetch and read
one.

## What an SBOM is

An SBOM is a complete, itemized list of the software components in a build:
every package, its version, and its license. Think of it as the ingredients
label for the OS image. When a new vulnerability is announced against some
library, an SBOM lets you answer *"is that library in our fielded units, and at
what version?"* in seconds instead of guessing.

!!! info "Why AryaOS ships one — the government context"
    AryaOS is funded by the Colorado Center of Excellence and the USDA Forest
    Service and is deployed on wildland fire and other public-safety missions.
    US federal guidance (Executive Order 14028 and the NTIA minimum elements)
    directs agencies to obtain SBOMs for the software they field. Shipping an
    SBOM with every image is table stakes for that context — and it's simply
    good supply-chain hygiene for anyone.

## What each build produces

The SBOM covers the **full rootfs** of the loop-mounted image — Debian packages,
Python site-packages, and the Node-RED npm tree — generated with
[syft](https://github.com/anchore/syft) by `scripts/generate-sbom.sh`:

| File | Format | Notes |
| --- | --- | --- |
| `<image>.spdx.json` | SPDX 2.3 (JSON) | The interchange standard used by most SBOM tooling and government workflows. |
| `<image>.cdx.json` | CycloneDX (JSON) | The OWASP format, strong for vulnerability tooling. |

Both files are attached to the **GitHub Release** alongside the image they
describe, so an SBOM always matches a specific, downloadable build.

## Fetch an SBOM

Grab the SBOM files from the release page that matches your image.

=== "GitHub web"

    1. Open the [AryaOS releases](https://github.com/snstac/aryaos/releases).
    2. Pick the release matching your fielded image.
    3. Under **Assets**, download the `*.spdx.json` and/or `*.cdx.json` files.

=== "GitHub CLI"

    ```bash
    # List assets on a release, then download the SBOMs
    gh release view <tag> --repo snstac/aryaos
    gh release download <tag> --repo snstac/aryaos --pattern '*.spdx.json' --pattern '*.cdx.json'
    ```

!!! tip "Match the SBOM to the running build"
    The AryaOS version on a unit is in `/etc/aryaos-version` (and shown in the
    **Software updates** card). Fetch the SBOM for that release so the inventory
    matches what's actually running.

## Read an SBOM

The files are JSON, so any tool that speaks SPDX or CycloneDX works. A couple of
quick starts:

```bash
# Count and list packages in an SPDX file
jq '.packages | length' aryaos.spdx.json
jq -r '.packages[] | "\(.name) \(.versionInfo)"' aryaos.spdx.json | sort

# Scan the SBOM for known vulnerabilities with grype
grype sbom:aryaos.cdx.json
```

!!! note "Regenerate one yourself"
    If you built a custom image, produce matching SBOMs the same way CI does:

    ```bash
    sudo scripts/generate-sbom.sh path/to/aryaos.img.xz out/aryaos
    # writes out/aryaos.spdx.json and out/aryaos.cdx.json
    ```

    It loop-mounts the image read-only and runs syft over the rootfs — set
    `SYFT_BIN` to point at a specific syft binary if it isn't on `PATH`.

## The trust anchor

An SBOM tells you *what* is installed; the signed apt repository tells you it
came from a source you trust. AryaOS installs every package — at build time and
during [updates](updates.md) — from the **GPG-signed snstac apt repository**,
[`https://snstac.github.io/packages`](https://snstac.github.io/packages). A unit
only installs packages it can cryptographically verify came from Sensors &
Signals, and the SBOM lets you audit exactly what those packages were.

## Related

<div class="grid cards" markdown>

- :material-update: **Updates** — the signed repo in the update path. [Updates](updates.md)
- :material-shield-lock: **Security posture** — image verification and the broader trust story. [Security posture](../security.md)
- :material-briefcase-search: **Support bundles** — capture the installed-package state from a live unit. [Support bundles](support-bundles.md)

</div>
