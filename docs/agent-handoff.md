# Agent handoff - state as of 2026-08-21

Working notes for agents (and humans) picking up AryaOS and the snstac fleet.
Supersedes the 2026-05-16 handoff in [portal.md](portal.md).

## 2026-08-21 GutCheck discovery and explicit DroneCOT DJI development tree

- GutCheck 0.4.0 now owns AryaOS neighbor discovery: rich CoT plus
  identity-only `_aryaos._tcp.local.` DNS-SD and SSDP. It writes the compatible
  portal cache at `/run/gutcheck/neighbors.json`; the old root-running
  `aryaos-neighbord` implementation is retired during overlay upgrades.
- DHCP-less Ethernet discovery relies on the optional, default-enabled IPv4LL
  fallback. CoT and SSDP transmit on every eligible active IPv4 interface.
- Dev-device tooling has no static lab address or required SSH alias. It sends
  GutCheck SSDP searches while listening for LINCOT CoT, expands the resulting
  seeds through the GutCheck neighbor cache, and requires an explicit selector
  when more than one device is present.
- AryaOS overlay 2.2.0 replaces the ambiguous generic DJI service with
  `dronecot-dji.service` and `/etc/default/dronecot-dji`. The upstream package,
  executable, and user remain named `dronecot`; the upstream generic unit is
  masked and has no alias. Upgrade migration preserves existing DJI settings
  and enabled state.
- The SSH pre-auth banner is now a full authorized-use notice installed with
  CRLF line endings for Windows clients. Local console, MOTD, and the landing
  page carry matching language; the support URL is `https://aryaos.org`.
- Component release order before the next image build: GutCheck 0.4.0,
  cockpit-dronecot 1.2.0, package-index refresh, then AryaOS 2.2.0. The overlay
  deliberately depends on GutCheck >= 0.4.0, so an image cannot silently ship
  the old discovery implementation. GutCheck's Makefile package targets are
  version-specific so an existing `deb_dist/` cannot rebuild an older release.

## 2026-08-16 zeroize credential and target closure

- AryaOS overlay 2.1.19 closes two live-test zeroize gaps. Zeroize now
  replaces and expires the `pi` password, locks every other interactive local
  account and root, removes all local SSH authorized keys and the lab sudo
  grant, and erases shell histories. A reset unit returns to the published
  bootstrap password but requires it to be changed at the next login.
- Zeroize now wipes the active site and COTBridge configuration before
  restoring the packaged defaults. This removes the prior TAK Server target as
  well as its TLS credentials, rather than leaving an unusable endpoint string
  behind.
- Restoring an older full backup after zeroize now reconciles the deliberately
  excluded per-device web certificate. If the restored first-boot marker exists
  but Lighttpd's combined PEM does not, the restore helper regenerates the PEM
  before restarting services; otherwise it clears the marker so first boot can
  retry. A live `.45` restore with the PEM intentionally absent regenerated it,
  returned Lighttpd to active, and passed another complete strict HIL run.
- A destructive live zeroize on AryaAir `192.168.0.45` proved that the sentinel
  password hash was replaced and expired, SSH keys and lab sudo access were
  removed, packaged site/COTBridge defaults were restored byte-for-byte, and
  TAK TLS material was gone. The retained root session then restored the
  operating configuration and lab access, rebooted the node, and a fresh
  post-recovery backup was created. Temporary off-device recovery material was
  securely removed after validation.
- The final overlay package is `aryaos-overlay_2.1.19_all.deb`, SHA-256
  `1667108dc90f7ca484e9f95933d2123118d7e379292eb409a1ed829d61dfbc3c`.
  That exact artifact is installed on `.44`, `.45`, `.149`, and `.199`. All
  four report zero failed units, an HTTP 200 portal, configured TAK TLS, and a
  healthy connected COTBridge output. All 165 local unit tests, shell checks,
  Ansible syntax validation, and every strict fleet HIL run passed. Evidence is
  in `.aryaos-lifecycle/20260816T020000Z-zeroize-2.1.19-deploy/`.

## 2026-08-14 fleet lifecycle release gates

- The lifecycle HIL runner now exercises encrypted backup, restore integrity,
  TAK enrollment, enrollment rollback, support bundles, and an allowlisted
  factory reset. Interrupted enrollment automatically restores the active
  node's full backup. Enrollment credentials and recovery material remain
  outside command lines and logs.
- Enrollment validates the peer certificate chain, then records either the
  requested DNS name or its certificate-backed short form as COTBridge's
  expected TLS hostname. It refuses unrelated certificate names and keeps CA
  and hostname verification enabled.
- COTBridge 1.0.1 closes read-only UDP ingress transports when TLS egress setup
  fails, preventing reconnect attempts from leaking the local socket and
  ending in `EADDRINUSE`. AryaOS overlay 2.1.18 and both image/HIL gates require
  that COTBridge floor.
- Factory reset uses noninteractive `--force-confnew` package restoration with
  a bounded timeout. This prevents a hidden conffile prompt from stalling an
  unattended reset while still restoring packaged gateway defaults.
- The burn-in runner now records network and USB evidence and has an enforced
  acceptance evaluator for service health, restarts, storage, temperature,
  network continuity, portal responses, and decoder activity.
- The ADS-B pi-gen package list no longer explicitly requests unused
  `uuid-runtime`. With the temporary Bookworm dependency source enabled for
  FlightAware, that request selected Bookworm 2.41-5 against Trixie's
  security-updated 2.41.5 libraries and blocked every image build.
- The image release workflow marks SemVer prerelease tags such as
  `v2.0.0-rc1` as GitHub prereleases even for field-safe builds; stable SemVer
  tags remain normal releases.

## 2026-08-14 DragonEgg position latency

- DragonEgg `192.168.0.149` had a healthy live 3D GPS fix, but the landing CGI
  waited about seven seconds for an arbitrary 40-report ceiling and the
  Cockpit AryaOS location card requested 12 gpspipe reports. The CGI now exits
  on a complete TPV/SKY snapshot with a three-second worst-case bound, accepts
  gpsd's compact `nSat`/`uSat` counters, and retains partial/no-fix behavior.
- Sibling `cockpit-aryaos` requests eight reports, measured at about 0.7 seconds
  on this receiver while retaining both TPV and SKY. Package `2.0.2-1`
  (`sha256:2128f6c4e5c941a6c6ac01df060b922c531372391b9fa2eaca079c4aaa7d9b21`)
  is installed on `.149`; the image and HIL floors now require 2.0.2.
- Five warmed live CGI samples returned in 0.42-0.95 seconds with a current 3D
  position and eight used satellites. The first request immediately after a
  lighttpd reload was a separate 9.6-second cold-start outlier. GPSD, GPSCOT,
  LINCOT, ACARSDEC, and ACARSCOT all remained active with zero restarts.

## 2026-08-14 DragonEgg LimeSDR portal inventory

- The landing portal now recognizes a LimeSDR Mini by its `Lime Micro` USB
  descriptors on the shared FTDI FT601 `0403:601f` bridge without opening the
  SDR. Its radio row exposes structured `frequency_range_mhz` metadata and the
  UI renders the published 10-3,500 MHz range in a dedicated Coverage column.
  Generic FT601 devices are not classified as LimeSDRs.
- Unit coverage exercises both the Lime match and the generic-FT601 rejection;
  HIL requires the identity and range whenever a LimeSDR Mini is present in
  sysfs. The focused Python, shell, and JavaScript checks pass.
- The three portal assets are deployed on DragonEgg `192.168.0.149`. Live JSON
  reports the LimeSDR Mini, serial `1DBB4189078E3F`, and the expected range.
  The sensor strip now includes ACARS gateway state plus a hardware-backed SDR
  chip; the active ACARS path makes the Sensors hero read `1/1`, while the SDR
  tooltip identifies the Lime and its coverage. ACARS decoding remained active
  with zero restarts through deployment.

## 2026-08-14 AryaAir TAK enrollment repair

- `cockpit-aryaos` 2.0.0 placed the services-card reorder before the `$` DOM
  helper declaration, so the whole AryaOS Site script stopped at load and the
  Enroll button had no listener. The sibling `cockpit-aryaos` source now moves
  that statement after the helper and includes a Node startup-preamble test;
  local package `2.0.1-1` is installed on `192.168.0.199`.
- The first live enrollment then exposed an `aryaos-import-tak-dp` partial-write
  bug: `import_package()` used `scheme` after installing TLS and writing the
  COTBridge lane but before assigning it, so it failed before updating shared
  config or restarting COTBridge. Overlay 2.1.16 assigns the scheme before any
  writes and adds an end-to-end connection-package regression test. The local
  package digest is
  `sha256:95fad1df565b8db3c5ee5a45de15cc0f61560f41a740835ecd970f83d880d109`.
- `.199` is enrolled to `tls://takserver.snstak.com:8089`. The server certificate
  SAN is `takserver`, so the lane pins
  `PYTAK_TLS_SERVER_EXPECTED_HOSTNAME=takserver`; CA and hostname verification
  remain enabled. COTBridge is healthy and connected with rising RX/TX counters
  and zero write errors.
- HIL now compares the configured AryaOS output with the COTBridge site-output
  lane instead of requiring factory Mesh SA, and configured TAK nodes must show
  a healthy connected runtime lane. Closing strict HIL passed all 13 modules;
  evidence is in
  `.aryaos-burnin/20260814T161836Z-aryaair-199-tak-enrollment-closing/`.

## 2026-08-13 CoT naming and health cutover

- Runtime and package identities are now COTBridge, GPSCOT, and GDLCOT. The
  old service, executable, package, config, and Cockpit names are not aliases.
  Package post-install scripts perform a one-time config migration and stop the
  old units.
- Local gateways continue to write to the fixed private bus
  `udp+wo://127.0.0.1:28087`. Operators edit `ARYAOS_COT_OUTPUT_URL`, backed by
  COTBridge `[lane:site-output]`; advanced lane editing remains in the
  COTBridge plugin.
- The shared PyTAK 7.5 status contract adds normalized `health`, `input`, and
  `output` blocks. `aryaos-health status --json` aggregates current daemon
  files and marks data older than 30 seconds as faulty.
- ADS-B config now distinguishes `ARYAOS_ADSB_1090_SOURCE`,
  `ARYAOS_ADSB_1090_DEVICE`, and `ARYAOS_UAT_978_DEVICE`, including ADSBee and
  independent 1090/978 selection.

### Fleet rollout and upgrade-path fixes

- Public releases are PyTAK 7.5.2, COTBridge 1.0.0, GPSCOT 2.0.1, GDLCOT
  2.0.1, SiKW00FCOT 1.0.2, DroneCOT 2.3.9, Cockpit
  COTBridge/GPSCOT/AryaOS 2.0.0, and LINCOT 1.3.8. The signed
  package repository now indexes the renamed public repositories instead of
  their legacy names. Gutcheck remains private and must not be added to the
  public `snstac/packages` product list; authorized lab deployments use its
  authenticated release asset.
- Gutcheck 0.3.5 displays normalized local gateway and per-instance health. It
  reads public status files directly and falls back to the exact protected
  `sudo -n /usr/local/sbin/aryaos-health --json` command for daemon-owned
  `0600` files. The sudo rule exposes only normalized, read-only health data;
  Gutcheck remains unprivileged. Debian installation also generates a stable,
  protected per-host web token. The service remains opt-in because only one
  mesh node should own external alerting, but dashboard-only instances are
  enabled on the current lab fleet. The API and dashboard retain the AryaOS
  capability, decoder, clock, Bluetooth PAN, and gateway activity fields.
  Active gateways without runtime telemetry remain visible as unknown, while
  disabled roles are omitted. DroneScout receive and emit counters are shown
  directly. Mixed-version beacon aliases that differ only by an `aryaos-`
  prefix on a 32-character machine ID collapse to one entity; unrelated UIDs
  remain unchanged.
