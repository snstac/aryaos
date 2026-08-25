# Download or Build

## Download AryaOS

Official release images are published as **GitHub Releases** on [snstac/aryaos](https://github.com/snstac/aryaos/releases). Each successful automated image build on `main` creates an annotated tag (`v<UTC-datetime>-<short-sha>`) and attaches the compressed image (`.img.xz`) to that release.

You can also fetch recent images from **GitHub Actions**:

1. Open the repository **Actions** tab and select **Pi-gen image**.
2. Open a completed run (push to `main` or **workflow_dispatch**).
3. Download the workflow **artifact**. The workflow keeps artifacts for 30 days, and they use Actions storage.

For flash instructions, see [Installing AryaOS](get-started/flash-the-image.md).

## Manual build checklist (local Raspberry Pi image)

Use this checklist when building an **arm64** Raspberry Pi OS-based image on your own machine. Automation-focused notes live in [AGENTS.md](https://github.com/snstac/aryaos/blob/main/AGENTS.md) at the repo root.

### Prerequisites

- **Git** and plenty of **disk** (pi-gen `work/` + deploy output can reach hundreds of gigabytes).
- **Docker** if you use `make build-docker` (recommended for unattended builds).
- **Passwordless or ready sudo** if you use `make build` / `./build.sh`.
- Repo layout: **`Makefile`**, **`config`** (native pi-gen), **`config.docker`** (Docker pi-gen bind-mount at `/aryaos`), **`shared_files/`**, **`stages/`**.

### Steps

1. Clone this repository.
2. **`make pi-gen`** - clones upstream [pi-gen](https://github.com/RPi-Distro/pi-gen) **`arm64`** into `./pi-gen/` (gitignored).
3. Choose one build path:
   - **Docker (preferred):** `make build-docker` - runs `./pi-gen/build-docker.sh -c <repo>/config.docker`, repo mounted read-only at `/aryaos`. Outputs land under **`.aryaos-pigen-deploy/`** at the repo root (and can also appear under `pi-gen/deploy/`).
   - **Native:** `make build` - runs `sudo ./build.sh`, which invokes pi-gen with **`config`** (expects `./pi-gen`).
4. After a successful base exists, use **`make skip`** / **`make unskip`** to skip or restore pi-gen **`stage0`-`stage2`** while iterating on AryaOS-only stages (see Makefile).
5. Optional **apt cache for Docker builds:** run `make apt-cacher-up`, then run `ARYAOS_APT_CACHE=1 make build-docker`. See the `apt-cacher-*` Makefile targets and `docker-compose.apt-cacher.yml`.
6. Optional **logged Docker build:** `./scripts/agent-build-docker.sh` mirrors output to `build-YYYYMMDD-HHMMSS.log`.
7. **Lab vs release builds:** by default images carry **no lab access** and **expire the default `pi` password at first login**. For a lab image (aryaos-dev-lab SSH key + passwordless sudo for `pi`, no password expiry) build with **`ARYAOS_LAB_ACCESS=1 make build-docker`** (or `sudo ARYAOS_LAB_ACCESS=1 ./build.sh` native). See `shared_files/aryaos/ssh/README.md`.
8. **Verify a built image:** `sudo scripts/verify-image.sh [--lab] <image>.img|.img.xz|.zip` checks files, packages, units, and lab access. CI runs this on every `main` build before publishing a release.
9. **Build the AryaOS overlay package only:** `make package-overlay` writes the overlay package. The package contains the portal, Cockpit integration, TAK helpers, identity scripts, defaults, hooks, and service configuration.
10. Lightweight validation without an image: **`make ansible-syntax`** (requires Ansible / `ansible-galaxy` per Makefile).

### Cleanup / retry

- **`make build-docker-clean`** removes `.aryaos-pigen-work/`, `.aryaos-pigen-deploy/`, and stray pi-gen Docker containers.
- **`make clean`** / **`make distclean`** widen the wipe (see Makefile).

### CI vs local

Pull requests run Ansible syntax and path checks only. **Full images** build on
**`ubuntu-24.04-arm`** after a merge to `main` or a manual workflow. See the
[pi-gen workflow](https://github.com/snstac/aryaos/blob/main/.github/workflows/pi-gen.yml).

---

## Build AryaOS (Raspberry Pi image)

The build environment for AryaOS is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). The build produces a Raspberry Pi OS image, compatible with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

Any SD card larger than 16 GB can get started. A 32 GB card is better for repeated builds.

The AryaOS build procedure is inspired by @deltazero's [kiosk.pi](https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6).

Configuration lives in `config` at the repo root (not inside the `pi-gen/` clone). Key settings include `STAGE_LIST`, `RELEASE`, and `SHARED_FILES`.

### Image build steps (detail)

To build initially:

1. Clone this repository.
2. Run `make pi-gen` to clone the upstream `arm64` branch of pi-gen into `./pi-gen/` (ignored by git).
3. Run `make build` to create an image (uses `sudo` on the host for pi-gen).

Docker alternative (no host `sudo` for debootstrap): `make build-docker` runs `./pi-gen/build-docker.sh` with the repo mounted at `/aryaos` and [config.docker](https://github.com/snstac/aryaos/blob/main/config.docker). It **bind-mounts** `.aryaos-pigen-work` and `.aryaos-pigen-deploy` at the **repo root** (writable even if `pi-gen/` is root-owned) so **retries** reuse finished stages. `docker rm -f pigen_work` then `make build-docker` again. **`NUM_CORES`** defaults to `nproc` for faster package installs. **`make build-docker-clean`** deletes those caches (large) plus stray containers. Images end up in `.aryaos-pigen-deploy/`. The script also unpacks into `pi-gen/deploy/`.

To iterate on AryaOS-only stages without rebuilding the base OS:

1. Sync the repo.
2. Run `make skip` to add `SKIP` markers for `stage0`-`stage2`.
3. Run `make build` again.

The `make build` step invokes `sudo` and can prompt for a password.

To refresh the embedded pi-gen clone after `make pi-gen`, run `cd pi-gen && git pull origin arm64` so your toolchain stays aligned with [upstream pi-gen](https://github.com/RPi-Distro/pi-gen).

## CI, artifacts, and GitHub Releases

The workflow `.github/workflows/pi-gen.yml`:

1. **Pull requests** - Runs Ansible collection install, `ansible-playbook --syntax-check`, checks that key paths (`config`, `manifests/aryaos-sensor-packages.yml`, custom stages) exist, validates that exactly **one stage carries `EXPORT_IMAGE`** and is **last in every `STAGE_LIST`**. HEAD-checks pinned download URLs (catches upstream release renames before they break a 6-hour `main` build). No image is built (GitHub-hosted `ubuntu-latest`).
2. **Push to `main` or `workflow_dispatch`** - Builds a **dev image** by default. The image contains
   lab access and uses a `v<ts>-<sha>-dev` prerelease tag. Select the **`release`** input for a field
   image without lab access. The workflow builds natively on GitHub's **`ubuntu-24.04-arm`** runner
   with [usimd/pi-gen-action](https://github.com/usimd/pi-gen-action). It frees disk space before the
   build and uploads a 30-day workflow artifact. `scripts/verify-image.sh` checks the image before
   publication. A failed check keeps the artifact but blocks the release. A successful check creates
   a version tag and GitHub Release. The workflow serializes builds for this repository.

**Hosted arm64 notes**

- **Public repos** can use **`ubuntu-24.04-arm`** at no extra charge for standard Actions minutes (subject to GitHub policies/limits).
- **`usimd/pi-gen-action`** mounts stage directories, not the whole repository. The workflow uses
  `docker-opts` to mount required source directories and `pi-gen-src/` at their workspace paths.
- If disk pressure persists on hosted runners, consider enabling **`increase-runner-disk-size`** on **`pi-gen-action`** or trimming stages. pi-gen **work/** trees are large.

### SBOMs

Every image build also produces a **Software Bill of Materials** in both
SPDX 2.3 and CycloneDX JSON (`aryaos-<tag>.spdx.json` / `.cdx.json`), attached
to the GitHub Release beside the image and kept as a 90-day workflow artifact.
The generator is `scripts/generate-sbom.sh` (loop-mounts the image, runs a
pinned [syft](https://github.com/anchore/syft) over the rootfs - covers dpkg,
Python site-packages, and the Node-RED npm tree). Run it locally with:

```bash
sudo SYFT_BIN=syft ./scripts/generate-sbom.sh deploy/<image>.img.xz /tmp/aryaos-sbom
```

### Manual `v*` tags (optional)

The workflow no longer triggers on `push` of version tags (that avoided rebuilding when the workflow itself pushes a release tag). Use **`workflow_dispatch`** in the Actions UI to rebuild from `main`, or adjust the workflow `on:` section if you want tag-triggered builds again.

### Hosting limits

- **GitHub Releases**: each asset must be **under 2 GiB**. If an image is larger, use a stronger xz level or split the file. You can also store the image in **S3** and link it from the release notes.
- **Actions artifacts**: convenient for testing builds from `main` or manual runs. They count against Actions storage quotas and expire (this workflow uses 30 days).

### Faster local builds (beefy machine)

- Prefer upstream **`pi-gen/build-docker.sh`** with **bind mounts or named volumes** for `work/` and `deploy/` so repeated runs reuse downloads where pi-gen allows.
- **Apt cache (Docker builds):** run `make apt-cacher-up` once (starts **`apt-cacher-ng`** via `docker-compose.apt-cacher.yml` at the repo root. Cache lives in the Docker volume `aryaos_apt_cacher_cache`). Then build with **`ARYAOS_APT_CACHE=1 make build-docker`**. The Makefile passes **`APT_PROXY`** into the pi-gen container (`Acquire::http::Proxy`, same as upstream pi-gen) using **`host.docker.internal`** + Docker's **`host-gateway`**. Check the cache with **`make apt-cacher-ping`**. Tail logs with **`make apt-cacher-logs`**. Stop with **`make apt-cacher-down`** (volume is kept until you remove it with `docker volume rm`).
- **Native `make build`:** set **`APT_PROXY`** in [`config`](config/index.md) (commented example) to your proxy URL, e.g. `http://127.0.0.1:3142` when `apt-cacher-ng` publishes that port on the host.
- Export **`NUM_CORES`** to match your CPU so pi-gen can parallelize package operations.
- Use **`make skip`** / **`make unskip`** when iterating only on AryaOS stages after a full base image exists.

### Off-GitHub build (e.g. AWS on a budget)

When Actions hit timeouts, disk limits, or the 2 GiB release cap:

1. Launch **Ubuntu 22.04/24.04** on **EC2 Spot** (e.g. compute-optimized 4xlarge class) with a large **gp3** volume (256-512 GB) for Docker and pi-gen work dirs.
2. Install Docker, clone this repo, `make pi-gen`, then `sudo ./build.sh` or run `pi-gen`'s Docker build script from the `pi-gen` tree.
3. Copy the artifact from `pi-gen/deploy/` to **S3** (`aws s3 cp ...`. Add a lifecycle rule to expire old objects). Optionally front it with **CloudFront** if download traffic grows.
4. For GitHub distribution, upload a file **smaller than 2 GiB** with **`gh release upload`**. Alternatively, publish an S3 URL or `latest.json` pointer.

## Deploy with Ansible (existing host)

The same `stages/stage-*` trees are usable as Ansible roles. Root `ansible.cfg` sets `roles_path` to `./stages`.

Install collections once:

```bash
ansible-galaxy collection install -r requirements.yml
```

Example: full stack on an inventory host (default `aryaos_profile: rpi` in `vars.yml`):

```bash
ansible-playbook -i inventory.yml site.yml
```

Example: sensor stack on a generic Debian/Ubuntu host (e.g. Dragon-style image) without Pi appliance extras (portal, comitup, etc.):

```bash
ansible-playbook -i inventory.yml -e 'aryaos_profile=generic' site.yml
```

Hardware-specific roles (ADS-B, AIS) are tagged `hardware`. Skip them if the host has no relevant SDR:

```bash
ansible-playbook -i inventory.yml -e 'aryaos_profile=generic' site.yml --skip-tags hardware
```

The PyTAK sensor stack installs from the signed [snstac apt repository](https://snstac.github.io/packages) (built by [snstac/packages](https://github.com/snstac/packages) from each product's latest GitHub Release). The package list is defined once in `manifests/aryaos-sensor-packages.yml` for both image builds and Ansible. The repo's trust anchor (`snstac.gpg` + `snstac.sources`) is vendored at `shared_files/aryaos/snstac-packages/`.

AryaOS-owned appliance files are also buildable as a local Debian package with `make
package-overlay`. During pi-gen, `stage-aryaos/00-install` builds that package into the target
rootfs. Installs it with apt so the running image records the overlay as `aryaos-overlay` in dpkg.
The legacy direct-copy path remains in the stage for now as a fallback while the overlay package is
being hardened.

### Check playbook syntax

```bash
make ansible-syntax
```

## Developer loops (faster iteration without an SD card)

When you need something close to AryaOS (e.g. **Cockpit + cockpit-adsbcot + adsbcot**) but do not want to wait for a full pi-gen image, flash, and reboot cycle:

### Incremental image builds (reminder)

Reuse **`.aryaos-pigen-work`** / **`.aryaos-pigen-deploy`**, **`make skip`** after the base exists, **`ARYAOS_APT_CACHE=1`**. **`NUM_CORES`**. See [AGENTS.md](https://github.com/snstac/aryaos/blob/main/AGENTS.md) and the **Manual build checklist** above. Avoid **`make build-docker-clean`** unless you need a cold rebuild.

### Ansible against a running Debian/arm64 host

[`site.yml`](https://github.com/snstac/aryaos/blob/main/site.yml) drives the same **`stages/stage-*`** trees as roles. Point Ansible at a cloud **arm64** VM, QEMU/UTM guest, or spare Pi already running Debian-tier OS, then install only what you need via tags:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.yml site.yml \
  --limit dev_arm64_example \
  -e 'aryaos_profile=generic' \
  --tags base,pytak,adsbcot \
  --skip-tags hardware
```

- Add **`aryaos`** (or other tags from [`site.yml`](https://github.com/snstac/aryaos/blob/main/site.yml)) when you need portal/lighttpd/Cockpit proxy behaviour (e.g. **`UrlRoot=/admin`**).
- **`stage-adsbcot`** can assume **Pi-oriented `.deb` artifacts** (e.g. vendored **arm64** readsb) or hardware. An **amd64** laptop often needs different packages or vars - prefer **arm64** for parity with shipped images.
- **readsb SDR backends:** pi-gen rebuilds readsb with **RTL-SDR**, **SoapySDR** (Airspy), and **HackRF** via [`shared_files/adsbcot/readsb-install.sh`](https://github.com/snstac/aryaos/blob/main/shared_files/adsbcot/readsb-install.sh). `04-adsbcot/01-run-chroot.sh` fails the stage if `readsb --help` lacks any of those. See [Radios & SDRs](config/radios-sdr.md#choosing-the-1090-mhz-decoder).

See commented **`dev_arm64`** stubs in [`inventory.yml`](https://github.com/snstac/aryaos/blob/main/inventory.yml).

### AirTAK-style readsb + adsbcot on DragonOS (`dragonball`)

For a **generic amd64** host (e.g. Ubuntu DragonOS) with SSH as **`gba`** and key **`~/.ssh/id_ed25519_nopass`**, use the thin playbook [`playbooks/readsb-adsbcot-generic.yml`](https://github.com/snstac/aryaos/blob/main/playbooks/readsb-adsbcot-generic.yml) (pytak sensor `.debs`, **COTBridge** CoT hub, + **`stage-adsbcot`** readsb build). Host vars: [`host_vars/dragonball.yml`](https://github.com/snstac/aryaos/blob/main/host_vars/dragonball.yml).

```bash
ansible-galaxy collection install -r requirements.yml
ansible -i inventory.yml dragonball -m ping -e ansible_become=false

# gba must have sudo (passwordless, or use -K / playbooks/dragonball-secret.yml)
ansible-playbook -i inventory.yml playbooks/readsb-adsbcot-generic.yml \
  --limit dragonball \
  -e 'adsb_sdr_sn=YOUR_RTL_SERIAL'
```

**`dragonball`** defaults in [`host_vars/dragonball.yml`](https://github.com/snstac/aryaos/blob/main/host_vars/dragonball.yml) use an **Airspy** (`1d50:60a1`) via **`readsb_device_type: soapysdr`** and **`readsb_soapy_device: driver=airspy`**. RTL dongles: set **`readsb_device_type: rtlsdr`** and **`adsb_sdr_sn`** from `rtl_test` (must differ from **`uat_sdr_sn`**).

If sudo prompts for a password, copy [`playbooks/dragonball-secret.yml.example`](https://github.com/snstac/aryaos/blob/main/playbooks/dragonball-secret.yml.example) to gitignored **`playbooks/dragonball-secret.yml`** and pass **`-e @playbooks/dragonball-secret.yml`**, or run **`--ask-become-pass`**.

Without sudo (e.g. **`gba`** in the **`docker`** group only): rsync the repo to the host, then run [`scripts/dragonball-deploy-readsb-adsbcot.sh`](https://github.com/snstac/aryaos/blob/main/scripts/dragonball-deploy-readsb-adsbcot.sh) on the machine. It builds readsb with SoapySDR/Airspy in Docker, installs units/config on the host rootfs, and enables services via **`nsenter`** (no password).

On a running host: [`scripts/readsb-use-airspy.sh`](https://github.com/snstac/aryaos/blob/main/scripts/readsb-use-airspy.sh) or [`scripts/readsb-use-rtl-serial.sh`](https://github.com/snstac/aryaos/blob/main/scripts/readsb-use-rtl-serial.sh). Probe Airspy with `SoapySDRUtil --probe="driver=airspy"`.

After deploy: `systemctl status cotbridge readsb adsbcot`, confirm `/run/adsb/aircraft.json` existss.

### Loop-mount / `nspawn` / `chroot` (advanced)

You can **loop-mount** a built **`.img`**, then **`systemd-nspawn`** or **`chroot`** into the rootfs for package inspection or quick commands. This is **not** a full firmware/kernel/network test and can behave differently than hardware.

### QEMU system arm64

Boot a generic **Debian arm64** cloud image or your produced image under **QEMU** / **UTM** for a closer integration test **without** writing an SD card. Expect lower performance than bare metal.

### cockpit-adsbcot UI-only iteration

Upstream [**cockpit-adsbcot**](https://github.com/snstac/cockpit-adsbcot) documents **`make devel-install`**, which symlinks the built bundle into **`~/.local/share/cockpit/`** on a machine that already runs Cockpit. Fastest for **frontend** changes. It does **not** reproduce AryaOS **lighttpd** termination or **`UrlRoot=/admin`** by itself. Validate that stack via Ansible or a real image.
