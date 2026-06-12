# Agent handoff — state as of 2026-06-12

Working notes for agents (and humans) picking up AryaOS and the snstac fleet.
Supersedes the 2026-05-16 handoff in [portal.md](portal.md).

## The big picture

AryaOS is the **master consumer of the PyTAK stack**. Three pillars landed in June 2026:

1. **Everything installs from the signed apt repo** — https://snstac.github.io/packages,
   built by [snstac/packages](https://github.com/snstac/packages) from each product's
   *latest GitHub release* (repos listed in its `products.txt`). No vendored sensor
   binaries remain in this repo; the only vendored artifacts are trust anchors
   (`shared_files/aryaos/snstac-packages/`, FlightAware repo deb).
2. **Cockpit is the single admin surface** — nine standalone `cockpit-*` plugin
   repos/debs (adsbcot, aiscot, aiscatcher, dronecot, lincot, gps, charontak, gpstak,
   aryaos). `cockpit-aryaos` ("AryaOS Site") manages the site-wide layer:
   `/etc/aryaos/aryaos-config.txt` (site `COT_URL` etc.) and one-shot TAK TLS cert
   upload to `/etc/aryaos/tls` (key `0640 root:tak-certs`; group reconciled by
   `aryaos-firstboot.sh` every boot). Per-tool plugins edit `/etc/default/<svc>`.
3. **CI builds dev images by default** — every push to `main` produces a
   `v<ts>-<sha>-dev` **prerelease** with lab access baked (dev SSH key, pi NOPASSWD,
   no password expiry) for burn-and-test. Hardened release images require dispatching
   the Pi-gen workflow with the **`release`** input checked. `scripts/verify-image.sh`
   loop-mounts every built image and asserts ~39 facts (packages, units, files, and
   the lab/release security contract) before anything publishes.

## Architecture invariants (don't break these)

- **Site-config inheritance**: every gateway unit loads
  `EnvironmentFile=-/etc/aryaos/aryaos-config.txt` *before* its own
  `/etc/default/<svc>` — site sets defaults, per-service values override. The
  injection happens in each stage's chroot script (sed after `[Service]`); drop-in
  files would invert the precedence (drop-ins parse *after* the unit file).
- **apt pinning**: `install-sensor-debs.sh` pins `release o=snstac` at **995** because
  stage-adsbcot pins trixie at 990 and Debian ships an SDR-less readsb that must never
  win. readsb is also `apt-mark hold` (status `hold ok installed` — verify-image
  accepts both hold and install).
- **Exactly one `EXPORT_IMAGE`** stage, last in every `STAGE_LIST` (PR validation
  enforces). `ARYAOS_CI_TRIM_WORK=1` (CI only) deletes stale stage rootfs trees —
  pi-gen full-copies per stage and 72 GB arm64 runners can't hold ~15 copies
  (the fleet has 72 GB *and* 145 GB VMs; never rely on runner luck).
  `increase-runner-disk-size` is broken on arm64 runners — keep it false.

## GPSTAK (new, 2026-06-12)

`shared_files/gpstak/gpstak.py` → `/usr/local/bin/gpstak`: feeds onboard GNSS to TAK
devices per https://ampledata.org/network_gps.html — CoT position events to `COT_URL`
(default `udp+broadcast://255.255.255.255:4349`, ATAK's *External or Network GPS*) and
raw-NMEA passthrough for WinTAK (`NMEA_TARGETS`). Reads gpsd's JSON socket; pytak for
transport (so `PYTAK_TLS_*` applies). Ships **disabled**; managed in Cockpit → GPSTAK
([cockpit-gpstak](https://github.com/snstac/cockpit-gpstak)). Verified live on the dev
Pi. Candidate for extraction to its own repo + deb later.

## Fleet state (all on pytak >= 7.3.0, releasing versioned debs)

| Repo | Release | Notes |
|---|---|---|
| pytak | 7.3.11 | capability line: cert enrollment, `tak://`, `wss://`, `marti://`, `pytak dp`, `+wo`/`+ro`, MQTT |
| adsbcot 9.1.0, aprscot 8.0.0, inrcot 5.2.1, cotproxy 1.0.1 | Jun 2026 | pipelines modernized (lincot-style ci.yml) |
| aiscot 7.1.4, dronecot 2.1.3, djicot 1.2.0, lincot 1.2.3, charontak 0.1.13 | Jun 2026 | charontak ≥ 0.1.13 no longer ships its cockpit plugin in-deb |
| readsb 3.16.15-2 | Jun 2026 | synced to wiedehopf dev; **build debs in `debian:trixie` containers** (Ubuntu builds depend on `librtlsdr2`, uninstallable on Debian) |
| dhbridge 0.3.3 | Jun 2026 | public now; ≥ 0.3.2 required for Pi 5 (sysfs has no `address` attr); `/etc/default/dhbridge` masks `dhbridge.ini` keys (issue #3) |
| AIS-catcher (fork) 0.68 | Jun 2026 | release workflow runs upstream `build-debian.sh` as root; upstream CI workflows disabled on the fork |
| kraktak 10.1.1, windtak 1.0.0, takline 0.1.1 | Jun 2026 | kraktak release decoupled from its best-effort docker job |
| cockpit-* ×9 | 1.0.0+ | see pillar 2 |

## Recurring gotchas (each cost a build this month)

- `gh release upload` fails on fresh tags — `gh release view || gh release create` first.
- `dpkg-deb -c | grep | head` → SIGPIPE kills dpkg-deb under `set -e`.
- `dh_install` treats destinations as directories (`foo.conf` becomes a *dir*).
- stdeb deb names default to `python3-<name>` without `stdeb.cfg` `Package3:`.
- A single private/release-less repo in `products.txt` kills the whole publish
  ("release not found"); publishes racing a just-pushed tag fail the same way.
- This repo has `core.fileMode=false` — `git update-index --chmod=+x` for scripts.
- GitHub GraphQL intermittently 401s here; use REST (`gh api`) with retries.

## Dev lab

`pi@172.17.2.158` (`aryaos-dev-pi`), key `id_ed25519_aryaos_dev` at repo root
(gitignored via `.git/info/exclude` — consider a tracked `.gitignore` entry).
Integration suite: `ARYAOS_SSH=pi@172.17.2.158 ARYAOS_DEV_PI_SSH_KEY=./id_ed25519_aryaos_dev
./scripts/aryaos-test/run.sh` — last full run 32/32. The Pi runs dhbridge 0.3.3,
readsb 3.16.15 (held), RTL serial `2002` (`host_vars/aryaos-dev-pi.yml`).

## Open items (need Greg's decision or action)

1. **takline + windtak are private** — the packages publish token can't read them;
   flip public (`gh repo edit snstac/<r> --visibility public
   --accept-visibility-change-consequences`), then add to `products.txt`.
2. **Archive** `spotcot` (pre-pytak-5, dormant since 2022) and `cockpit-sdrconnect`
   (unmodified cockpit-dronecot clone, no releases).
3. **Delete** stray fork `snstac/AIS-catcher-1` (accidental duplicate).
4. adsbcot PyPI job needs a **trusted publisher** configured on PyPI (release works
   regardless; the job just reads red).
5. Possible next plugins: charontak *lane editor* (structured `charontak.ini` UI —
   current plugin is a raw editor), kraktak/windtak/aprscot pages; extract GPSTAK to
   its own repo; backport SIGPIPE fix everywhere `dpkg-deb -c | head` survives.
6. Node-RED runtime check after the worldmap 5.x / tfr2cot 2.0 major bumps
   (palette installs now go through the npm 11 override).