- DroneCOT 2.3.9 gives each systemd instance its own status namespace through
  `STATUS_APP` and `STATUS_PATH`. This fixes the mismatch between the
  `dronecot-dronescout` runtime directory and the former hard-coded
  `dronecot` status path. The DroneScout status files now survive normal
  service starts and appear in Gutcheck with live receive and emit counters.
- AryaOS overlay 2.1.15 includes the canary and reboot fixes: it packages
  `aryaos-health`, feeder ordering drop-ins, the protected Gutcheck collector,
  and independent site-output and ADS-B keys without replacing operator
  configuration. It keeps serial discovery off a verified ADSBee Beast port,
  orders `readsb.service` after serial assignment, and migrates enabled legacy
  COTBridge lanes to one `site-output` lane while disabling the old sections to
  prevent duplicate CoT. Its SiKW00FCOT systemd drop-in resets and rebuilds
  the environment-file order under `/etc`, so a vendor package upgrade cannot
  discard the site-wide CoT input while service-local overrides still win.
  Repeated serial discovery also preserves a present, non-conflicting GPS
  assignment by stable by-id path. This avoids reopening a verified CP2102N
  receiver, its unsupported eight-second hardware PURGE timeout, and an
  unnecessary gpsd/GPSCOT interruption; missing or changed hardware still gets
  full protocol discovery. Overlay upgrades now migrate only missing gpsd keys
  instead of restoring the factory `DEVICES=""` template over a live receiver.
  Gateway health now includes systemd enablement and live unit state. Disabled
  inactive roles do not degrade the appliance, while an enabled failed or
  inactive unit overrides a stale healthy status document. An active gateway
  without a status contract remains visible as unknown. The fallback neighbor
  beacon now uses the same bare machine ID as LINCOT so new nodes do not create
  duplicate fleet entities. Full configuration backups now retain the private
  Gutcheck defaults and web token plus the local ACARS decoder settings.
  Shareable `--no-secrets` backups continue to omit the secret-bearing
  Gutcheck file while retaining the decoder configuration. The landing portal
  now points operators to Admin for TAK connectivity configuration while
  retaining the security boundary that keeps mutation off the unauthenticated
  page.
- Node-RED now locks `socket.io-parser` 4.2.7, the first release that fixes
  GHSA-2m8v-j782-fhvr. Image verification and strict live HIL enforce that
  floor. Dependabot alert 75 is closed as fixed, and security workflow
  `31758220131` passes both the Python documentation and Node-RED npm jobs.
- Current lab nodes are `192.168.0.44` (AIS), `192.168.0.45` (ADSBee, DS110,
  GNSS), and `192.168.0.199` (ADSBee, DroneScout, GNSS). `.44` and `.45` run
  overlay 2.1.15; `.199` runs the enrollment-fix overlay 2.1.16. All three use
  PyTAK 7.5.2, COTBridge 1.0.0, GPSCOT/GDLCOT 2.0.1,
  SiKW00FCOT 1.0.2, LINCOT 1.3.8, DroneCOT 2.3.9, Gutcheck 0.3.5, and
  `socket.io-parser` 4.2.7. A single controlled reboot changed every boot ID;
  all 13 strict HIL modules then passed on every host. Node-RED flows, settings,
  and package manifest retained their pre-upgrade hashes. `.45` and `.199`
  report healthy `dronecot-dronescout` instances in Gutcheck with rising
  counters and zero write errors; `.44` reports its COTBridge, GPSCOT, LINCOT,
  and AISCOT gateways.
- A paced test delivered all 5,000 generated CoT events per node at about 675
  events per second with zero COTBridge write errors. A 50,000-event burst
  exercised UDP saturation without service failure. Four-core CPU load peaked
  at 73.3 C on `.44`, 74.9 C on `.45`, and 49.1 C on `.199`, with
  `throttled=0x0` everywhere and no core-service restarts.
- PyTAK 7.5.2 exposes `supervise_with_reconnect()` for gateways with custom
  worker graphs. GPSCOT 2.0.1, GDLCOT 2.0.1, and SiKW00FCOT 1.0.2 use it so a
  transient remote outage or local firewall replacement rebuilds fresh
  transports without exiting the daemon. Fatal configuration and certificate
  errors remain fatal.
- Live recovery testing repeatedly reloaded firewalld on all three nodes. On
  `.45`, eight reloads reproduced UDP `EPERM` in both GPSCOT and DroneCOT;
  both logged a bounded retry, rebuilt their transports, and resumed rising
  counters with their original PIDs and `NRestarts=0`. Four reloads on `.199`
  produced the same DroneCOT recovery, again without a PID change or systemd
  restart. Four reloads on `.44` left GPSCOT and AISCOT active with unchanged
  PIDs and zero restarts. Evidence is in the `pytak-7.5.2-*-recovery-*.log`
  files in the burn-in directory.
- A deliberate `.45` COTBridge output outage also left the service active with
  zero restarts and correctly reported `degraded` and `retrying`. Restoring
  the output returned it to `ok` and `connected`, with traffic flowing again.
- The planned eight-hour run was stopped at the operator's request to prioritize
  the closing software deployment. The primary sampler still collected 2,037
  successful observations over 5 hours 39 minutes, 679 per host, with no probe
  failures, failed units, throttling, filesystem alerts, or automatic service
  restart growth. Peak temperatures were 65.55 C on `.44`, 65.55 C on `.45`,
  and 40.8 C on `.199`. The expanded sampler collected another 1,482 successful
  observations, 494 per host. During the primary window, `.45` DroneScout
  received 123,583 records and emitted 247,166 events; `.199` received 116,147
  and emitted 232,294. `.44` AISCOT received 85 records and emitted 64 events.
  Every observed gateway write-error range remained `[0,0]`.
- Burn-in evidence is collected under the gitignored
  `.aryaos-burnin/20260813T1907Z-post-2.1.4/` directory. Check `summary.json`
  and the per-node HIL logs before drawing conclusions. The directory
  name records the starting deployment; the nodes were upgraded in place to
  overlay 2.1.15, PyTAK 7.5.2, GPSCOT/GDLCOT 2.0.1, SiKW00FCOT 1.0.2,
  DroneCOT 2.3.9, Gutcheck 0.3.5, and `socket.io-parser` 4.2.7 after sampling
  stopped. Closing strict HIL logs are `closing-2.1.15-hil-{44,45,199}.log`;
  all modules pass. `.44` has no warnings and observes live AIS NMEA. `.45` and
  `.199` only warn that their disabled AIS role is inactive and that no ADS-B
  aircraft were present during the closing sample. The exact CI release package
  was then reinstalled on all three hosts; `release-2.1.15-hil-{44,45,199}.log`
  records the same all-module pass. Full live backups include both
  `/etc/default/gutcheck` and `/etc/default/acarsdec`; shareable backups exclude
  Gutcheck while retaining ACARS decoder settings. Image workflow `31736340576`
  exposed an escaped-regex bug in
  the mounted-image verifier; commit `9b96407` fixed it, and replacement run
  `31738934689` passed image creation, mounted-image verification, SBOMs, tag
  creation, and release publication. Runs `31741703758` and `31741941854` were
  superseded while live HIL exposed the SiK drop-in and gpsd upgrade-path
  defects. Final image workflow `31743281559` built commit `2a24944` and passed
  image creation, mounted-image verification, SBOM generation, tag creation,
  and release publication. Prerelease
  `v2026.08.13.211809-2a249441c77e-dev` contains the resulting image, overlay
  2.1.10 package, image metadata, and both SBOM formats.
- Image workflow `31755011645` built commit `3421047` and passed all
  image creation, upload, mounted-image verification, SBOM, tag, metadata,
  overlay, and release steps. The mounted verifier reported 315 checks passed
  and zero failed. Prerelease
  `v2026.08.14.000533-342104777806-dev` contains the image, overlay 2.1.12,
  image metadata, and SPDX and CycloneDX SBOMs. The release tag resolves to the
  exact implementation commit.
- Image runs `31757974913` and `31758220090` were canceled as superseded after
  the live backup audit found missing ACARS decoder coverage and closing HIL
  found the landing portal configuration dead end. Overlay 2.1.15 contains both
  fixes.
- Authoritative image workflow `31759507279` built commit `cced9da`, passed 317
  mounted-image checks with zero failures, generated SPDX and CycloneDX SBOMs,
  and published prerelease `v2026.08.14.012330-cced9dae79da-dev`. Its
  `aryaos-overlay_2.1.15_all.deb` digest is
  `sha256:dd39aab638f1459f9a7fd94433d7078e8bc126cba41850b4fd4c1022b67dca7a`;
  that exact asset is installed on `.44`, `.45`, and `.199`.

!!! tip "Looking for what to work on next?"
    Outstanding work and follow-ups live in **[Roadmap & next steps](roadmap.md)**.
    This handoff covers the running build/merge state and architecture invariants.

## 2026-08-12 DroneScout binary MAVLink CRLF recovery

### One-hour AryaAir/AryaSea acceptance after 2.0.25 rollout

- `192.168.0.44` (AryaSea) and `192.168.0.45` (AryaAir) completed a paired
  one-hour burn-in after upgrading to `aryaos-overlay 2.0.25` and
  `dronecot 2.3.8-1`. The sampler collected 720 successful probes, 360 per
  host, with no probe failures, failed units, service drops, restart-count
  growth, throttling, filesystem alerts, or boot-ID changes.
- AryaSea peaked at 62.8 C, load 0.71, 11.43% memory, and 23.11% disk usage;
  memory moved +0.57 percentage points. AryaAir peaked at 63.9 C, load 1.06,
  6.33% memory, and 23.13% disk usage; memory moved +0.33 points. Both root
  filesystems stayed clean. The only warning was the known Broadcom Wi-Fi
  management-IE `-52` message, with 30 unique events per host.
- AryaSea kept AIS-catcher and AISCOT active in all 360 samples. Its gateway
  counters were quiet during the exact sampler window, but the post-burn-in
  strict suite observed live AIS NMEA. AryaAir kept readsb, ADSBCOT, and
  `dronecot-dronescout` active in all 360 samples. Its DS110 added 24,330
  received records and 48,660 emitted events with zero DroneCOT restarts.
- All 13 strict HIL modules passed on both hosts after the soak. Evidence is in
  the gitignored `.aryaos-burnin/20260813T022127Z-aryaair-aryasea-1h/`
  directory. The authoritative health result is `summary.json`; final suite
  logs are `post-burnin-hil-44.log` and `post-burnin-hil-45.log`.
- AryaOS commit `e23106a` passed pull-request validation run `31657308366` and
  image run `31657314290`. The latter completed image creation, mounted-image
  verification, SBOM generation, tag creation, and release publication.

- Fresh AryaAir host `192.168.0.45` has an ADSBee, a BlueMark DroneScout DS110
  on the ESP32-S3 USB CDC path, and a CP2102N GNSS receiver. AryaOS discovery
  now identifies the live DroneScout from checksum-valid MAVLink heartbeat and
  `OPEN_DRONE_ID_MESSAGE_PACK` traffic and applies `adsb rid`. The dedicated
  `dronecot-dronescout` instance is enabled and the landing portal reports UAS
  active.
- A byte-for-byte 30-second capture found 250 nominal MAVLink frames. The DS110
  USB output expanded every LF byte to CRLF, including LF bytes inside binary
  MAVLink headers, payloads, and checksums, and appended a newline after each
  frame. Most apparent pymavlink `BAD_DATA` was the harmless frame delimiter,
  but 12 of 250 frames were checksum-invalid because an embedded LF had been
  expanded. Reversing CRLF to LF recovered all 250 frames with valid checksums:
  220 OpenDroneID packs and 30 heartbeats.
- DroneCOT `v2.3.8`, commit `b90850d`, adds opt-in
  `SERIAL_CRLF_NORMALIZE=1`. The streaming filter preserves state across serial
  read boundaries and defaults off for compliant receivers. Unit coverage
  includes every split point through expanded CRLF pairs and an end-to-end
  pymavlink checksum regression. The canonical suite passes 106 tests with one
  skip and 14 subtests; targeted Black and flake8 checks pass.
