# Download or Build

## Download AyraOS

* FIXME TK

## Build AryaOS

The build environment for AryaOS is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). 
The build will create a Raspberry Pi OS image, compatible with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

Any SD card larger than 16 GB should suffice to get started, 32 GB recommended.

The AryaOS build procedure is inspired by @deltazero's [kiosk.pi](https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6).

### Build Steps

To build initially:

1. Checkout this repo.
2. `make init` to download pi-gen.
3. `make build` to create an image.

To Update a build:

1. sync repo
2. `make skip` to skip base-os build steps.
3. `make build` to create an image.

N.B.: The `make build` step will attempt to sudo, and may prompt for a password.

### Speeding Up Local Builds with apt-cacher-ng

Re-running `make build` repeatedly re-downloads all APT packages. You can avoid this by running
a local apt caching proxy:

```bash
# Install apt-cacher-ng
sudo apt-get install apt-cacher-ng
sudo service apt-cacher-ng start

# Then set APT_PROXY in the config file or as an env var before building
export APT_PROXY=http://localhost:3142
make build
```

The proxy caches downloaded `.deb` files on first run; subsequent builds serve packages from disk,
significantly reducing download time. The cache lives in `/var/cache/apt-cacher-ng/`.

## CI Builds (GitHub Actions)

CI is handled by `.github/workflows/pi-gen.yml` using [usimd/pi-gen-action](https://github.com/usimd/pi-gen-action).

### Caching strategy

- **apt-cacher-ng**: The CI workflow installs apt-cacher-ng on the runner and configures
  pi-gen's Docker containers to route all APT traffic through it (`apt-proxy: http://172.17.0.1:3142`).
  The proxy cache at `/var/cache/apt-cacher-ng` is persisted between workflow runs using
  `actions/cache`, keyed on the contents of the `stages/**/packages` files.
- **Cache key**: Changes to any `packages` file in the `stages/` directory automatically bust the
  cache so that new packages are downloaded fresh.
- **Concurrency**: The workflow uses a `concurrency` group so that a new push to the same branch
  cancels any still-running build for that branch, preventing wasted runner time.

### Busting the CI cache

To force a full re-download of all packages (e.g., after a repository-wide package update):

1. Navigate to **Actions → Caches** in the GitHub UI and delete the `apt-cacher-ng-*` cache entries.
2. Or update any `stages/**/packages` file (even a trivial whitespace change) to produce a new cache key.
