# Dev Pi integration tests

Reusable SSH-based checks for a lab Raspberry Pi running an AryaOS image. Use after flashing CI, syncing portal files, or cutting a release.

## Quick start

From the repository root:

```bash
./scripts/aryaos-test/run.sh
make test-dev-pi
```

Default target: **`pi@aryaos-dev-pi`** (`172.17.2.158` via `~/.ssh/config`). Override:

```bash
ARYAOS_SSH=pi@10.0.0.5 ./scripts/aryaos-test/run.sh
```

Optional pre-sync (legacy wrapper):

```bash
ARYAOS_DEV_PI_SYNC=1 ./scripts/test-dev-pi.sh
```

This runs `sync-to-dev-pi.sh` and `sync-portal-review.sh`, then the same test runner.

## SSH authentication

Same order as [dev-pi.md](dev-pi.md) and [scripts/sync-to-dev-pi.sh](../scripts/sync-to-dev-pi.sh):

1. Normal **`ssh`** (agent / `~/.ssh/config`)
2. Repo dev key **`shared_files/aryaos/ssh/aryaos-dev-lab`**
3. **`ARYAOS_DEV_PI_PASSWORD`** or gitignored **`scripts/.dev-pi-creds.local`** with **`sshpass`**

## Layout

```
scripts/aryaos-test/
  run.sh              # entry: SSH, stage files on Pi, run modules
  lib.sh              # ok / fail / warn / skip counters
  expectations.yml    # expected units, paths, gateway IDs
  validate_portal.py  # portal JSON schema (stdlib Python 3)
  tests/
    01-services.sh    # systemd active / TAK gateway units
    02-config.sh      # aryaos-config, charontak, adsbcot, readsb
    03-adsb.sh        # readsb SDR flags, aircraft.json
    04-portal.sh      # HTTPS/HTTP CGI + validate_portal.py
    05-packages.sh    # dhbridge, calfire tiles
    06-optional-uas.sh # docker, MQTT, Bluetooth (warn-only)
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
- Core units: `readsb`, `adsbcot`, `lighttpd`, `gpsd`
- TAK gateway units expected by portal CGI: `charontak`, `lincot`, `adsbcot`, `aiscot`, `dronecot`
- Config: `COT_URL=udp+wo://127.0.0.1:28087`, adsbcot `FEED_URL`, charontak ingress (when present)
- readsb `--help` includes RTL-SDR, SoapySDR, HackRF
- `/run/adsb/aircraft.json` exists and is valid JSON
- Portal CGI returns HTTP 200 JSON with required keys and gateway IDs

### Warn / skip (exit 0)

- Empty `aircraft.json` (no ADS-B traffic)
- Inactive optional TAK gateways
- Missing `dhbridge` on older flashes
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

- [dev-pi.md](dev-pi.md) — lab Pi setup, sync, portal deploy
- [portal.md](portal.md) — portal JSON schema and TAK gateway list
- [AGENTS.md](../AGENTS.md) — agent workflow after portal or image changes