- AryaOS 2.0.25 enables the workaround only in
  `/etc/default/dronecot-dronescout`. Image verification now requires DroneCOT
  2.3.8 and that setting. Live HIL on `.45` with the locally built
  `dronecot_2.3.8-1_all.deb` decoded 329 RID records in 45 seconds, matching the
  330 expected from the raw rate within the sampling boundary. CoT for lab RID
  `1787F04BM24010011195` reached COTBridge with current position. The service
  remained enabled and active with zero restarts, no failed units, and no Pi
  throttling.
- The same host passed all 13 strict AryaAir HIL modules after the DroneCOT and
  overlay upgrade. DroneCOT PyPI workflow `31656496938` and Debian release
  workflow `31656496947` both succeeded; release `v2.3.8` contains
  `dronecot_2.3.8-1_all.deb`. Signed package repository workflow
  `31656860708` published 2.3.8 for fleet updates.
- When installing a locally built DroneCOT package on an existing AryaOS box,
  preserve its modified `/etc/default/dronecot` conffile explicitly, for
  example with `dpkg --force-confold --configure dronecot` if a noninteractive
  local-package install stops at the conffile prompt.

### AryaAir/AryaSea fleet update and acceptance

- AryaOS commit `e23106a` scopes CRLF normalization to protocol-verified
  `esp32-usb` Remote ID transports. The role manager writes `0` for compliant
  UART transports, and the overlay migration enables it only when the live
  `/dev/dronescout` udev vendor is Espressif (`303a`). The complete 120-test
  repository suite, Ansible syntax check, shellcheck, overlay package build,
  and PR validation run `31657308366` pass. Image run `31657314290` completed
  all build, mounted-image verification, SBOM, and publication steps from that
  implementation commit. Release
  `v2026.08.13.013732-e23106aa5fac-dev` contains the resulting image and overlay.
- `192.168.0.44` (`aryaos-b6b9`, AryaSea) and `192.168.0.45`
  (`aryaos-fdb9`, AryaAir) now run overlay 2.0.25 and DroneCOT 2.3.8. The
  update retained all role, GNSS, AIS, ADS-B, and gateway configuration hashes
  and preserved service enablement. AryaSea has `SERIAL_CRLF_NORMALIZE=0` and
  AryaAir's ESP32-S3 DS110 has `SERIAL_CRLF_NORMALIZE=1`. Neither host required
  a reboot.
- Both hosts passed all 13 strict HIL modules before and after a 15-minute
  paired acceptance soak. The sampler collected 180 successful probes, 90 per
  host, with no probe failures, failed units, service drops, restart growth,
  throttling, filesystem alerts, or boot-ID changes. AryaSea peaked at 61.7 C,
  load 0.07, 11.13% memory, and 23.11% disk. AryaAir peaked at 60.05 C, load
  0.59, 5.98% memory, and 23.13% disk. Memory changed only +0.25 and +0.13
  percentage points respectively. The only journal warning was the known
  Broadcom Wi-Fi management-IE `-52` message.
- AryaAir decoded 6,173 live Remote ID payloads during the final 15-minute
  window. The current DroneScout process had zero restarts and no checksum,
  traceback, bad-data, or runtime errors after startup; the portal reported
  UAS up through `dronecot-dronescout`. AryaSea received one live AIS NMEA line
  near the end of the run; AIS-catcher and AISCOT remained active with zero
  restarts. Evidence is gitignored under
  `.aryaos-burnin/20260813T012330Z-aryaair-aryasea/`, with the authoritative
  result in `acceptance-sampler-15m/summary.json`.

## 2026-08-12 latest-firmware AryaAir/AryaSea regression follow-up

- Fresh-image testing on `192.168.0.44` exposed a discovery dependency: its
  quiet CH340 dAISy could only be assigned after AIS was already enabled, while
  first boot only enabled AIS after discovering an assigned receiver. The
  capability scanner now recognizes the constrained AryaSea layout of one
  CH340 beside a separately verified GPS, and explicitly refuses that guess
  when an AntSDR is present. Live HIL with the AIS assignment temporarily
  cleared returned `ais` as an auto-applied capability and selected the correct
  stable by-id path.
- The same boot produced one AISCOT restart. PyTAK correctly rebuilt the client
  after a refused COTBridge connection, but AISCOT did not close its UDP/5050
  listener before the replacement worker bound the same port. AISCOT 7.3.1
  retains and closes the datagram transport through the PyTAK worker cleanup
  hook. Its regression starts a replacement worker on the same port in the same
  process. AryaOS 2.0.24 and both image/runtime checks require AISCOT 7.3.1 or
  newer.
- AISCOT PR 17 merged as `19c82a5`; release `v7.3.1` produced
  `aiscot_7.3.1-1_all.deb`, and signed repository run `31638850105` published it
  for arm64 and armhf. AryaSea was upgraded to AISCOT 7.3.1 and AryaOS overlay
  2.0.24. The installed package closed and rebound the same UDP port in one
  process, survived a 70-second COTBridge outage with the same PID and zero
  systemd restarts, and retained UDP/5050. After reboot, the six AIS/GPS/CoT
  services were active with zero restarts, no failed units or throttling, and
  all 13 strict HIL modules passed. The final RF window was quiet.
- The first 2.0.24 image attempt, run `31639680637`, reached the Node-RED stage
  and received HTTP 503 from the pinned GitHub release asset. Run `31640434386`
  proved that the browser-facing release CDN remained unavailable through all
  bounded retries. The stage now fetches the same immutable asset through its
  GitHub release API id, retains retry and pinned SHA-256 verification, and CI
  downloads and verifies the payload during its preflight.

## 2026-08-12 AryaAir/AryaSea eight-hour burn-in

- `192.168.0.199` (`aryaos-d628`, AryaAir) and `192.168.0.44`
  (`aryaos-c2cb`, AryaSea) completed an eight-hour mixed hardware-in-the-loop
  acceptance run. The sampler collected 960 successful probes (480 per host)
  with no probe failures, failed units, required-service drops, restart-count
  growth, throttling, filesystem alerts, or boot-ID changes. The role services
  were active in all 480 samples on each host: ADS-B/DroneScout on AryaAir and
  AIS on AryaSea.
- AryaAir peaked at 61.15 C, load 4.46, 21.66% memory, and 23.15% disk usage;
  memory moved -0.29 percentage points. AryaSea peaked at 78.75 C, load 2.06,
  17.62% memory, and 23.93% disk usage; memory moved +1.31 points. The only
  repeated kernel warning was the known Broadcom Wi-Fi management-IE `-52`
  message.
- Two 512 MiB discard-only network passes measured AryaAir at 30.84--35.64
  MiB/s upload and 56.66--63.09 MiB/s download, and AryaSea at 32.51--37.88
  MiB/s upload and 54.85--62.16 MiB/s download. AryaAir completed both
  15-minute 4-worker/512 MiB load phases at no more than 62.8 C. AryaSea's
  guarded tests intentionally stopped four workers at 78.2 C and two workers
  at 78.75 C, with no throttling or service fault; its 15-minute
  1-worker/512 MiB phase passed at 73.8 C. Treat one sustained CPU worker as
  the safe current thermal envelope for the installed AryaSea enclosure.
- Live DroneScout traffic exposed a GDLCOT crash loop: legitimate unknown CoT
  fields arrived as `hae="nan"` and `speed="nan"`, and GDLCOT attempted to
  convert them to integers. GDLCOT 1.0.1 rejects non-finite coordinates and
  treats non-finite altitude/motion as unknown. Its 60-test suite and flake8
  pass, upstream PR 2 is merged as `b57f35c`, release/package `1.0.1-1` is in
  the signed repository, and both live hosts now carry it without changing
  their local configuration. AryaAir processed the same Remote ID stream with
  zero subsequent GDLCOT restarts; AryaSea retains GDLCOT disabled/inactive as
  intended for its role.
- A long-running DroneScout receiver can rotate its one-time MAVLink heartbeat
  line out of the RAM journal even while processing current Remote ID payloads.
  HIL now accepts either the startup heartbeat or live `Processing RID data`
  as MAVLink session proof. The final strict HIL suite passes every module on
  both hosts; ADS-B and AIS were RF-quiet during the final short windows, but
  service ownership, ports, role state, and restart checks passed. Earlier in
  the run, live/synthetic role traffic exercised both complete pipelines.
- AryaOS commit `4c6f0c3` requires `gdlcot >= 1.0.1` in HIL and mounted-image
  verification; `965013e` adds the journal-safe DroneScout HIL assertion and
  this handoff. Final image run `31612196240` passed every build, verification,
  SBOM, and publication step and released
  `v2026.08.12.154348-965013ee9dd1-dev`. Detailed gitignored evidence is under
  `.aryaos-burnin/20260812T020135Z-aryaair-aryasea/`; the authoritative sampler
  result is `acceptance-sampler/summary.json` and the final strict-suite logs
  are `final-hil-aryaair.log` and `final-hil-aryasea.log`.

## 2026-08-11 `chronos` GPSCOT provisioning

- `chronos` is a Raspberry Pi Zero W at `192.168.0.200`, running 32-bit
  Raspberry Pi OS Bookworm. Use `gba` and the AryaOS development SSH key.
- `playbooks/gpscot-generic.yml` is the minimal, repeatable provisioning path.
  It assigns the PL011 to a GPIO14/15 GNSS receiver, disables Bluetooth and the
  serial console, installs only gpsd/GPSCOT from the signed snstac repository,
  and broadcasts `GPSCOT-chronos` CoT on UDP/4349.
- Run it with `ansible-playbook -i inventory.yml playbooks/gpscot-generic.yml --limit chronos`.
  Cockpit, LINCOT, COTBridge, and the rest of the AryaOS
  sensor stack are deliberately outside this host profile.
- Provisioning installed `gpscot 1.0.1-1` and `pytak 7.4.3-1`. gpsd identified
  the receiver as an MTK-3301 at 9600 baud and reported a mode-3 fix with 11 of
  13 satellites used. A LAN capture verified `GPSCOT-chronos` CoT from
  `192.168.0.200`, including GNSS-derived CE/LE, altitude, course, and speed.
- HIL passed a forced gpsd restart without restarting GPSCOT, a 12-sample soak
  with a continuous 3D fix and zero service restarts, an idempotent playbook run
  (`changed=0`), and a second reboot. The post-reboot host had no failed units,
  no Pi throttling, and about 284 MiB available memory.
- Original boot files are retained as `config.txt.pre-gpscot` and
  `cmdline.txt.pre-gpscot` under `/var/backups/aryaos-gpscot`. To roll back the
  UART reassignment, stop/disable GPSCOT, restore those two files to
  `/boot/firmware/`, re-enable `hciuart.service`, unmask any needed serial-getty
  unit, and reboot. Restoring the originals re-enables the serial console and
  returns the PL011 to Bluetooth.

## 2026-08-11 `.44` refresh and AIS restart hardening

- `192.168.0.44` (`aryaos-c2cb`, Raspberry Pi 5) was refreshed from overlay
  `2.0.18` to `2.0.23`, and all available OS and Cockpit gateway package updates
  were installed. The host now has the fixed scrolling/branding gateway builds
  documented below. Its GPS, AIS, and site configuration hashes were unchanged.
- Repeated first-boot serial discovery exposed a live-service race: the helper
  rewrote already-correct AIS values and requested another AIS-catcher restart
  while its first start was still probing optional backends. AIS-catcher deferred
  SIGTERM, so the unit remained `deactivating` until systemd's 90-second default
  stop timeout. Serial assignment now detects exact no-op writes, tracks AIS
  changes independently from GPS, and restarts AIS-catcher only when its port or
  baud actually changes. A 15-second stop timeout bounds a genuine reassignment.
