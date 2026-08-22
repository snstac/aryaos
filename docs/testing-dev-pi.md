# Dev Pi integration tests

Reusable SSH-based checks for a lab Raspberry Pi running an AryaOS image. Use after flashing CI, syncing portal files, or cutting a release.

## Quick start

From the repository root:

```bash
./scripts/aryaos-test/run.sh
make test-dev-device
```

The default path discovers exactly one device through AryaOS Mesh SA. Select a
device or provide an explicit fallback target:

```bash
ARYAOS_DEV_DEVICE=aryaos-e406 make test-dev-device
ARYAOS_SSH=pi@10.0.0.5 ./scripts/aryaos-test/run.sh
```

For a known hardware kit, require its capabilities explicitly. This prevents a
quiet receiver from being omitted during first-boot discovery and then skipped
by the capability-aware modules:

```bash
ARYAOS_SSH=pi@10.0.0.5 ARYAOS_EXPECT_CAPABILITIES="adsb rid" \
  ARYAOS_TEST_TIER=strict ./scripts/aryaos-test/run.sh
```

Optional pre-sync:

```bash
ARYAOS_DEV_DEVICE_SYNC=1 ./scripts/test-dev-device.sh
```

This runs `sync-to-dev-pi.sh` and `sync-portal-review.sh`, then the same test runner.

## Current lab fleet

Use the capability profile only when it adds hardware-specific checks. The
default profile already follows `ARYAOS_CAPABILITIES` for ADSBee and DroneScout
nodes; the `uas` profile additionally requires AntSDR Ethernet and is therefore
wrong for an ADSBee plus DS110 box.

```bash
# AryaSea: dAISy/AIS receiver
ARYAOS_SSH=pi@192.168.0.44 ARYAOS_TEST_PROFILE=ais \
  ARYAOS_EXPECT_CAPABILITIES="ais" \
  ARYAOS_TEST_TIER=strict ./scripts/aryaos-test/run.sh

# AryaAir: ADSBee, DroneScout, and GNSS
ARYAOS_SSH=pi@192.168.0.45 ARYAOS_EXPECT_CAPABILITIES="adsb rid" \
  ARYAOS_TEST_TIER=strict \
  ./scripts/aryaos-test/run.sh
ARYAOS_SSH=pi@192.168.0.199 ARYAOS_EXPECT_CAPABILITIES="adsb rid" \
  ARYAOS_TEST_TIER=strict \
  ./scripts/aryaos-test/run.sh

# DragonEgg: LimeSDR, ACARS, and GNSS
ARYAOS_SSH=pi@192.168.0.149 ARYAOS_EXPECT_CAPABILITIES="acars" \
  ARYAOS_TEST_TIER=strict \
  ./scripts/aryaos-test/run.sh
```

For an unattended fleet soak, first populate the dedicated known-hosts file,
then run the sampler. Raw JSONL is the source of truth; regenerate summaries
from it when analysis changes.

```bash
ssh-keyscan -H 192.168.0.44 192.168.0.45 192.168.0.149 192.168.0.199 \
  > /tmp/aryaos-burnin-known-hosts
./scripts/aryaos-burnin.py \
  --hosts 192.168.0.44 192.168.0.45 192.168.0.149 192.168.0.199 \
  --duration-hours 8 --interval 60 --enforce-acceptance
```

The generated `summary.json` reports service state counts, automatic restart
ranges, boot IDs, filesystem alerts, and per-gateway `gateway_activity`.
Gateway activity includes observed samples, total counter growth, counter
resets, the last counters, and the range of CoT write errors. Positive receive
and emit growth with a zero write-error range proves that the live hardware
path generated data during the sampled window. A counter reset is not by
itself an automatic service crash: correlate it with systemd `NRestarts`, the
journal event cursor, and the sudo audit record to distinguish a controlled
package or operator restart from an unexplained failure. Completed systemd
oneshots and the run-to-completion GPS time synchronization helper are not
reported as service drops.

The release acceptance gate also rejects probe failures, service drops or
restart growth, reboots, USB inventory changes, filesystem alerts, throttling,
gateway write errors, network error growth, temperatures at or above 80 C,
disk use at or above 85%, and memory growth above five percentage points.

When sampler analysis changes after a long run, keep the raw JSONL and
regenerate the summary from it:

```bash
python3 scripts/aryaos-burnin.py \
  --summarize-existing .aryaos-burnin/<run>/samples.jsonl \
  --summary-output .aryaos-burnin/<run>/summary.json \
  --enforce-acceptance
```

## Lifecycle HIL

The controller-side lifecycle runner creates both backup forms, verifies a
restore sentinel, encrypts full backups while they are off-device, optionally
tests enrollment through stdin, scans a generated support bundle for the exact
credential, restores the prior TAK state, and can factory-reset one designated
lab box with networking retained:

```bash
# Paste the one-time URL when prompted by `read -s`; it is not echoed.
read -r -s ENROLLMENT_URL
printf '%s\n' "${ENROLLMENT_URL}" | ./scripts/aryaos-lifecycle-hil.sh \
  --hosts 192.168.0.44 192.168.0.45 192.168.0.149 192.168.0.199 \
  --enroll-stdin --factory-reset 192.168.0.45
unset ENROLLMENT_URL
```

