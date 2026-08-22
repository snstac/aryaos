# Local development device

Use a dedicated AryaOS device on the local network to test repository changes
before a full image build. Development tools discover devices from the LINCOT /
`aryaos-neighbord` Mesh SA beacons; there is no fixed lab address or required
SSH alias.

## Discover and connect

From the repository root:

```bash
./scripts/aryaos-dev-device list
./scripts/aryaos-dev-device list --json
./scripts/aryaos-dev-device resolve aryaos-e406
./scripts/aryaos-dev-device ssh aryaos-e406
```

Discovery listens on `239.2.3.1:6969` for 15 seconds, then expands direct seeds
through `/cgi-bin/aryaos-neighbors`. Set `ARYAOS_DISCOVERY_TIMEOUT` to change the
window or `ARYAOS_DISCOVERY_INTERFACE` to an interface name or local IPv4
address. Discovery metadata is unauthenticated LAN data; SSH host-key checking
remains the trust boundary. New keys are accepted, but changed keys are rejected.

With no selector, discovery succeeds only when exactly one device exists. Select
by exact hostname, FQDN, machine UID, or IP with an argument or
`ARYAOS_DEV_DEVICE`. Exit status 2 means invalid input, 3 means no match, 4 means
ambiguous selection, and 5 means a connection setup failure.

Use an explicit target when multicast is unavailable:

```bash
ARYAOS_SSH=pi@192.168.0.99 make test-dev-device
```

## Authentication

New lab images include the public key
`shared_files/aryaos/ssh/aryaos-dev-lab.pub`. Keep the matching gitignored
private key at `shared_files/aryaos/ssh/aryaos-dev-lab`, or set:

```bash
export ARYAOS_DEV_DEVICE_USER=pi
export ARYAOS_DEV_DEVICE_SSH_KEY=/path/to/private-key
export ARYAOS_DEV_DEVICE_PASSWORD='password-only-fallback'
```

`ARYAOS_SSH_KNOWN_HOSTS_FILE` selects an explicit known-hosts file and changes
checking from `accept-new` to strict. `ARYAOS_SSH_CONFIG_FILE` selects an SSH
config file. The old `ARYAOS_DEV_PI_*` variables and gitignored
`scripts/.dev-pi-creds.local` remain compatible for one transition period and
print deprecation warnings.

For an older image, install the lab public key using a known explicit target:

```bash
ssh-copy-id -i shared_files/aryaos/ssh/aryaos-dev-lab.pub pi@192.168.0.99
```

## Sync and test

```bash
./scripts/sync-to-dev-pi.sh
./scripts/sync-portal-review.sh
make test-dev-device
```

Each command uses explicit positional/`ARYAOS_SSH` targeting first, then the
legacy explicit host override, then `ARYAOS_DEV_DEVICE`, then automatic unique
discovery. The sync script mirrors the tree to `~/aryaos-sync/`. To sync and
test in one invocation:

```bash
ARYAOS_DEV_DEVICE=aryaos-e406 ARYAOS_DEV_DEVICE_SYNC=1 \
  ./scripts/test-dev-device.sh
```

For Ansible, combine the normal inventory with the dynamic inventory:

```bash
ansible-playbook -i inventory.yml -i scripts/aryaos-dev-inventory \
  site.yml --limit aryaos-dev-device --tags cotbridge,lincot
```

Use `scp` or `rsync` with an IP printed by `aryaos-dev-device resolve` for
one-off files. Rebuild the image when exact pi-gen parity matters.

## USB power

If several SDRs brown out USB, run `./scripts/enable-pi-usb-current.sh` from the
synced tree and reboot. New images apply the same boot configuration during the
AryaOS stage.