- A clean reboot retained the stable CP2102N GPS and CH340 dAISy paths. GPSD had
  a 3D fix, AIS-catcher/AISCOT/COTBridge were active with zero restarts, the AIS
  dashboard answered on TCP/8100, and no systemd unit failed. A checksum-valid
  synthetic type-1 report produced `MMSI-366967102` CoT at COTBridge's UDP/28087
  ingress, exercising the complete decoder-to-CoT path while RF was quiet.
- Strict HIL passed all 13 modules. A three-minute, 12-sample burn-in had zero
  probe failures, service drops, restart increments, throttling events, storage
  alerts, or boot-ID changes; peak temperature was 60.05 C, peak load was 0.34,
  and memory moved 0.39 percentage points. Remaining warnings were boot-time
  Docker/firewalld stale-chain cleanup, normal Broadcom Wi-Fi driver noise, two
  recovered CP210x setup timeouts, and chrony correctly rejecting the NMEA-only
  GPS clock's 333 ms offset in favor of network time.

## 2026-08-11 Cockpit gateway scrolling sweep

### LINCOT stylesheet follow-up

- LINCOT had the same design-kit SCSS and React layout as the other gateways,
  but its shipped `index.html` was the only one that did not load `index.css`
  or Cockpit's shared `branding.css`. The UI therefore looked legacy/unstyled
  even though the correct CSS and fonts were present in the package.
- `cockpit-lincot` **1.1.3** adds both links and a source regression. AryaOS HIL
  now verifies the two stylesheet links for all seven gateway plugins, in
  addition to checking their compiled CSS and root scroll containers.
- LINCOT release run `31529704293` and signed repository publish run
  `31529773872` completed successfully. The public arm64 index advertises
  `cockpit-lincot 1.1.3-1` under the existing verified packaging key.
- `.199` was upgraded only from `cockpit-lincot 1.1.2-1` to `1.1.3-1`.
  `/etc/default/lincot` retained SHA-256
  `46554bbb6b92be73e92de33ab80b8bef79d4ffdc0d04dfee470eb3f7bb82d7b8`,
  `lincot.service` stayed active, and the complete strict HIL suite passed,
  including all seven new installed-HTML stylesheet checks.
- AryaOS image run `31530016764` completed successfully from `4b21257`; its
  mount-based verifier enforced `cockpit-lincot >= 1.1.3`. Release
  `v2026.08.11.201034-4b212576cac2-dev` contains the 1.62 GB compressed image,
  image hashes, overlay package, and SPDX/CycloneDX SBOMs.

- Cockpit fixes non-index page bodies in place, but the seven plain-root gateway
  plugins did not provide their own scroll container. Expanding **Debug Logs**
  or **Advanced Details** could therefore expose content below the viewport with
  no way to reach it. `#app` now owns vertical scrolling in ADSBCOT, AISCOT,
  APRSCOT, COTBridge, DroneCOT, LINCOT, and SAPIENTCOT.
- Every plugin has a compiled-Sass regression for the viewport-height root and
  `overflow-y: auto`; the browser-enabled gateway suites also expand Debug Logs
  and prove the root can scroll. AryaOS HIL checks both the minimum fixed package
  versions and the installed (possibly gzip-compressed) CSS rule.
- Fixed release floor: cockpit-adsbcot **1.2.3**, cockpit-aiscot **1.2.3**,
  cockpit-aprscot **0.1.1**, cockpit-cotbridge **1.2.2**, cockpit-dronecot
  **1.1.3**, cockpit-lincot **1.1.3**, cockpit-sapientcot **0.1.1**. The three
  direct GitHub download pins in `stage-aiscot` match those releases; the other
  plugins are sourced from the signed snstac apt repository.
- The first APRSCOT/SAPIENTCOT tag builds exposed a workflow bug: they built the
  packages and then tried to upload into a Release that did not exist. Their
  workflows now create the GitHub Release on demand before uploading assets;
  the fixed tag jobs were rerun successfully.
- All seven releases were ingested by `snstac/packages` publish run
  `31516851407`. The public arm64 index contains the exact release floor above,
  and its `InRelease` has a good signature from packaging key
  `C34ED9FEFE38916133DC7B614F0D93E47D24D367`.
- `.199` (`aryaos-d628`) was upgraded in place from the signed repository. The
  complete strict default-profile HIL suite passed: all seven installed CSS
  rules and versions, live ADSBee/GNSS/DroneScout paths, Remote ID heartbeat and
  payload processing, portal power/branding/capability checks, storage, and
  security. The update did not change gateway service enablement or config.
- AryaOS image run `31517168556` completed successfully from `eec008f`; the
  mount-based image verifier passed the new package floors and the complete
  image content slate. Release
  `v2026.08.11.174209-eec008f09b26-dev` includes the 1.62 GB compressed image,
  `image-info.json`, SPDX/CycloneDX SBOMs, and overlay package.

## 2026-08-10 `.44` AIS HIL

- `192.168.0.44` returned as `aryaos-c2cb` on image `22e7a12` and overlay
  `2.0.15`. Its CP2102N emitted checksum-valid GPS NMEA at 9600 baud; its one
  remaining CH340 serial device was silent and was therefore safely assigned as
  the intended dAISy by elimination when the maritime role was applied.
- AIS-catcher and AISCOT ran with zero steady-state restarts. Live RF produced
  checksum-valid `!AIVDM` traffic for MMSI `3669708`. A synthetic type-1
  position report exercised the complete UDP/5050 path and produced a valid
  `MMSI-366967102` CoT event at COTBridge's loopback ingress, proving
  `serial receiver -> AIS-catcher -> AISCOT -> COTBridge` end to end.
- The strict HIL suite passed every module. Storage was clean, media manufacturer
  ID `0x000027` was valid, the boot PARTUUID matched, and the Pi 5 kernel and
  initramfs artifacts passed size checks. The node had no failed units or
  throttling and retained a 3D GPS fix.
- HIL exposed two defects fixed in overlay `2.0.18`: role application used to
  start AIS-catcher with an empty serial argument before assignment, producing
  two avoidable exits, and AIS-catcher 0.68 enabled its internet community feed
  by default. AryaOS now enables-but-does-not-start the unit, assigns the serial
  receiver first, refuses to start cleanly when the assigned device is absent,
  bounds failures in the unit's `[Unit]` section, and passes `-X off` on serial,
  RTL, and generic-SDR AIS paths. HIL now requires both AIS services, stable
  isolated serial assignment, zero restart loops, local ports, and explicit
  community sharing opt-out.
- Installing the overlay with AIS already active exposed an ordering deadlock:
  `aryaos-serial-assign.service` is ordered before AIS-catcher/GPSD but called
  blocking `try-restart` jobs for those same units. The restarts are now queued
  with `--no-block`, allowing the oneshot to finish before its dependents run.
- A ten-minute post-fix burn-in passed 60/60 probes with one boot ID, no failed
  units, no service drops/restarts, no throttling or filesystem alerts, 58.4 C
  maximum temperature, 0.24 maximum one-minute load, and 0.1 percentage-point
  memory drift. The sampler now tracks `ais-catcher` itself as well as AISCOT.

## 2026-08-10 `.199` reboot and factory-reset HIL

### Replacement-image media failure (historical; card replaced)

- The exact `22e7a12` CI image returned as `aryaos-025f` with overlay `2.0.15`.
  First boot correctly detected and configured ADSBee, DroneScout, and the SiRF
  GPS; the default HIL suite passed every enabled software/hardware path except
  storage. Live DroneScout heartbeat and Remote ID payload checks passed, all
  enabled services were active with no failed units, and the short ADS-B sample
  was RF-quiet.
- `/boot/firmware/cmdline.txt` was again 132 bytes of AArch64 instructions.
  The pristine release image contains the correct 139-byte command line. The
  corrupt bytes match `/usr/bin/node` at file offset `0x19f8000` exactly. On the
  card, boot LBA `35008` and root LBA `2510784` returned the same complete
  512-byte Node sector despite belonging to different partitions. The card
  identifies as `SD32G` with invalid manufacturer ID `0x000000`.
- An offline FAT check then found corrupt directory entries and reclaimed
  42,062,848 bytes in seven orphaned chains. It exposed missing/corrupt Pi 5
  boot artifacts, including `kernel_2712.img` and `initramfs_2712`. The running
  root filesystem and services remain healthy, but **do not reboot or factory
  reset this node**. Replace the microSD card with reputable endurance media,
  flash the current image, and rerun HIL. Forensic evidence is gitignored under
  `.aryaos-burnin/20260810T-new-firmware-forensics/`.
- Overlay `2.0.16` replaces the upstream initramfs `set_partuuid` payload at
  build time. The replacement constructs the new command line in tmpfs, writes
  a separate FAT candidate, syncs and remounts the boot filesystem, and
  requires byte-for-byte candidate and final-path readback (up to five
  allocations) before continuing. HIL now also
  rejects zero manufacturer IDs, binary command lines, and missing/implausibly
  small model-specific kernel/initramfs files.
- A 15-minute post-diagnosis burn-in collected 30/30 successful probes with one
  boot ID, no throttling, no failed units, no service drops or restarts, 33.65 C
  maximum temperature, 0.26 maximum one-minute load, and 0.06 percentage-point
  memory drift. All 30 samples correctly retained the storage alert. The only
  repeated journal message was the known Broadcom onboarding-AP vendor-IE
  warning (`-52`). The enhanced sampler then proved it records the invalid
  manufacturer ID, binary cmdline, and both missing Pi 5 boot artifacts.

### Current `.199` replacement card and live portal capabilities

- `.199` is now `aryaos-d628` on a replacement `GB1QT` card with valid media
  manufacturer ID `0x00001b`. A controlled reboot completed normally. The boot
  command line is printable and names the installed root PARTUUID;
  `kernel_2712.img` and `initramfs_2712` pass the HIL size checks. The prior
  no-reboot restriction applied only to the discarded `SD32G` card.
- First boot discovered `ARYAOS_CAPABILITIES="adsb rid"`: ADSBee feeds readsb
  over its stable Mode-S Beast serial path, DroneScout feeds
  `dronecot-dronescout` through `/dev/dronescout`, and the PL2303 GPS has a live
  3D fix. The strict suite confirms Remote ID heartbeat and payload processing,
  zero failed units, clean storage, and no service restart loop.
- Overlay `2.0.19` fixes the HTTPS landing page's UAS state. The page used to
  inspect only legacy `dronecot.service`, so a live DroneScout, Wi-Fi/BLE RID,
  or SAPIENT gateway appeared disabled. The UAS item now aggregates all of
  those live implementations and exposes their member-unit states in portal
  JSON. The hero SENSORS count considers only activated sensor gateways, not
  disabled capabilities or the always-on CoT/GNSS core. On `.199`, the portal
  now reports ADS-B and UAS/Remote ID active and healthy.
- The packaged overlay was installed on `.199`; the complete post-install
  strict HIL suite passed every module. Expected warnings were limited to
  deliberately disabled AIS/SiK, the absent unauthenticated TAK configuration
  pointer, and a brief RF-quiet ADS-B sample. Remote ID remained live.
- Actions run `31465778187` built commit `643f5c2` in 24m13s. Finished-image
  verification reported **281 ok, 0 failed**. The image, overlay `2.0.19`,
  image metadata, and SPDX/CycloneDX SBOMs are published in prerelease
  `v2026.08.11.065730-643f5c2d0baa-dev`.
- Overlay `2.0.20` restores the landing page's POWER status. Debian's lighttpd
  sandbox has `PrivateDevices=yes`, which hid `/dev/vcio_gencmd` even though
  `www-data` was already in the `video` group. The AryaOS drop-in retains the
  private device namespace and bind-mounts/allows only that firmware-command
  character device. `.199` now reports `throttled=0x0` / POWER **OK** through
  the HTTPS CGI. HIL asserts the telemetry block on Pi, and the UI explicitly
  says **UNKNOWN** instead of remaining blank if it becomes unavailable.
  Actions run `31502191920` built commit `c8fbead` in 21m22s; finished-image
  verification reported **281 ok, 0 failed**. Prerelease
  `v2026.08.11.145102-c8fbead1c1e2-dev` contains the image, overlay, image
  metadata, and SPDX/CycloneDX SBOMs.