This is destructive lab testing. Do not select a factory-reset host without a
known network path and working lab-key access. The runner intentionally does
not expose or exercise `aryaos-zeroize`.

## SSH authentication

Same order as [dev-pi.md](dev-pi.md) and [scripts/sync-to-dev-pi.sh](https://github.com/snstac/aryaos/blob/main/scripts/sync-to-dev-pi.sh):

1. Normal **`ssh`** (agent / `~/.ssh/config`)
2. Repo dev key **`shared_files/aryaos/ssh/aryaos-dev-lab`**
3. **`ARYAOS_DEV_DEVICE_PASSWORD`** or gitignored **`scripts/.dev-pi-creds.local`** with **`sshpass`**

Release images intentionally omit the lab key and passwordless-sudo grant. If
password authentication is selected, the runner sends the password to
`sudo -S -v` over SSH stdin (never in argv) and verifies that the resulting
global timestamp supports the suite's existing `sudo -n` checks. An explicitly
exported `ARYAOS_DEV_DEVICE_PASSWORD` takes precedence over the fallback credentials
file.

## Layout

```
scripts/aryaos-test/
  run.sh              # entry: SSH, stage files on Pi, run modules
  lib.sh              # ok / fail / warn / skip counters
  expectations.yml    # expected units, paths, gateway IDs
  validate_portal.py  # portal JSON schema (stdlib Python 3)
  tests/
    01-services.sh    # systemd active / TAK gateway units
    02-config.sh      # aryaos-config, cotbridge, adsbcot, readsb
    03-adsb.sh        # readsb SDR flags, aircraft.json
    04-portal.sh      # HTTPS/HTTP CGI + validate_portal.py
    05-packages.sh    # overlay package, calfire tiles
    06-optional-uas.sh # docker, MQTT, Bluetooth and UAS role checks
    07-antsdr.sh       # UAS-profile AntSDR Ethernet/feed health
    08-tak-dp.sh       # authenticated TAK data-package import boundary
    09-security.sh     # firewall, SSH, updates, swap, sudo log headroom, TLS
    10-storage.sh      # root/FAT symptoms, SD identity, cmdline, boot artifacts
    11-wifi-rid.sh     # enabled Wi-Fi RID adapter/service/data-path health
    12-gutcheck.sh     # enabled capability API/dashboard/auth/runtime health
    13-ais.sh          # enabled AIS serial isolation, ports, privacy, live NMEA
    14-acars.sh        # enabled ACARS SDR, listener, channels, and live activity
    15-lifecycle.sh    # installed helpers, backup inventory/modes, redaction guard
```

Expectations live in **`expectations.yml`**; update that file when image defaults change.

## Tiers

| Tier | Behavior |
|------|----------|
| **default** | Hard fail on core services, config parity, portal JSON, readsb SDR build, unified ADS-B path |
| **strict** | Reserved for future stricter checks (`ARYAOS_TEST_TIER=strict`) |
| **minimal** | Reserved for smoke-only runs (`ARYAOS_TEST_TIER=minimal`) |

### Hard fail (exit 1)

- SSH unreachable
- Any capability named by `ARYAOS_EXPECT_CAPABILITIES` is not enabled
- Core units: `readsb`, `adsbcot`, `lighttpd`, `gpsd`
- TAK gateway units expected by portal CGI: `cotbridge`, `lincot`, `adsbcot`, `aiscot`, `dronecot`
- Config: `COT_URL=udp+wo://127.0.0.1:28087`, adsbcot `FEED_URL`, cotbridge ingress (when present)
- readsb `--help` includes RTL-SDR, SoapySDR, HackRF
- `/run/adsb/aircraft.json` exists and is valid JSON
- Portal CGI returns HTTP 200 JSON with required keys and gateway IDs
- Sudo I/O audit history is bounded to 128 sessions and `/var/log` is below 95%
- Install media has a valid manufacturer identity; the boot command line is
  printable and names the mounted root PARTUUID; model-specific kernel and
  initramfs files are present and plausibly sized
- When the AIS capability is enabled: AIS-catcher/AISCOT are stable, the
  receiver uses a present by-id path distinct from GPS, local ports are open,
  and AIS-catcher explicitly disables its internet community feed
- When ACARS is enabled: ACARSDEC/ACARSCOT are stable, the configured SDR is
  present and opened, the decoder path is loopback-only, and the expected UDP
  listener and channel count are valid

### Warn / skip (exit 0)

- Empty `aircraft.json` (no ADS-B traffic)
- Inactive optional TAK gateways
- CalFire tiles still present (until removal lands on main)
- GNSS fix quality, DroneScout/docker/MQTT, Bluetooth `hci0`

## Output

Each module prints lines like:

```
OK   readsb active
WARN aircraft.json empty (no ADS-B traffic)
FAIL adsbcot FEED_URL
---
passed=18 failed=1 warned=3 skipped=2
```

The runner exits **1** if any module reports failures; **0** if only warnings/skips.

## Related docs

- [dev-pi.md](dev-pi.md) - lab Pi setup, sync, portal deploy
- [portal.md](portal.md) - portal JSON schema and TAK gateway list
- [AGENTS.md](https://github.com/snstac/aryaos/blob/main/AGENTS.md) - agent workflow after portal or image changes
