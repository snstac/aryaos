# Agent handoff — state as of 2026-07-18

Working notes for agents (and humans) picking up AryaOS and the snstac fleet.
Supersedes the 2026-05-16 handoff in [portal.md](portal.md).

!!! tip "Looking for what to work on next?"
    Outstanding work and follow-ups live in **[Roadmap & next steps](roadmap.md)**.
    This handoff covers the running build/merge state and architecture invariants.

## 2026-07-15/17 sweep — "never SSH" + fleet dedup (SHIPPED)

Full review + implementation sweep. **All 11 PRs merged and released** (2026-07-17,
in dependency order: packages → aryaos → cockpit-aryaos → plugins). What landed:

- **aryaos overlay helpers** (all driven by cockpit-aryaos cards, no SSH):
  `aryaos-support-bundle` (redacted diagnostics tarball, `/var/lib/aryaos/support/`),
  `aryaos-set-nodered-password` (rotates the publicly-known default; `settings.js`
  → `root:node-red 0640`), `aryaos-sdr` (RTL-SDR enumerate + EEPROM re-serial; this
  added the `rtl-sdr` package — only `librtlsdr0` shipped before), `aryaos-role`
  (runtime device roles **multi/air/maritime/cuas/relay**; CoT core charontak/lincot/
  gpstak/gpsd never touched; ADS-B decoder follows `ARYAOS_ADSB_DECODER`). Installed
  via overlay deb + chroot stage + Ansible; asserted in `verify-image.sh`; all four
  now in the CI shellcheck list (they have **no `.sh` suffix** — the globs missed them,
  don't re-break that).
- **SBOMs** — `scripts/generate-sbom.sh` + pinned syft, every image build emits
  SPDX + CycloneDX attached to the release. The step runs **before the tag push** on
  purpose (an SBOM failure must not strand a tag). CAUTION: it runs syft under `sudo`,
  so it chowns `deploy/` back to the runner afterward — a prior version stranded a tag
  by leaving `deploy/` root-owned (fixed in #131).
- **cockpit-aryaos v1.3.0** — six new cards: support bundle, Node-RED password,
  Radios (RTL-SDR), Device role, comitup hotspot password, Tailscale join. The four
  helper-backed cards need aryaos-overlay ≥ the 2026-07 helpers; on older images they
  show a clear error toast.
- **cockpit-charontak v1.2.0** — React/TS rewrite + **structured lane editor**.
  `src/cotUrl.ts` is a differentially-tested port of `charontak/src/charontak/config.py`
  — **keep the two in sync** if lane/URL validation changes.
- **gdltak** (new repo, v1.0.0) — CoT → GDL90 UDP broadcast so ForeFlight/EFBs display
  the TAK air picture. In the sensor manifest + air/multi roles; egress-only (no
  inbound firewall service). 48 tests incl. the GDL90-spec CRC known-answer.
- **@snstac/cockpit-shared** (new repo, v1.1.0) — shared `serviceCard`/`tlsCard`/
  `envDefaultFile`/`types`. **Source-shipping model**: consumers depend on
  `github:snstac/cockpit-shared#vX.Y.Z` and esbuild bundles the `.ts/.tsx` directly
  (no npm registry, no build step); `cockpit` resolves from each consumer's `pkg/lib`.
  Keyless `npm ci` verified (pacote fetches public repos over anonymous https even
  though the lockfile `resolved` says `git+ssh`). **All five family-B plugins consume
  it** (aiscot v1.2.1, adsbcot v1.2.1, dronecot v1.1.1, lincot v1.1.1, charontak v1.2.0).
  Bumping the shared package = bump its tag, then bump the `#vX.Y.Z` ref in each consumer.
- **README** amd64 claim softened (arm64 today, amd64 planned) — tracking #129
  (installer-script path first: the apt repo + overlay deb already run on any Debian host).

Issue tracker triaged **42 → 11 open** (each closure commented with what superseded it).

**Next hardware session**: flash the milestone image below and exercise all six
cockpit-aryaos cards + verify the Cockpit expired-password first-login flow (the
prerequisite for a first-login wizard); good `09-security.sh` test candidates. Then:
amd64 installer (#129), unified COP map, track record/replay (#8/#9), and the cockpit
plugins still on vanilla-JS could adopt cockpit-shared patterns.

## Current known-good build

- Latest successful dev image: `v2026.07.17.165541-5fa79a7bfae5-dev` — **the milestone
  build**: first image with gdltak, the four field-support helpers, device roles, and
  working SBOM attachment.
- Release: https://github.com/snstac/aryaos/releases/tag/v2026.07.17.165541-5fa79a7bfae5-dev
- Assets verified present: `image_*.img.xz`, `aryaos-overlay_2.1_all.deb`, `*.spdx.json`,
  `*.cdx.json`.
- Notes: **dev/lab image** (`aryaos-dev-lab` SSH key, passwordless `pi` sudo, no
  first-boot password expiry). Do not field it. For a release image, dispatch the
  Pi-gen workflow with the `release` input checked.
- Watch: the apt index refreshes on the packages repo's daily/push publish — the new
  plugin deb versions (cockpit-aryaos 1.3.0 etc.) reach deployed units via one-click
  updates once that runs.

Recent build blockers fixed:

- `sikw00fcot.service` was missing AryaOS site config inheritance. Root cause was
  a broken `sed` expression in `stage-charontak` that used `/` as the delimiter
  while matching `/etc/default/<svc>`. Fixed in `81ca548` with a path-safe `awk`
  insert. Keep site `EnvironmentFile=/etc/aryaos/aryaos-config.txt` before the
  service-specific `/etc/default/<svc>` line.
- GitHub release publishing failed on immutable releases because
  `softprops/action-gh-release` published the prerelease before uploading the image
  asset. Fixed in `abe8e41` by using `gh release create`, which creates a draft,
  uploads assets, then publishes.
- `sikw00fcot` depends on `python3-pymavlink`; that package is now published from
  https://github.com/snstac/python3-pymavlink and indexed by
  https://snstac.github.io/packages.

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
   loop-mounts every built image and asserts ~58 facts (packages, units, files, and
   the lab/release security contract) before anything publishes.

## Architecture invariants (don't break these)

- **Site-config inheritance**: every gateway unit loads
  `EnvironmentFile=-/etc/aryaos/aryaos-config.txt` *before* its own
  `/etc/default/<svc>` — site sets defaults, per-service values override. The
  injection happens in each stage's chroot script (sed after `[Service]`); drop-in
  files would invert the precedence (drop-ins parse *after* the unit file).
- **CoT routing hub**: `adsbcot`, `aiscot`, `dronecot`, `lincot`, and other local
  PyTAK feeders should keep `COT_URL=udp+wo://127.0.0.1:28087`. Charontak listens on
  `udp+ro://127.0.0.1:28087` and owns the external egress lanes: default Mesh SA
  `udp+wo://239.2.3.1:6969`, optional TAK Server, and other tools. Do not point each
  feeder independently at the same TAK Server except for deliberate legacy/debug bypass.
- **apt pinning**: `install-sensor-debs.sh` pins `release o=snstac` at **995** because
  stage-adsbcot pins trixie at 990 and Debian ships an SDR-less readsb that must never
  win. readsb is also `apt-mark hold` (status `hold ok installed` — verify-image
  accepts both hold and install).
- **Exactly one `EXPORT_IMAGE`** stage, last in every `STAGE_LIST` (PR validation
  enforces). `ARYAOS_CI_TRIM_WORK=1` (CI only) deletes stale stage rootfs trees —
  pi-gen full-copies per stage and 72 GB arm64 runners can't hold ~15 copies
  (the fleet has 72 GB *and* 145 GB VMs; never rely on runner luck).
  `increase-runner-disk-size` is broken on arm64 runners — keep it false.
- **Release publication on immutable-release repos**: use `gh release create` for
  releases with image assets. Do not go back to `softprops/action-gh-release` unless
  it is configured to keep the release draft until after asset upload.

## Bluetooth PAN

AryaOS now includes a local-only Bluetooth PAN/NAP service for phone-to-box IP
connectivity without network egress. The service is `aryaos-bt-pan.service`; helper
source is `shared_files/bt-pan/aryaos-bt-pan-nap`; docs are in
[bluetooth-pan.md](bluetooth-pan.md).

Defaults in `/etc/aryaos/aryaos-config.txt`:

```ini
BT_PAN_ENABLED=1
BT_PAN_BRIDGE=pan0
BT_PAN_ADDRESS=10.44.0.1
BT_PAN_PREFIX=24
BT_PAN_DHCP_START=10.44.0.20
BT_PAN_DHCP_END=10.44.0.60
BT_PAN_DHCP_LEASE=12h
```

Expected behavior:

- AryaOS registers a BlueZ Network Access Point on `hci0` and creates `pan0`.
- Paired phones get a DHCP lease on `10.44.0.0/24`; AryaOS is `10.44.0.1`.
- No NAT or forwarding is enabled. This is only for reaching AryaOS local services,
  for example `https://10.44.0.1:9090/`.
- Phone OS support varies. Android vendor builds differ; iOS is usually restrictive
  for arbitrary Bluetooth PAN client use.

## Hardening + one-click updates (new, 2026-07-02)

See [security.md](security.md) for the full posture. Summary of what landed:

- **firewalld** enabled with an explicit allowlist in the default zone
  (`shared_files/aryaos/firewalld/`); AntSDR link pinned to the trusted zone
  via `zone=trusted` in `aryaos-antsdr.nmconnection`. Operators use Cockpit →
  Networking → Firewall. If a new service opens a port, add a firewalld
  service XML + zone entry + verify-image assert, or it will be unreachable.
- **fail2ban** (sshd jail), **sshd drop-in** (`50-aryaos.conf`, password auth
  deliberately stays on), **sysctl** hardening, **unattended-upgrades**
  (Debian security only; snstac origin commented out by design).
- **Per-device web TLS**: `aryaos-firstboot.sh` regenerates the snakeoil key
  and `/etc/lighttpd/ssl/snakeoil-combined.pem` once per device (marker
  `/etc/aryaos/.web-tls-regenerated`). Firstboot also stopped `chown -R
  node-red /etc/aryaos` — Node-RED now owns only the config file, and
  `/etc/aryaos/tls` is `root:tak-certs 0750` with the key `0640`.
- **One-click updates**: `/usr/local/sbin/aryaos-update {check|apply|status}`
  + `aryaos-update.service` (oneshot, survives browser close), driven by the
  *Software updates* card in cockpit-aryaos ≥ 1.1 (falls back to
  `systemd-run` + plain apt on pre-2.1 images). JSON state in
  `/var/lib/aryaos/update-*.json`.
- **aryaos-overlay 2.1** is built by CI and attached to releases as a deb
  asset, so units can upgrade the overlay itself once `snstac/aryaos` is in
  the packages repo `products.txt` (see open items — sequencing matters).
- New verify-image asserts cover all of the above; runtime checks are in
  `scripts/aryaos-test/tests/09-security.sh`.

## GPSTAK (new, 2026-06-12)

`gpstak` package → `/usr/bin/gpstak`: feeds onboard GNSS to TAK
devices per https://ampledata.org/network_gps.html — CoT position events to `COT_URL`
(default `udp+broadcast://255.255.255.255:4349`, ATAK's *External or Network GPS*) and
raw-NMEA passthrough for WinTAK (`NMEA_TARGETS`). Reads gpsd's JSON socket; pytak for
transport (so `PYTAK_TLS_*` applies). Ships **disabled**; managed in Cockpit → GPSTAK
([cockpit-gpstak](https://github.com/snstac/cockpit-gpstak)). Verified live on the dev
Pi. Source and Debian/RPM release packaging live in https://github.com/snstac/gpstak.

## Fleet state (all on pytak >= 7.3.0, releasing versioned debs)

| Repo | Release | Notes |
|---|---|---|
| pytak | 7.3.11 | capability line: cert enrollment, `tak://`, `wss://`, `marti://`, `pytak dp`, `+wo`/`+ro`, MQTT |
| adsbcot 9.1.0, aprscot 8.0.0, inrcot 5.2.1, cotproxy 1.0.1 | Jun 2026 | pipelines modernized (lincot-style ci.yml) |
| aiscot 7.1.4, dronecot 2.1.3, djicot 1.2.0, lincot 1.2.3, charontak 0.1.13, sikw00fcot 1.0.0 | Jun 2026 | charontak ≥ 0.1.13 no longer ships its cockpit plugin in-deb; sikw00fcot is SiKW00F MAVLink fan-out to CoT |
| python3-pymavlink | 2.4.49-1 | packaged for AryaOS so sikw00fcot can install cleanly; pure-Python fallback path, depends on `python3` and `python3-lxml` |
| readsb | 3.16.15-2 | synced to wiedehopf dev; build debs in `debian:trixie` containers because Ubuntu builds depend on `librtlsdr2`, uninstallable on Debian |
| AIS-catcher fork | 0.68 | release workflow runs upstream `build-debian.sh` as root; upstream CI workflows disabled on the fork |
| windtak 1.0.0, takline 0.1.1 | Jun 2026 | |
| cockpit-* ×9 | 1.0.0+ | Cockpit plugins use the dark AryaOS/GPSTAK visual style; watch for regressions to white-on-white UI |

## LINCOT / Host Beacon

AryaOS expects LINCOT v1.3.1+ for dynamic host remarks and gpsd-derived CoT accuracy.
`/etc/default/lincot` sets `GPS_INFO_CMD="gpspipe --json -n 5"` and
`REMARKS_EXTRA_CMD=/usr/local/sbin/aryaos-lincot-remarks`. The helper emits CPU/load,
RAM, swap, disk, temperature, uptime, and Pi throttle state. LINCOT maps gpsd TPV
`altHAE`/`eph`/`epx`/`epy`/`epv` to CoT `hae`/`ce`/`le`.

AryaOS also sets `COT_DETAIL_XML_CMD=/usr/local/sbin/aryaos-cot-detail` so the LINCOT
host beacon carries a structured `<__aryaos>` detail block. `aryaos-neighbord.service`
listens on Mesh SA multicast (`239.2.3.1:6969`) and writes `/run/aryaos/neighbors.json`
for `/cgi-bin/aryaos-neighbors` and the landing-page neighbor table.

## Recurring gotchas (each cost a build this month)

- `gh release upload` fails on fresh tags — `gh release view || gh release create` first.
- Immutable GitHub releases reject assets uploaded after publication. Use
  `gh release create <tag> <asset> ...`, not a create-then-upload flow that publishes
  first.
- `dpkg-deb -c | grep | head` → SIGPIPE kills dpkg-deb under `set -e`.
- `dh_install` treats destinations as directories (`foo.conf` becomes a *dir*).
- stdeb deb names default to `python3-<name>` without `stdeb.cfg` `Package3:`.
- A single private/release-less repo in `products.txt` kills the whole publish
  ("release not found"); publishes racing a just-pushed tag fail the same way.
- This repo has `core.fileMode=false` — `git update-index --chmod=+x` for scripts.
- GitHub GraphQL intermittently 401s here; use REST (`gh api`) with retries.

## Dev lab

Known lab hosts recently used:

- `pi@aryaos-dev-pi` / `pi@172.17.2.158`: original default dev Pi; may be unreachable
  depending on current lab network.
- `192.168.0.199`: ADS-B box used for readsb/adsbcot/gpsd/dashboard checks.
- `192.168.0.13`: UAS-mode box with AntSDR and BlueMark DroneScout bridge DS100.

Use the lab SSH key in `shared_files/aryaos/ssh/` where possible. Integration suite:

```bash
ARYAOS_SSH=pi@<host> ./scripts/aryaos-test/run.sh
```

After flashing the latest dev image, first checks should include:

- `systemctl status charontak lincot adsbcot aiscot dronecot sikw00fcot`
- `/cgi-bin/aryaos-portal-status` and `/admin/aryaos`
- `gpsd` data on GPS-capable units
- `readsb` and `/run/adsb/aircraft.json` on ADS-B units
- AntSDR Ethernet reachability and dronecot feed behavior on UAS units
- Bluetooth pairing plus `aryaos-bt-pan.service`/`pan0` on Bluetooth-capable units

## Open items / next handoff tasks

0. **Hardening burn-in (2026-07-02)**: flash the first post-hardening dev
   image and run the integration suite (esp. `09-security.sh`). Watch for
   firewalld regressions: comitup hotspot onboarding, Bluetooth PAN DHCP,
   Mesh SA neighbor discovery, AntSDR → dronecot, Docker-published CloudTAK
   ports, Node-RED/AIS-catcher dashboards. Then, **after the first release
   with the `aryaos-overlay_*_all.deb` asset exists**, add `snstac/aryaos` to
   packages `products.txt` (adding it earlier breaks the whole publish —
   `gh release download` fails on a release with no deb assets).
1. **Flash and test the latest dev image**: burn
   `v2026.06.23.212757-abe8e41bf5e2-dev`, then run the integration suite against the
   current lab ADS-B and UAS boxes. Pay special attention to `sikw00fcot`, Charontak
   inheritance, and the new Bluetooth PAN service.
2. **Bluetooth PAN live validation**: pair an Android phone to AryaOS, confirm it
   receives `10.44.0.20-60`, confirm `https://10.44.0.1:9090/` works, and confirm no
   unwanted NAT/default-route behavior is introduced.
3. **AntSDR operational follow-through**: keep the AntSDR path focused on
   `alphafox02/antsdr_dji_droneid`; do not rely on DroneScout containers for this
   setup. Verify the matching Ethernet interface comes up and that dronecot consumes
   the AntSDR output.
4. **Release hygiene**: for dev builds, verify published prereleases have the image
   asset attached. Delete empty prereleases immediately if publish fails after tag
   creation.
5. **takline + windtak are private** — the packages publish token can't read them;
   flip public (`gh repo edit snstac/<r> --visibility public
   --accept-visibility-change-consequences`), then add to `products.txt`.
6. **Archive** `spotcot` (pre-pytak-5, dormant since 2022) and `cockpit-sdrconnect`
   (unmodified cockpit-dronecot clone, no releases).
7. **Delete** stray fork `snstac/AIS-catcher-1` (accidental duplicate).
8. adsbcot PyPI job needs a **trusted publisher** configured on PyPI (release works
   regardless; the job just reads red).
9. Possible next plugins: charontak *lane editor* (structured `charontak.ini` UI —
   current plugin is a raw editor), windtak/aprscot pages; backport SIGPIPE
   fixes everywhere `dpkg-deb -c | head` survives.
10. Node-RED runtime check after the worldmap 5.x / tfr2cot 2.0 major bumps
   (palette installs now go through the npm 11 override).