- Overlay `2.0.21` replaces Cockpit's legacy rounded teal tile and generated
  `A` at `/admin/` with the exact reverse AryaOS Signal Block from the design
  guide. The stylesheet now uses the Console Ink, Paper, Field Green, and
  Signal Orange tokens, and the overlay installs the canonical SVG into both
  Cockpit OS-brand directories. On `.199`, both the served CSS and SVG match
  the repository byte for byte; the mark is publicly available before login
  at `/admin/cockpit/static/mark-aryaos-rev.svg`. The portal HIL module asserts
  the live asset, color, and CSS reference. The full local 107-test suite and
  Ansible syntax check pass. The strict HIL branding, portal, service, storage,
  and hardware checks pass. The first post-install run recorded one transient
  DroneScout UDP `EPERM` while the overlay reloaded the firewall; the service
  recovered, its counter was cleared after confirming the cause, and the full
  strict rerun passed with continued live RID processing and zero restarts.
  The first CI attempt (`31508617396`) correctly failed when pi-gen's container
  could not see the canonical `docs/brand` source; commit `ad682b1` adds that
  directory as a read-only build input and regression-tests the mount. Rerun
  `31509326669` succeeded in 23m07s with **287 ok, 0 failed** from finished-image
  verification. Prerelease `v2026.08.11.161055-ad682b1257fe-dev` contains the
  image, overlay `2.0.21`, image metadata, and SPDX/CycloneDX SBOMs.

- The reflashed `192.168.0.199` returned as `aryaos-d600` with overlay `2.0.10`,
  the ADSBee, DroneScout, and SiRF GPS all attached. Its fresh first boot wrote
  `ARYAOS_CAPABILITIES="adsb rid"` but left readsb on the RTL-SDR default and
  enabled `dump978-fa`; readsb, ADSBCOT, and UAT consequently failed. The
  scanner itself correctly protocol-verified both serial sensors.
- First boot accumulated capability names across its bounded scans but invoked
  the plain `aryaos-role caps` setter, bypassing the transport wiring used by
  `discover --apply`. Overlay `2.0.14` adds `apply-detected`: first boot keeps
  its multi-pass union while configuring the ADSBee Mode-S Beast by-id path and
  colon-safe `/dev/dronescout` feed before enabling services.
- Factory-reset HIL exposed two more lifecycle gaps. The helper now disables
  sensor units and removes both capability-autodetection markers before reboot,
  so scanners see unclaimed ports. It also clears the crash-guard counter and
  sticky safe-mode flag and restores USB power; an intentional reset reboot no
  longer becomes the third "short boot" and falsely powers off every sensor.
- The OTA overlay builder had omitted `aryaos-safe-mode`, its units, and sensor
  drop-ins even though full images installed them. They are now packaged, so
  deployed boxes receive the factory-reset/safe-mode fix rather than only new
  images. Static image verification and regression coverage assert all three
  lifecycle contracts.
- A controlled reboot changed the boot ID while preserving hostname/machine ID,
  the installed root PARTUUID matched the boot command line, all ADS-B/RID/GPS
  services recovered, and the full default HIL suite passed. readsb decoded
  live ADS-B traffic and DroneCOT processed the lab Remote ID beacon.
- The final network-preserving reset returned as `aryaos-265b` with a new
  machine ID and web certificate. The lab authorized-key and sudoers digests
  were unchanged, `.199` remained reachable, safe mode stayed off, GPS was
  reassigned to its stable PL2303 by-id path, `adsb rid` was rediscovered,
  ADSBee and DroneScout transports were correct, and no units failed. The final
  complete HIL suite passed all modules; its short ADS-B sample happened to be
  quiet, while Remote ID heartbeat/payload checks remained live.
- The reset's best-effort gateway reinstall failed after unpacking ADSBCOT,
  DroneCOT, and LINCOT, leaving them pending in dpkg even though their running
  services looked healthy. The packages configured cleanly when resumed.
  Overlay `2.0.15` therefore runs a bounded noninteractive `dpkg --configure -a`
  recovery on the apt failure path so reset never knowingly reboots with an
  inconsistent package database.

## 2026-08-10 TAK outage resilience (`.60`)

- A prolonged outage of the dedicated ACARSCOT TAK endpoint exposed two coupled
  failures on `aryaos-ff84` (`.60`): the WebSocket receive worker exited after
  the server closed it, and repeated PKCS#12 loads leaked three extracted PEMs
  per attempt. After 12,723 files, both 100 MiB `/tmp` and `/var/tmp` mounts
  were full; ACARSCOT then entered a 12,272-restart systemd loop with
  `No usable temporary directory`.
- PyTAK `7.4.3` supervises transient TCP/TLS/WebSocket failures within one
  process, rebuilding bounded worker queues per attempt and retrying with a
  jittered 5-to-120-second exponential delay. A five-minute stable session
  resets the delay. Configuration errors remain fatal. Temporary PKCS#12 PEMs
  are removed immediately after `SSLContext.load_cert_chain()`, including
  partial-conversion failure paths.
- ACARSCOT `0.1.1` requires PyTAK `>= 7.4.3` and packages
  `StateDirectory=acarscot` plus `HOME=/var/lib/acarscot`, keeping enrollment
  state across reboots without a local drop-in.
- On `.60`, only the 12,723 confirmed root-level temporary PEMs owned by
  `acarscot` were removed; the three persistent enrollment-cache files were
  preserved. A bounded fixture test proved initial outage, recovery,
  server-initiated close, and second recovery on one PID with zero systemd
  restarts and zero leaked PEMs. The operator's real TAK endpoint remains
  unreachable as of this handoff, but ACARSCOT stays active and retries safely.
- The image now installs ACARS packages, requires PyTAK `>= 7.4.3` and ACARSCOT
  `>= 0.1.1`, and verifies persistent state. HIL checks assert active ACARS
  units, zero systemd restarts, persistent HOME/state, no leaked PEMs, and
  headroom on `/tmp`, `/var/tmp`, and `/var/log`.
- PyTAK `v7.4.3` and ACARSCOT `v0.1.1` are published GitHub releases. Packages
  workflow run `31415323491` rebuilt and deployed the signed repository from
  `snstac/packages` main commit `2423630`; the public arm64 index was then
  signature-verified with the vendored key and confirmed to serve
  `pytak 7.4.3-1` and `acarscot 0.1.1-1` (which depends on
  `pytak >= 7.4.3`).
- Source validation passed: PyTAK 233 tests on the development interpreter and
  its Python 3.7--3.12 CI matrix; ACARSCOT 46 tests; AryaOS 69 tests with three
  intentional skips; Ansible syntax, strict MkDocs, shellcheck, Bash syntax,
  and Debian package inspection. The complete `.60` HIL suite passed all 12
  modules on the hardened packages.
- AryaOS Actions run `31415495113` built commit `08f3654` in 22m56s. The
  finished-image verifier reported **264 ok, 0 failed**, explicitly confirming
  `pytak 7.4.3-1`, `acarscot 0.1.1-1`, persistent ACARSCOT state/HOME, and the
  intended default-disabled role policy. The image, SPDX/CycloneDX SBOMs,
  checksums, and overlay deb are published in prerelease
  `v2026.08.10.180238-08f3654475b8-dev`.
- A final live outage check on `.60` found `acarsdec` and `acarscot` both
  active/enabled, ACARSCOT still on PID `937080` with zero systemd restarts,
  zero leaked PEMs, zero failed units, no credential-pattern matches in its
  outage logs, and `/tmp`/`/var/tmp` at 2%/1% used.

## 2026-08-10 ADSBee / DroneScout discovery HIL (`.199`)

- The newly flashed `aryaos-f069` at `192.168.0.199` has an ADSBee 1090 on
  `/dev/serial/by-id/usb-Raspberry_Pi_Pico_E4654C6197481B39-if00` and a SiRF
  GSD4e GPS connected through a Prolific PL2303 UART adapter. The GPS is on
  `/dev/serial/by-id/usb-Prolific_Technology_Inc._USB-Serial_Controller_D-if00-port0`.
  Generic USB identities are not treated as product identities.
- ADSBee detection is protocol-verified with the read-only
  `AT+BIAS_TEE_ENABLE?` query. Five consecutive probes succeeded. Discovery
  configured readsb as `--device-type modesbeast` on the stable by-id path,
  recorded `ARYAOS_ADSB_1090_SOURCE=adsbee`, and deliberately kept `dump978-fa`
  disabled. Repeated `discover --apply` is idempotent while readsb owns the tty.
- Live receiver queries reported 1090 and sub-G receivers enabled, console
  output `BEAST`, trigger level `1569mV (-45 dBm)`, offset `600mV (-104 dBm)`,
  and more than 5,100 seconds of uninterrupted receiver uptime. After an
  initially quiet several-minute sample, readsb decoded 451 valid messages,
  six tracks, and 50 position updates in 9.4 minutes; three aircraft were
  current and ADSBCOT consumed them. `readsb`, `adsbcot`, and `gdlcot` are
  enabled/active. readsb and gdlcot have zero restarts; ADSBCOT restarted once
  after the controlled test stopped readsb and removed its runtime JSON tree,
  then recovered normally.
- The PL2303 path was initially tested as a claimed DS110 and emitted no
  checksum-valid MAVLink. A binary-safe capture then found checksum-valid SiRF
  frames at 4,800 baud. gpsd identifies it as `SiRF`, subtype
  `GSD4e_4.1.2-B2_RPATCH.02-F-GPS-4R`. It acquired a live 3D fix with 12
  satellites in view and 7 used. `/etc/default/gpsd` now pins the stable by-id
  path. AryaOS serial discovery now validates SiRF binary framing in addition
  to NMEA, and capability discovery excludes an assigned GPS from PL2303/DS110
  probing.
- The box exposed a second GPS-path defect: `gpscot.service` was installed but
  disabled even though GPSCOT is documented as role-independent core plumbing.
  Overlay 2.0.9 enables/starts GPSCOT during installation, and HIL now asserts
  that it stays active. The package also reruns serial assignment after
  refreshing gpsd defaults, avoiding a blank `DEVICES` setting after update.
- `dronecot-dronescout.service` now uses an `ExecCondition` that validates its
  configured serial character device. A missing/unconfigured receiver produces
  a clean inactive/skipped unit (start result success, no failed unit) rather
  than a `Restart=always` loop.
- Overlay 2.0.9 was initially installed on the box. The post-update closing HIL suite
  passed 88 checks, including live GPS/portal data, GPSCOT, and ADSBee traffic;
  there are no failed units. The only deferred failure is the known corrupt
  binary `/boot/firmware/cmdline.txt`. Do not reboot this node until the
  separate command-line repair is completed.
- After the DroneScout was attached, discovery verified `HEARTBEAT` and
  `OPEN_DRONE_ID_MESSAGE_PACK` on its unique ESP32 CDC port. The first applied
  configuration exposed a pymavlink edge case: the MAC-address colons in the
  stable by-id path made pymavlink treat the tty as UDP while systemd still
  reported DroneCOT active. AryaOS now selects `/dev/dronescout` only when it
  resolves to the protocol-verified port, and refuses an unsafe colon-bearing
  fallback. Live HIL then received the MAVLink heartbeat, processed the lab
  beacon, and emitted both UAS and operator CoT with `sensor_id=dronescout`.
  A 68.8-second runtime sample counted 411 received RID records and 819 emitted
  events with zero write errors; a separate 10-second wire capture saw 63 UAS
  CoTs reach COTBridge ingress. Overlay 2.0.10 is installed, and the closing HIL
  suite passed 94 checks. Its only failure remains the deliberately deferred
  corrupt boot cmdline; do not reboot this node.
