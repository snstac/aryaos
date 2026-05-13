# Download or Build

## Download AryaOS

* FIXME TK

## Build AryaOS (Raspberry Pi image)

The build environment for AryaOS is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). The build produces a Raspberry Pi OS image, compatible with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

Any SD card larger than 16 GB should suffice to get started; 32 GB is recommended.

The AryaOS build procedure is inspired by @deltazero's [kiosk.pi](https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6).

Configuration lives in `config` at the repo root (not inside the `pi-gen/` clone). Key settings include `STAGE_LIST`, `RELEASE`, and `SHARED_FILES`.

### Image build steps

To build initially:

1. Clone this repository.
2. Run `make pi-gen` to clone the upstream `arm64` branch of pi-gen into `./pi-gen/` (ignored by git).
3. Run `make build` to create an image (uses `sudo` on the host for pi-gen).

Docker alternative (no host `sudo` for debootstrap): `make build-docker` runs `./pi-gen/build-docker.sh` with the repo mounted at `/aryaos` and [config.docker](config.docker). It **bind-mounts** `.aryaos-pigen-work` and `.aryaos-pigen-deploy` at the **repo root** (writable even if `pi-gen/` is root-owned) so **retries** reuse finished stages: `docker rm -f pigen_work` then `make build-docker` again. **`NUM_CORES`** defaults to `nproc` for faster package installs. **`make build-docker-clean`** deletes those caches (large) plus stray containers. Images end up in `.aryaos-pigen-deploy/`; the script also unpacks into `pi-gen/deploy/`.

To iterate on AryaOS-only stages without rebuilding the base OS:

1. Sync the repo.
2. Run `make skip` to add `SKIP` markers for `stage0`–`stage2`.
3. Run `make build` again.

The `make build` step invokes `sudo` and may prompt for a password.

To refresh the embedded pi-gen clone after `make pi-gen`, run `cd pi-gen && git pull origin arm64` so your toolchain stays aligned with [upstream pi-gen](https://github.com/RPi-Distro/pi-gen).

## CI, artifacts, and GitHub Releases

The workflow `.github/workflows/pi-gen.yml`:

1. **Pull requests** — Runs Ansible collection install, `ansible-playbook --syntax-check`, and checks that key paths (`config`, `manifests/aryaos-sensor-packages.yml`, custom stages) exist. No image is built (GitHub-hosted `ubuntu-latest`).
2. **Push to `main` or `workflow_dispatch`** — Builds the full pi-gen image on a **[self-hosted, Linux]** runner via [usimd/pi-gen-action](https://github.com/usimd/pi-gen-action) (`compression: xz`, `increase-runner-disk-size` disabled for self-hosted). Register the runner under **Repo → Settings → Actions → Runners**; it must provide Docker/privileged tooling compatible with pi-gen (mirror your local `make build-docker` host). After a successful build, the workflow creates an annotated tag `v<UTC-datetime>-<12-char-sha>`, pushes it, uploads the image as a **workflow artifact** (30-day retention), and publishes a **GitHub Release** with the image attached (`generate_release_notes`). Builds for the same repo are serialized (`concurrency`, no cancel-in-progress).

**Self-hosted prerequisites**

- **Docker** with permission for the runner user to build/run images (often `docker` group).
- **Privileged-ish binfmt setup:** On **x86_64** builders the workflow runs `docker run --rm --privileged tonistiigi/binfmt:latest --install arm64` so `arch-test`/debootstrap can execute **arm64** binaries. Requires **`/proc/sys/fs/binfmt_misc/register`** to exist after **`sudo modprobe binfmt_misc`** (root mounts the fs; the runner user does not need to write that node directly). The runner user typically needs **passwordless `sudo`** for `modprobe`, and a kernel with **`CONFIG_BINFMT_MISC`**. Docker must allow **`--privileged`**.
- **Native arm64 runners** (`aarch64`) skip the binfmt image step.
- Large **disk** / **RAM** consistent with local pi-gen Docker builds.

### Manual `v*` tags (optional)

The workflow no longer triggers on `push` of version tags (that avoided rebuilding when the workflow itself pushes a release tag). Use **`workflow_dispatch`** in the Actions UI to rebuild from `main`, or adjust the workflow `on:` section if you want tag-triggered builds again.

### Hosting limits

- **GitHub Releases**: each asset must be **under 2 GiB**. If your `.img.xz` is larger, use a stronger xz level in the workflow (trades CPU/time), split the file (`split -b 1900M your.img.xz chunk_`) and upload the parts as separate assets with reassembly instructions, or store the blob in **S3** (or similar) and link it from the release notes.
- **Actions artifacts**: convenient for testing builds from `main` or manual runs; they count against Actions storage quotas and expire (this workflow uses 30 days).

### Faster local builds (beefy machine)

- Prefer upstream **`pi-gen/build-docker.sh`** with **bind mounts or named volumes** for `work/` and `deploy/` so repeated runs reuse downloads where pi-gen allows.
- **Apt cache (Docker builds):** run `make apt-cacher-up` once (starts **`apt-cacher-ng`** via [`docker-compose.apt-cacher.yml`](../docker-compose.apt-cacher.yml); cache lives in the Docker volume `aryaos_apt_cacher_cache`). Then build with **`ARYAOS_APT_CACHE=1 make build-docker`**. The Makefile passes **`APT_PROXY`** into the pi-gen container (`Acquire::http::Proxy`, same as upstream pi-gen) using **`host.docker.internal`** + Docker’s **`host-gateway`**. Check the cache with **`make apt-cacher-ping`**; tail logs with **`make apt-cacher-logs`**. Stop with **`make apt-cacher-down`** (volume is kept until you remove it with `docker volume rm`).
- **Native `make build`:** set **`APT_PROXY`** in [`config`](config) (commented example) to your proxy URL, e.g. `http://127.0.0.1:3142` when `apt-cacher-ng` publishes that port on the host.
- Export **`NUM_CORES`** to match your CPU so pi-gen can parallelize package operations.
- Use **`make skip`** / **`make unskip`** when iterating only on AryaOS stages after a full base image exists.

### Off-GitHub build (e.g. AWS on a budget)

When Actions hit timeouts, disk limits, or the 2 GiB release cap:

1. Launch **Ubuntu 22.04/24.04** on **EC2 Spot** (e.g. compute-optimized 4xlarge class) with a large **gp3** volume (256–512 GB) for Docker and pi-gen work dirs.
2. Install Docker, clone this repo, `make pi-gen`, then `sudo ./build.sh` or run `pi-gen`’s Docker build script from the `pi-gen` tree.
3. Copy the artifact from `pi-gen/deploy/` to **S3** (`aws s3 cp ...`; add a lifecycle rule to expire old objects). Optionally front it with **CloudFront** if download traffic grows.
4. For GitHub distribution, either upload a file **smaller than 2 GiB** with **`gh release upload`** using a token on the instance, or publish an **S3 HTTPS URL** / `latest.json` pointer in the release notes.

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

Hardware-specific roles (ADS-B, AIS) are tagged `hardware`; skip them if the host has no relevant SDR:

```bash
ansible-playbook -i inventory.yml -e 'aryaos_profile=generic' site.yml --skip-tags hardware
```

PyTAK and related `.deb` URLs are defined once in `manifests/aryaos-sensor-packages.yml` for both image builds and Ansible.

### Check playbook syntax

```bash
make ansible-syntax
```
