# Dynamic AryaOS Dev-Device Discovery

## Summary

Replace the retired static `aryaos-dev-pi` host convention with LINCOT-based
discovery. Dev tooling will listen briefly for AryaOS multicast beacons, expand
results through a discovered node's LINCOT-fed neighbor endpoint, and either
resolve one unambiguous device or fail safely with a device list.

Gutcheck will not be required. Explicit targets remain supported for CI,
recovery, and networks that block multicast.

## Implementation changes

- Add `scripts/aryaos-dev-device`, a stdlib-only discovery CLI with:
  - `list [--json]`: show discovered hostname, UID, IP, capabilities, and age.
  - `resolve [selector]`: print only the selected IP for script consumption.
  - `ssh [selector] [-- <ssh arguments>]`: resolve and execute SSH using
    existing key/password conventions.
  - A default 15-second scan, configurable through
    `ARYAOS_DISCOVERY_TIMEOUT`.
  - Optional interface selection through `ARYAOS_DISCOVERY_INTERFACE`.
  - Selection through an exact hostname, FQDN, UID, or IP argument, or
    `ARYAOS_DEV_DEVICE`.
  - Distinct nonzero exits for no devices, ambiguous selection, and invalid
    input.

- Implement discovery by:
  - Joining `239.2.3.1:6969` on each active, multicast-capable IPv4 interface.
  - Parsing only AryaOS `__aryaos` CoT details and rejecting DTD/entity
    declarations, malformed XML, oversized datagrams, invalid addresses, and
    expired observations.
  - Querying each multicast-discovered seed at
    `/cgi-bin/aryaos-neighbors`, accepting its self-signed device certificate,
    validating the JSON schema, and merging entries no older than the
    advertised 240-second TTL.
  - Deduplicating by machine UID, preferring the freshest observation and the
    packet source address over an advertised address.
  - Waiting the complete 15-second window before selection. With no selector,
    exactly one merged device must exist; zero or multiple devices fail and
    print actionable diagnostics.
  - Keeping discovery state in memory only; no persistent workstation cache.

- Integrate the resolver into sync, portal-review, HIL, and Makefile workflows:
  - Precedence: positional/`ARYAOS_SSH` explicit target, legacy explicit host
    override, `ARYAOS_DEV_DEVICE` selector, then automatic unique discovery.
  - Introduce canonical `ARYAOS_DEV_DEVICE_USER`,
    `ARYAOS_DEV_DEVICE_SSH_KEY`, and `ARYAOS_DEV_DEVICE_PASSWORD` variables.
  - Accept existing `ARYAOS_DEV_PI_*` variables and credentials file for one
    compatibility period with deprecation warnings.
  - Add canonical `make test-dev-device`; retain `make test-dev-pi` as a
    deprecated compatibility alias.
  - Replace the static SSH setup workflow with
    `./scripts/aryaos-dev-device ssh`; do not write or refresh
    `~/.ssh/config`.
  - Preserve current SSH host-key behavior: accept previously unseen keys,
    reject changed keys, and honor the existing explicit known-hosts file
    option.

- Replace the static Ansible host with an executable dynamic inventory that
  exposes the logical host `aryaos-dev-device` and obtains `ansible_host` from
  the resolver. Update affected playbooks and examples to combine the normal
  inventory with this dynamic inventory.

- Update agent guidance, Cursor rules, README, development/testing/portal
  documentation, and operational examples. Remove every tracked occurrence of
  the retired static lab address and replace active `aryaos-dev-pi` targeting
  examples with discovery or explicit-target examples. Rewrite the historical
  handoff reference without retaining the obsolete address.

## Public interfaces

```bash
./scripts/aryaos-dev-device list
./scripts/aryaos-dev-device resolve
./scripts/aryaos-dev-device resolve aryaos-e406
./scripts/aryaos-dev-device ssh aryaos-e406
ARYAOS_DEV_DEVICE=aryaos-e406 make test-dev-device
ARYAOS_SSH=pi@192.168.0.99 make test-dev-device
ansible-playbook -i inventory.yml -i scripts/aryaos-dev-inventory \
  site.yml --limit aryaos-dev-device
```

Discovery metadata is advisory and unauthenticated LAN data; SSH host-key
validation remains the trust boundary. Changed host keys must never be silently
replaced.

## Test plan

- Unit-test beacon parsing, hostile XML rejection, interface joining, neighbor
  JSON validation, TTL handling, deduplication, and source-address preference.
- Test selection behavior for zero, one, and multiple devices plus hostname,
  UID, FQDN, and IP selectors.
- Test clean machine-readable output, documented exit codes, explicit-target
  precedence, deprecated-variable compatibility, and dynamic Ansible inventory
  JSON.
- Mock multicast and HTTPS inputs so CI never depends on a live lab network.
- Run Python tests, ShellCheck, Ansible syntax validation, and existing AryaOS
  tests.
- Assert the retired static lab address has no tracked matches.
- Perform live acceptance on the lab LAN: list discovered devices, confirm an
  ambiguous unqualified target fails, resolve by UID/hostname, open SSH, and
  run `make test-dev-device`.

## Assumptions

- LINCOT multicast and `aryaos-neighbord` remain enabled by default on AryaOS.
- The workstation and at least one AryaOS seed share a multicast-capable
  network; explicit targeting is the fallback otherwise.
- A 15-second scan can miss an idle 61-second beacon cycle. This is an accepted
  latency/reliability tradeoff, mitigated but not eliminated by expanding through
  the seed's neighbor cache.
- Gutcheck is intentionally outside this implementation because it is optional
  and requires a preconfigured URL and bearer token.