- Package HIL also found a zero-corrupted `/var/lib/apt/listchanges` pickle at
  byte 983,261. The original is preserved on-host as
  `listchanges.corrupt-20260810` and in the gitignored HIL evidence directory;
  Debian's `apt-listchanges.service` rebuilt a valid database and completed
  successfully. This did not touch the boot cmdline.

## 2026-08-02 four-node HIL burn-in (SOAK COMPLETE; `.60` RECOVERED)

The eight-hour sampler ran from 09:03:45 through 17:03:45 UTC against `.13`,
`.44`, `.60`, and `.199`: 480 cycles per host and 1,920 records. Raw evidence,
enhanced summaries, intervention annotations, and final HIL/audit logs live in
gitignored `.aryaos-burnin/20260802T090345Z/`. Every `.13`/`.44`/`.199` probe
failure is explained by a controlled reboot/package intervention or the sudo
capacity defect found and fixed below. `.60` supplied 164 successful samples,
then remained offline for cycles 165--480 after its operator-triggered
filesystem-repair reboot. It returned later as a freshly initialized image;
the recovery and post-flash validation are recorded below.

### Lab inventory and roles

| Address | Host | Active role / attached hardware | Wired link |
|---|---|---|---|
| `192.168.0.13` | `aryaos-36aa` | DJI DroneID; AntSDR at `172.31.100.2`; ESP32-S3 + CH340 | 10 Mb/full |
| `192.168.0.44` | `aryaos-91bd` | Wi-Fi Remote ID; AR9271 monitor adapter + CH340 + CP2102N | 10 Mb/full |
| `192.168.0.60` | `aryaos-ff84` (reflashed; formerly `aryaos-fad2`) | ACARS; LimeSDR Mini + u-blox 7 | 1 Gb/full |
| `192.168.0.199` | `aryaos-0f26` | Gutcheck; Pico + PL2303 | 1 Gb/full |

### Findings already fixed and deployed

- Gutcheck `v0.2.0` parses AryaOS beacon v1-v5 capabilities, decoder state,
  clock/TDoA fields, and PAN state, and renders all four on its node table. It
  sustained 5,000 rich entities and 10,000 authenticated API requests without
  drops or restarts. AryaOS now permits its token-gated port 8181 on the trusted
  LAN only (never the onboarding hotspot).
- PyTAK `v7.4.2` uses per-app runtime status directories and serializes status
  writes. Dronecot `v2.3.7` reports DJI runtime state, preserves intentional
  service enablement across upgrades, and reloads changed systemd units. Lincot
  `v1.3.7` bounds the
  no-GPS probe and kills its process group. COTBridge `v0.2.1` fixes write-only
  UDP CPU spin, usrmerge packaging, and binary AES key handling.
- All Cockpit gateway consumers use `cockpit-shared v1.3.1`, which closes the
  four-second D-Bus client leak. Sapient/APRS packaging and dependency audits
  are also clean.
- Capability beacon v5, bounded local SDR/serial discovery, ACARS start limits,
  portal GPS probing, Wi-Fi/Bluetooth DHCP coexistence, and the burn-in sampler
  are in the AryaOS branch `fix/dronecot-ws-recovery`.
- Raspberry Pi OS Trixie's new `rpi-swap` defaulted to `zram+file`, silently
  creating a 2 GiB `/var/swap` backing file and periodic flash writeback. Overlay
  `2.0.4` pins `Mechanism=zram`. Controlled reboots on `.13`, `.44`, and `.199`
  proved `/var/swap` absent and `/sys/block/zram0/backing_dev` equal to `none`;
  `.60` still needs that validation after its filesystem recovery.
- Overlay `2.0.5` initializes the legacy GPSD `OPTIONS` variable and
  reconciles BlueZ's expected configuration-directory mode with Debian's
  packaged `/etc/bluetooth`. Live GPSD/BlueZ/PAN restarts on all three reachable
  nodes produce no corresponding warnings and recover fully. It also overrides
  Debian lighttpd's request for its optional `tls` kernel module: the Raspberry
  Pi kernel omits kTLS, while HTTPS correctly continues through user-space
  OpenSSL. A live `systemd-modules-load` restart completes cleanly on all three.
- Overlay `2.0.6` bounds sudo's compressed I/O audit history with
  `Defaults maxseq=128`. The eight-hour run reproduced a fleet-wide failure in
  which 409/401/403 unbounded sudo sessions consumed the entire 50 MiB
  `/var/log` tmpfs on `.13`/`.44`/`.199`; sudo then rejected every privileged
  command with `ENOSPC`, although the nodes and role services themselves stayed
  healthy. After recording the failure, the oldest 288/280/282 ephemeral
  sessions were removed, leaving the newest 128 and restoring 63--72% free
  space. The new sequence limit parsed successfully and passed the live
  security/media HIL checks on every reachable node. The
  image verifier and HIL suite now assert both the bound and `/var/log`
  headroom.
  Three concurrent privileged samplers then drove the counters through a
  natural rollover to sequence 4/4/7 with no failed probe, while `/var/log`
  retained 36--39% free even before the closing reboot cleared the old tmpfs
  sessions.
- Burn-in sampling and the HIL suite now inspect the root superblock, current-
  boot filesystem/media errors, boot command-line shape, and configured versus
  installed root PARTUUID. This was added after the deeper audit below caught a
  failure which the ordinary service checks and direct-I/O benchmark did not.
- Burn-in summaries now distinguish overlapping journal observations from
  distinct events by journal cursor, retain both historical and current failed-
  unit state, and locate the first/last failed probe. A 20-minute companion run
  after deployment collected 20/20 good samples per reachable node, zero
  filesystem/PARTUUID alerts, zero failed-unit samples, and zero service drops.
  It reduced 21 overlapping warning observations to 12 distinct events per node
  (four scheduled Comitup scans, three Broadcom messages each), proving the
  deduplication works. Memory moved only +0.24/+0.13/-0.07 percentage points on
  `.13`/`.44`/`.199`.
- The HIL suite now has role-aware Wi-Fi RID and Gutcheck modules. On `.44`, all
  eight Wi-Fi checks pass (AR9271 driver, monitor mode, live packet flow, healthy
  status, no write errors/restarts, Dronecot `2.3.7-1`). On `.199`, all nine
  Gutcheck checks pass (package `0.2.0-1`, health/dashboard, enforced API auth,
  live capability-rich entity fields, zero drops/warnings/restarts, and the four
  display columns). Other roles skip these modules rather than producing noise.

### Active-test evidence

- The main run recorded maxima of 52.35 °C, load 3.95, and 14.9% memory used;
  there was no throttling or service restart growth. The closing overlay `2.0.6`
  proof collected 77/77 successful samples on each reachable node with clean
  filesystems/PARTUUIDs, no failed units or service drops, and memory changes of
  only +0.56/+0.55/+0.32 points on `.13`/`.44`/`.199`.
  Three historical failed-unit samples came from the deliberately removed
  `rpi-zram-writeback.timer` during the swap-policy migration; every final and
  post-fix sample had zero failed units.
- Concurrent 15-minute CPU/VM stress on all four: no failures, no swap use, no
  throttling; maximum 52.35 °C.
- Direct-ext4 1 GiB sequential write/read MiB/s: `.13` 27.7/94.0, `.44`
  33.0/94.9, `.60` 48.0/89.0, `.199` 24.6/94.6. No immediate I/O errors occurred
  during the benchmark, but the later whole-boot audit found pre-existing `.60`
  metadata corruption; throughput alone is not a media-integrity test.
- `.60`↔`.199` reached about 936 Mb/s. `.13` and `.44` advertise gigabit but
  their link partners advertise only 10baseT; unidirectional transfers reach
  the full 9.4 Mb/s with zero NIC CRC/symbol errors. Bidirectional loss/retries
  are consistent with switch buffering between 1 Gb and 10 Mb ports, not AryaOS.
- Multicast from `.199` does not reach the other three nodes although unicast
  does. Treat the 10 Mb links and `.199` multicast isolation as switch/cabling/
  IGMP/VLAN work, not image defects.
- `.44` received 2,092,896 ambient monitor-mode frames (about 110 frames/s)
  without capture drops/errors or service restarts. `.60` produced 113 ACARS
  frames and tracked five aircraft before its repair reboot, with zero gateway
  write errors. Gutcheck processed 1,407 live events with zero drops, warnings,
  or restarts. No live DJI target was present for `.13`, but the AntSDR feed and
  Dronecot service remained established with zero write errors/restarts.
- The clean pre-intervention install-media baseline was 2.19--3.00 MiB/hour;
  an early post-overlay interval including once-per-minute audit probes was
  5.55--7.03 MiB/hour. The later 4.66-hour interval averaged 73.7--75.2 MiB/hour
  because it deliberately included package installs, repeated HIL/apt checks,
  Docker image/container recovery work, and hundreds of sudo rollover sessions;
  it is not an idle-write baseline.
- After the closing controlled reboot, `.13`, `.44`, and `.199` returned with
  new boot IDs. All default HIL suites passed, as did `.13`'s UAS profile with
  all eight AntSDR checks, `.44`'s eight Wi-Fi RID checks, and `.199`'s nine
  Gutcheck API/capability/UI checks. Exact fresh-boot scans found zero kTLS
  module, GPSD `OPTIONS`, BlueZ configuration-directory, filesystem/media, sudo
  `ENOSPC`, or USB-reset regressions. Packages and dependencies audited clean;
  root PARTUUIDs matched; swap was RAM-only with no backing device or
  `/var/swap`; and no systemd unit failed. A forced 300-session sudo test on
  each node retained exactly 128 sessions (16.4 MiB) and left `/var/log` only
  33% used.

### Source and image validation

- Final local gates on branch `fix/dronecot-ws-recovery` passed: AryaOS Python
  tests 69 passed/3 skipped, Gutcheck 110 passed, Ansible syntax, CI-equivalent
  shellcheck, strict MkDocs rendering, YAML parsing, and `git diff --check`.
- The first workflow dispatch, Actions run `30759152511`, exposed a CI-only
  filename bug: the raw ref `fix/dronecot-ws-recovery` became part of pi-gen's
  image name, so `/` was interpreted as a directory separator during export.
  Commit `20bb47a` sanitizes only the filesystem-facing image name to
  `aryaos-fix-dronecot-ws-recovery-dev` while preserving the original ref in
  the image provenance stamp. A second run exported and uploaded the image,
  proving that fix.
- The second run (`30759601742`) was then correctly blocked by the image
  verifier because the signed package repository still served Dronecot
  `2.3.4-1` while AryaOS requires `>=2.3.7`. Packages workflow run
  `30760437018` refreshed the repository from the already-published Dronecot
  `v2.3.7` release; the public arm64 apt index now serves `2.3.7-1`.
- Final Actions run `30760485704` at commit `20bb47a` passed in 21m37s. The
  image verifier reported **258 ok, 0 failed**, including Dronecot `2.3.7-1`;
  image and SBOM artifacts, image hashes, overlay deb, and the prerelease were
  all published as
  `v2026.08.02.182711-20bb47af0ffe-dev`.
- The definitive Actions run `30761773782` then built the exact documented head
  `20a77fb` in 26m32s. Its verifier reported **259 ok, 0 failed**, including the
  new ACARS role-management assertion and Dronecot `2.3.7-1`. The image, SPDX
  and CycloneDX SBOMs, hashes, overlay `2.0.7` deb, and prerelease were published
  as `v2026.08.02.190609-20a77fb8dbb2-dev`.

### `.60` install-media incident and reflash recovery

- The deeper kernel/superblock audit found ext4 directory-checksum failures in
  `/usr/src/linux-headers-6.18.39+rpt-common-rpi/include/net` and `/srv`. The root
  superblock was `clean with errors`; the boot FAT was dirty. No contemporaneous
  MMC I/O error was logged, so the evidence establishes damaged install media,
  not a specific hardware root cause.
- `/boot/firmware/cmdline.txt` itself contained corrupt random-looking data and
  named no usable root. Before reboot it was reconstructed as a single line with
  the current root PARTUUID (`7c6f9611-02`), `fsck.repair=yes`, and a one-boot
  `fsck.mode=force`. Redacted configuration and support archives were copied
  off-host into the burn-in evidence directory before intervention.
- `.60` had not returned by the final 17:11 UTC ping/SSH/mDNS/ARP check after
  the 11:47 UTC repair reboot. It later returned with new host keys, hostname
  `aryaos-ff84`, and a new machine ID, establishing that it was reflashed rather
  than resuming the damaged `aryaos-fad2` installation.
- The fresh image was healthy at the filesystem layer (clean root superblock,
  matching root PARTUUID, and no current-boot filesystem/media errors), but was
  still on overlay `2.0.0`. It also had Trixie's file-backed swap loop and had
  misclassified the LimeSDR as AIS, leaving `ais-catcher` failed. Overlay
  `2.0.7` and the signed ACARS stack were installed, and the capability was set
  explicitly to `acars`.
- That transition exposed and fixed a source bug: `aryaos-role` knew that the
  `acars` capability maps to `acarsdec acarscot`, but omitted both units from
  `all_managed_units`, so it could persist the label without enabling the
  services. Commit `9c9782c` adds both units, a regression test, and an image
  verifier assertion.
- After a controlled reboot, `.60` had only RAM-backed zram (no backing device
  and no `/var/swap`), no failed units, and passed the complete default HIL
  suite. LimeSDR Mini v2 serial `1DBB4189078E3F` opened over USB 3.0; both
  `acarsdec` and `acarscot` were enabled/active. The decoder emitted a 384-byte
  JSON datagram to the gateway on loopback at 19:42:34 BST with zero capture
  drops, proving live RF-to-gateway data flow. One initial USB 2.0 open attempt
  failed during boot enumeration; the bounded service restart succeeded 20
  seconds later over USB 3.0 and remained error-free.
- ACARSCOT was subsequently enrolled directly to the operator-supplied TAK
  server (credentials deliberately omitted). PyTAK resolved the enrollment URL
  to WSS on port 8443; the socket remained established with both WebSocket
  workers running and zero ACARSCOT warnings or restarts. The three enrollment
  cache files are mode `0600` under `/var/lib/acarscot`, backed by a local
  `StateDirectory=acarscot` service drop-in so a reboot does not consume the
  enrollment token again. A forced service restart preserved the cache
  byte-for-byte and reconnected successfully. A controlled reboot then changed
  the boot ID while preserving the same cache digest; ACARSCOT automatically
  re-established WSS with no warnings or restarts. The complete default HIL
  suite passed again on that boot (including 23 security and three storage
  checks). A 45-second follow-up RF capture was quiet, which is normal for
  sparse ACARS traffic; the earlier live 384-byte decoder datagram remains the
  data-path proof.

## 2026-07-19 to 21 sweep - HIL hardening + landing-page features (SHIPPED)

Two arcs, both merged and in a green image: **`v2026.07.21.211313-4e5923568c11-dev`**
(`verify-image`: 135 ok, 0 failed). User is flashing it now for HIL testing -
**resume by testing this release on the box.**

### Arc 1 - HIL security hardening (radios / EMCON / isolation)
Hardware-in-the-loop pentest of the appliance. Landed (aryaos, all asserted in
`verify-image.sh`):
- **Wi-Fi/AP isolation**: `public.xml` dropped `<forward/>` so the onboarding AP/PAN
  can't gateway to wired ethernet; new **`aryaos-hotspot` firewalld zone** withholds
  ssh/node-red/mesh from onboarding clients; NM owns the zone via `connection.zone`
  (`comitup-callback.sh` uses `nmcli connection modify ... + device reapply`, NOT
  `firewall-cmd --change-interface`, which NM reverts). `pan0` statically bound.
- **EMCON / radio silence** (`aryaos-radio`): `ap {on|off}`, `silence {on|off}` does
  `nmcli radio wifi off` + `rfkill block wifi bluetooth`; `--boot` re-applies from
  `/etc/aryaos/emcon` flag; comitup/bt-pan/bt-ready gated off via
  `ConditionPathExists=!/etc/aryaos/emcon` drop-ins. Ethernet + SDR RX unaffected.
- **Node-RED unauth-root closed**: drop-in runs it `User=node-red` (was root); default
  publicly-known password (`aryaos415`) rotated on first boot; cockpit-aryaos card to reset.
- **XXE/billion-laughs guards** + systemd sandboxing on `aryaos-neighbord` (score reduced from 9 to 3),
  socket `0600`; TAK data-package import moved off CGI to a root CLI over an AF_UNIX
  socket with SSRF host-blocking. **Zeroize stays best-effort sanitize (usable box), NOT
  scorched-earth.** SSH password auth intentionally STAYS ON (don't lock users out).
- **chrony NTP server** (`local stratum 10`, gpsd SHM refclock, `allow`) served on the LAN zone.

### Arc 2 - landing-page features + style fix (cockpit-aryaos v1.5.0 + plugin patches)
- **Unstyled plugins fixed**: React/esbuild plugins bundle SCSS to `dist/index.css` but
  `index.html` never linked it > completely unstyled in Cockpit. Added
  `<link rel="stylesheet" href="index.css">` + shared `branding.css` (matching
  cockpit-gps/aiscatcher) to **cockpit-cotbridge/adsbcot/dronecot/aiscot/sdrconnect**.
- **Landing-page location chip** (cockpit-aryaos): offline **North America** base map +
  live position. Geometry ships in `aryaos-basemap.js` (`window.ARYAOS_BASEMAP`,
  public-domain Natural Earth 110m, ~29KB) rendered client-side as SVG with a Web-Mercator
  projection so the marker aligns; **no tiles fetched** (works in EMCON). Position from
  `gpspipe --json` best 2D/3D TPV, falls back to config `STATIC_LAT/LON`. NA-only by design
  (primary sales region); off-map positions are labelled, not mis-plotted.
- Also this batch: **OS image backup card** (`aryaos-image-download` pulls the box's own
  `.img.xz`), **NTP time-server** exposure, **bundled cloudtak removed**.

### Build/release gotchas learned this sweep (IMPORTANT)
- **image-commit stamp**: pi-gen runs inside a **Docker container** (`usimd/pi-gen-action`).
  `GITHUB_ENV` vars do NOT cross into it - `ARYAOS_BUILD_SHA` must be passed via
  `docker-opts: -e` (fixed #164). A prior "fix" using GITHUB_ENV silently left the stamp
  `unknown` and failed the gate. Same rule for any new build-time env a stage needs.
- **Plugin debs publish on TAGS ONLY** (`build.yml` steps are `if: startsWith(github.ref,
  'refs/tags/')`). Merging a plugin PR to `main` only runs validation - it does NOT
  produce a new deb. To ship a plugin change: **push a `vX.Y.Z` git tag** (git push, not
  `gh release create` - the workflow triggers on `push: tags`, not the `release` event) >
  build.yml packages the deb + creates the release > then publish the apt repo.
- **apt repo path** is `https://snstac.github.io/packages/apt` (note the `/apt` subpath),
  suite `stable`, component `main`, index at `.../apt/dists/stable/main/binary-arm64/Packages`.
  Ingest new debs by dispatching **`snstac/packages` `publish.yml`** (`gh workflow run
  publish.yml --repo snstac/packages`; also runs daily 06:17 UTC) - it pulls each product's
  *latest* GitHub Release assets. THEN rebuild the aryaos image so apt pulls the new versions.
- Correct order to land a plugin change in an image: merge PR > tag release > publish.yml >
  image build. Skipping any step ships the old deb (and `verify-image` now catches the
  cockpit-aryaos case: `card-location` + `aryaos-basemap.js`).

This sweep's plugin releases: cockpit-aryaos **v1.5.0**, cockpit-cotbridge **v1.2.1**,
cockpit-aiscot **v1.2.2**, cockpit-dronecot **v1.1.2**, cockpit-adsbcot **v1.2.2**.
(cockpit-sdrconnect CSS fix merged but unreleased - not in the image manifest / apt index.)

## 2026-07-15/17 sweep - "never SSH" + fleet dedup (SHIPPED)

Full review + implementation sweep. **All 11 PRs merged and released** (2026-07-17,
in dependency order: packages > aryaos > cockpit-aryaos > plugins). What landed:

- **aryaos overlay helpers** (all driven by cockpit-aryaos cards, no SSH):
  `aryaos-support-bundle` (redacted diagnostics tarball, `/var/lib/aryaos/support/`),
  `aryaos-set-nodered-password` (rotates the publicly-known default and sets
  `settings.js` to `root:node-red 0640`), `aryaos-sdr` (RTL-SDR enumerate + EEPROM re-serial; this
  added the `rtl-sdr` package - only `librtlsdr0` shipped before), `aryaos-role`
  (runtime device roles **multi/air/maritime/cuas/relay**; CoT core cotbridge/lincot/
  gpscot/gpsd never touched; ADS-B decoder follows `ARYAOS_ADSB_DECODER`). Installed
  via overlay deb + chroot stage + Ansible; asserted in `verify-image.sh`; all four
  now in the CI shellcheck list (they have **no `.sh` suffix** - the globs missed them,
  don't re-break that).
- **SBOMs** - `scripts/generate-sbom.sh` + pinned syft, every image build emits
  SPDX + CycloneDX attached to the release. The step runs **before the tag push** on
  purpose (an SBOM failure must not strand a tag). CAUTION: it runs syft under `sudo`,
  so it chowns `deploy/` back to the runner afterward - a prior version stranded a tag
  by leaving `deploy/` root-owned (fixed in #131).
- **cockpit-aryaos v1.3.0** - six new cards: support bundle, Node-RED password,
  Radios (RTL-SDR), Device role, comitup hotspot password, Tailscale join. The four
  helper-backed cards need aryaos-overlay ≥ the 2026-07 helpers; on older images they
  show a clear error toast.
- **cockpit-cotbridge v1.2.0** - React/TS rewrite + **structured lane editor**.
  `src/cotUrl.ts` is a differentially-tested port of `cotbridge/src/cotbridge/config.py`
  - **keep the two in sync** if lane/URL validation changes.
- **gdlcot** (new repo, v1.0.0) - CoT > GDL90 UDP broadcast so ForeFlight/EFBs display
  the TAK air picture. In the sensor manifest + air/multi roles; egress-only (no
  inbound firewall service). 48 tests incl. the GDL90-spec CRC known-answer.
- **@snstac/cockpit-shared** (new repo, v1.1.0) - shared `serviceCard`/`tlsCard`/
  `envDefaultFile`/`types`. **Source-shipping model**: consumers depend on
  `github:snstac/cockpit-shared#vX.Y.Z` and esbuild bundles the `.ts/.tsx` directly
  (no npm registry, no build step); `cockpit` resolves from each consumer's `pkg/lib`.
  Keyless `npm ci` verified (pacote fetches public repos over anonymous https even
  though the lockfile `resolved` says `git+ssh`). **All five family-B plugins consume
  it** (aiscot v1.2.1, adsbcot v1.2.1, dronecot v1.1.1, lincot v1.1.1, cotbridge v1.2.0).
  Bumping the shared package = bump its tag, then bump the `#vX.Y.Z` ref in each consumer.
- **README** amd64 claim softened (arm64 today, amd64 planned) - tracking #129
  (installer-script path first: the apt repo + overlay deb already run on any Debian host).

Issue tracker triaged **42 > 11 open** (each closure commented with what superseded it).

**Next hardware session**: flash the milestone image below and exercise all six
cockpit-aryaos cards + verify the Cockpit expired-password first-login flow (the
prerequisite for a first-login wizard); good `09-security.sh` test candidates. Then:
amd64 installer (#129), unified COP map, track record/replay (#8/#9), and the cockpit
plugins still on vanilla-JS could adopt cockpit-shared patterns.

## Current known-good build

- Latest successful dev image: `v2026.07.17.165541-5fa79a7bfae5-dev` - **the milestone
  build**: first image with gdlcot, the four field-support helpers, device roles, and
  working SBOM attachment.
- Release: https://github.com/snstac/aryaos/releases/tag/v2026.07.17.165541-5fa79a7bfae5-dev
- Assets verified present: `image_*.img.xz`, `aryaos-overlay_2.1_all.deb`, `*.spdx.json`,
  `*.cdx.json`.
- Notes: **dev/lab image** (`aryaos-dev-lab` SSH key, passwordless `pi` sudo, no
  first-boot password expiry). Do not field it. For a release image, dispatch the
  Pi-gen workflow with the `release` input checked.
- Watch: the apt index refreshes on the packages repo's daily/push publish - the new
  plugin deb versions (cockpit-aryaos 1.3.0 etc.) reach deployed units via one-click
  updates once that runs.

Recent build blockers fixed:

- `sikw00fcot.service` was missing AryaOS site config inheritance. Root cause was
  a broken `sed` expression in `stage-cotbridge` that used `/` as the delimiter
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

1. **Everything installs from the signed apt repo** - https://snstac.github.io/packages,
   built by [snstac/packages](https://github.com/snstac/packages) from each product's
   *latest GitHub release* (repos listed in its `products.txt`). No vendored sensor
   binaries remain in this repo; the only vendored artifacts are trust anchors
   (`shared_files/aryaos/snstac-packages/`, FlightAware repo deb).
2. **Cockpit is the single admin surface** - nine standalone `cockpit-*` plugin
   repos/debs (adsbcot, aiscot, aiscatcher, dronecot, lincot, gps, cotbridge, gpscot,
   aryaos). `cockpit-aryaos` ("AryaOS Site") manages the site-wide layer:
   `/etc/aryaos/aryaos-config.txt` (site `COT_URL` etc.) and one-shot TAK TLS cert
   upload to `/etc/aryaos/tls` (key `0640 root:tak-certs`; group reconciled by
   `aryaos-firstboot.sh` every boot). Per-tool plugins edit `/etc/default/<svc>`.
3. **CI builds dev images by default** - every push to `main` produces a
   `v<ts>-<sha>-dev` **prerelease** with lab access baked (dev SSH key, pi NOPASSWD,
   no password expiry) for burn-and-test. Hardened release images require dispatching
   the Pi-gen workflow with the **`release`** input checked. `scripts/verify-image.sh`
   loop-mounts every built image and asserts ~58 facts (packages, units, files, and
   the lab/release security contract) before anything publishes.

## Architecture invariants (don't break these)

- **Site-config inheritance**: every gateway unit loads
  `EnvironmentFile=-/etc/aryaos/aryaos-config.txt` *before* its own
  `/etc/default/<svc>` - site sets defaults, per-service values override. The
  injection happens in each stage's chroot script (sed after `[Service]`); drop-in
  files would invert the precedence (drop-ins parse *after* the unit file).
- **CoT routing hub**: `adsbcot`, `aiscot`, `dronecot`, `lincot`, and other local
  PyTAK feeders should keep `COT_URL=udp+wo://127.0.0.1:28087`. COTBridge listens on
  `udp+ro://127.0.0.1:28087` and owns the external egress lanes: default Mesh SA
  `udp+wo://239.2.3.1:6969`, optional TAK Server, and other tools. Do not point each
  feeder independently at the same TAK Server except for deliberate legacy/debug bypass.
- **apt pinning**: `install-sensor-debs.sh` pins `release o=snstac` at **995** because
  stage-adsbcot pins trixie at 990 and Debian ships an SDR-less readsb that must never
  win. readsb is also `apt-mark hold` (status `hold ok installed` - verify-image
  accepts both hold and install).
- **Exactly one `EXPORT_IMAGE`** stage, last in every `STAGE_LIST` (PR validation
  enforces). `ARYAOS_CI_TRIM_WORK=1` (CI only) deletes stale stage rootfs trees -
  pi-gen full-copies per stage and 72 GB arm64 runners can't hold ~15 copies
  (the fleet has 72 GB *and* 145 GB VMs; never rely on runner luck).
  `increase-runner-disk-size` is broken on arm64 runners - keep it false.
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
  via `zone=trusted` in `aryaos-antsdr.nmconnection`. Operators use Cockpit >
  Networking > Firewall. If a new service opens a port, add a firewalld
  service XML + zone entry + verify-image assert, or it will be unreachable.
- **fail2ban** (sshd jail), **sshd drop-in** (`50-aryaos.conf`, password auth
  deliberately stays on), **sysctl** hardening, **unattended-upgrades**
  (Debian security only; snstac origin commented out by design).
- **Per-device web TLS**: `aryaos-firstboot.sh` regenerates the snakeoil key
  and `/etc/lighttpd/ssl/snakeoil-combined.pem` once per device (marker
  `/etc/aryaos/.web-tls-regenerated`). Firstboot also stopped `chown -R
  node-red /etc/aryaos` - Node-RED now owns only the config file, and
  `/etc/aryaos/tls` is `root:tak-certs 0750` with the key `0640`.
- **One-click updates**: `/usr/local/sbin/aryaos-update {check|apply|status}`
  + `aryaos-update.service` (oneshot, survives browser close), driven by the
  *Software updates* card in cockpit-aryaos ≥ 1.1 (falls back to
  `systemd-run` + plain apt on pre-2.1 images). JSON state in
  `/var/lib/aryaos/update-*.json`.
- **aryaos-overlay 2.1** is built by CI and attached to releases as a deb
  asset, so units can upgrade the overlay itself once `snstac/aryaos` is in
  the packages repo `products.txt` (see open items - sequencing matters).
- New verify-image asserts cover all of the above; runtime checks are in
  `scripts/aryaos-test/tests/09-security.sh`.

## GPSCOT (new, 2026-06-12)

`gpscot` package > `/usr/bin/gpscot`: feeds onboard GNSS to TAK
devices per https://ampledata.org/network_gps.html - CoT position events to `COT_URL`
(default `udp+broadcast://255.255.255.255:4349`, ATAK's *External or Network GPS*) and
raw-NMEA passthrough for WinTAK (`NMEA_TARGETS`). Reads gpsd's JSON socket; pytak for
transport (so `PYTAK_TLS_*` applies). Ships **disabled**; managed in Cockpit > GPSCOT
([cockpit-gpscot](https://github.com/snstac/cockpit-gpscot)). Verified live on the dev
Pi. Source and Debian/RPM release packaging live in https://github.com/snstac/gpscot.

## Fleet state (all on pytak >= 7.3.0, releasing versioned debs)

| Repo | Release | Notes |
|---|---|---|
| pytak | 7.3.11 | capability line: cert enrollment, `tak://`, `wss://`, `marti://`, `pytak dp`, `+wo`/`+ro`, MQTT |
| adsbcot 9.1.0, aprscot 8.0.0, inrcot 5.2.1, cotproxy 1.0.1 | Jun 2026 | pipelines modernized (lincot-style ci.yml) |
| aiscot 7.1.4, dronecot 2.1.3, djicot 1.2.0, lincot 1.2.3, cotbridge 0.1.13, sikw00fcot 1.0.0 | Jun 2026 | cotbridge ≥ 0.1.13 no longer ships its cockpit plugin in-deb; sikw00fcot is SiKW00F MAVLink fan-out to CoT |
| python3-pymavlink | 2.4.49-1 | packaged for AryaOS so sikw00fcot can install cleanly; pure-Python fallback path, depends on `python3` and `python3-lxml` |
| readsb | 3.16.15-2 | synced to wiedehopf dev; build debs in `debian:trixie` containers because Ubuntu builds depend on `librtlsdr2`, uninstallable on Debian |
| AIS-catcher fork | 0.68 | release workflow runs upstream `build-debian.sh` as root; upstream CI workflows disabled on the fork |
| windtak 1.0.0, takline 0.1.1 | Jun 2026 | |
| cockpit-* x9 | 1.0.0+ | Cockpit plugins use the dark AryaOS/GPSCOT visual style; watch for regressions to white-on-white UI |

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

- `gh release upload` fails on fresh tags - `gh release view || gh release create` first.
- Immutable GitHub releases reject assets uploaded after publication. Use
  `gh release create <tag> <asset> ...`, not a create-then-upload flow that publishes
  first.
- `dpkg-deb -c | grep | head` > SIGPIPE kills dpkg-deb under `set -e`.
- `dh_install` treats destinations as directories (`foo.conf` becomes a *dir*).
- stdeb deb names default to `python3-<name>` without `stdeb.cfg` `Package3:`.
- A single private/release-less repo in `products.txt` kills the whole publish
  ("release not found"); publishes racing a just-pushed tag fail the same way.
- This repo has `core.fileMode=false` - `git update-index --chmod=+x` for scripts.
- GitHub GraphQL intermittently 401s here; use REST (`gh api`) with retries.

## Dev lab

Known lab hosts recently used:

- The retired fixed-address development target may be unreachable on current
  lab networks; use `scripts/aryaos-dev-device` or an explicit current address.
- `192.168.0.199`: ADS-B box used for readsb/adsbcot/gpsd/dashboard checks.
- `192.168.0.13`: UAS-mode box with AntSDR and BlueMark DroneScout bridge DS100.

Use the lab SSH key in `shared_files/aryaos/ssh/` where possible. Integration suite:

```bash
ARYAOS_SSH=pi@<host> ./scripts/aryaos-test/run.sh
```

After flashing the latest dev image, first checks should include:

- `systemctl status cotbridge lincot adsbcot aiscot dronecot sikw00fcot`
- `/cgi-bin/aryaos-portal-status` and `/admin/aryaos`
- `gpsd` data on GPS-capable units
- `readsb` and `/run/adsb/aircraft.json` on ADS-B units
- AntSDR Ethernet reachability and dronecot feed behavior on UAS units
- Bluetooth pairing plus `aryaos-bt-pan.service`/`pan0` on Bluetooth-capable units

## Open items / next handoff tasks

0. **Hardening burn-in (2026-07-02)**: flash the first post-hardening dev
   image and run the integration suite (esp. `09-security.sh`). Watch for
   firewalld regressions: comitup hotspot onboarding, Bluetooth PAN DHCP,
   Mesh SA neighbor discovery, AntSDR > dronecot, Docker-published CloudTAK
   ports, Node-RED/AIS-catcher dashboards. Then, **after the first release
   with the `aryaos-overlay_*_all.deb` asset exists**, add `snstac/aryaos` to
   packages `products.txt` (adding it earlier breaks the whole publish -
   `gh release download` fails on a release with no deb assets).
1. **Flash and test the latest dev image**: burn
   `v2026.06.23.212757-abe8e41bf5e2-dev`, then run the integration suite against the
   current lab ADS-B and UAS boxes. Pay special attention to `sikw00fcot`, COTBridge
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
5. **takline + windtak are private** - the packages publish token can't read them;
   flip public (`gh repo edit snstac/<r> --visibility public
   --accept-visibility-change-consequences`), then add to `products.txt`.
6. **Archive** `spotcot` (pre-pytak-5, dormant since 2022) and `cockpit-sdrconnect`
   (unmodified cockpit-dronecot clone, no releases).
7. **Delete** stray fork `snstac/AIS-catcher-1` (accidental duplicate).
8. adsbcot PyPI job needs a **trusted publisher** configured on PyPI (release works
   regardless; the job just reads red).
9. Possible next plugins: cotbridge *lane editor* (structured `cotbridge.ini` UI -
   current plugin is a raw editor), windtak/aprscot pages; backport SIGPIPE
   fixes everywhere `dpkg-deb -c | head` survives.
10. Node-RED runtime check after the worldmap 5.x / tfr2cot 2.0 major bumps
   (palette installs now go through the npm 11 override).
