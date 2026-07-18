# CLI helpers

AryaOS installs a small set of `aryaos-*` helper commands in `/usr/local/sbin`. These are the same actions the [AryaOS Site](../admin/aryaos-site.md) web cards run — so **SSH is optional**. Reach for the shell when you are already on the console, scripting a fleet, or want to see raw output.

!!! tip "Every command has a web-console equivalent"
    You never have to touch the shell. Each helper below is backed by a card in **Cockpit → AryaOS Site**. See [AryaOS Site page](../admin/aryaos-site.md).

## At a glance

| Command | What it does | Root? | Web equivalent |
|---|---|---|---|
| [`aryaos-update {check\|apply\|status}`](#aryaos-update) | Check for and apply package updates | check/apply: yes | Software updates |
| [`aryaos-support-bundle`](#aryaos-support-bundle) | Collect redacted diagnostics into a tarball | yes | Support bundle |
| [`aryaos-set-nodered-password`](#aryaos-set-nodered-password) | Rotate the Node-RED admin password (stdin) | yes | Node-RED admin password |
| [`aryaos-sdr {list\|set-serial}`](#aryaos-sdr) | List RTL-SDR dongles / rewrite EEPROM serials | set-serial: yes | Radios |
| [`aryaos-role {list\|set}`](#aryaos-role) | Switch the device's sensor role | set: yes | Device role |
| [`aryaos-import-tak-dp`](#aryaos-import-tak-dp) | Import a TAK connection data package / enrollment | yes | TAK connection |
| [`aryaos-config-backup {backup\|restore\|list}`](#aryaos-config-backup) | Back up / restore the full config set | yes | Backup & restore |
| [`aryaos-factory-reset`](#aryaos-factory-reset) | Return the box to its just-flashed state | yes | Factory reset |
| [`aryaos-zeroize`](#aryaos-zeroize) | Best-effort secure sanitize (decommission) | yes | Zeroize |
| [`aryaos-firstboot.sh`](#aryaos-firstboot) | One-time first-boot personalization | yes | — (runs automatically) |

Commands print JSON where a machine (Cockpit) consumes the output, and require `sudo` for anything that changes the system.

## aryaos-update {#aryaos-update}

One-command update path for deployed units. Everything installs from the [signed snstac apt repository](https://snstac.github.io/packages).

```bash
sudo aryaos-update check    # refresh apt metadata, report upgradable packages (JSON)
sudo aryaos-update apply    # non-interactively apply all pending upgrades (full-upgrade)
aryaos-update status        # report last check/apply + reboot-required (JSON, no root)
```

- `apply` runs a `full-upgrade` then an `autoremove --purge`, preserving locally edited config files (never prompts on a dpkg conffile).
- State is written to `/var/lib/aryaos/update-check.json` and `update-apply.json`; `status` reports the installed AryaOS version and whether a reboot is required.

!!! note "The web card survives a closed browser"
    In Cockpit, `apply` runs under `aryaos-update.service`, so an upgrade continues even if you close the browser tab. See [Updates](../operations/updates.md).

## aryaos-support-bundle {#aryaos-support-bundle}

Collects **redacted** diagnostics — system identity, package versions, service status, journals, network state, config files, and a sensor snapshot — into a single tarball for support.

```bash
sudo aryaos-support-bundle
```

- Prints the bundle path on the last line of stdout and records it in `/var/lib/aryaos/support-bundle.json`. Keeps the three newest bundles.
- **Secrets are stripped:** values of keys matching `PASSWORD`/`TOKEN`/`SECRET`/`PASSPHRASE`/`PSK` and `tak://` enrollment credentials are replaced with `[REDACTED]`. No private key material (nothing from `/etc/aryaos/tls` or `/etc/charontak/tls`) is ever included.

See [Support bundles](../operations/support-bundles.md).

## aryaos-set-nodered-password {#aryaos-set-nodered-password}

Rotates the Node-RED editor admin password. Reads the new password from **stdin** (never on the command line):

```bash
echo 'a-strong-password' | sudo aryaos-set-nodered-password
```

- Minimum length **8** characters. The password is bcrypt-hashed with Node-RED's own bundled `bcryptjs`, written into `settings.js`, and Node-RED is restarted.

!!! danger "Rotate this before fielding a unit"
    AryaOS ships Node-RED with a publicly known default admin password, and the Node-RED editor can run arbitrary code as the `node-red` user. See [Node-RED dashboard](../node-red.md) and [Security posture](../security.md).

## aryaos-sdr {#aryaos-sdr}

Enumerates RTL-SDR dongles and rewrites their EEPROM serials so decoders can tell them apart.

```bash
sudo aryaos-sdr list                        # JSON: index, vendor, product, serial
sudo aryaos-sdr set-serial 0 stx:1090:0     # write a new EEPROM serial to device 0
```

- AryaOS serial conventions: `stx:1090:0` for the ADS-B 1090 MHz path (`readsb`/`dump1090-fa`), `stx:978:0` for UAT 978 MHz (`dump978-fa`, `ARYAOS_UAT_RTL_SERIAL`).
- `set-serial` stops any active SDR consumers (`readsb`, `dump1090-fa`, `dump978-fa`, `ais-catcher`), writes the serial, and restarts what it stopped.
- A serial is 1–32 characters of `[A-Za-z0-9:._-]`. **Replug the dongle (or reboot)** before the new serial is visible to consumers.

See [Radios & SDRs](../config/radios-sdr.md).

## aryaos-role {#aryaos-role}

Switches which sensor pipelines run at runtime. The CoT core (`charontak`, `lincot`, `gpstak`, `gpsd`) always runs; the role only toggles sensor units. The choice is persisted as `ARYAOS_ROLE` in the site config.

```bash
aryaos-role list            # JSON: available roles, their units, and the current role (no root)
sudo aryaos-role set air    # enable this role's units, disable the rest, persist ARYAOS_ROLE
```

| Role | Sensor pipelines |
|---|---|
| `multi` | All: ADS-B + UAT, AIS, drones |
| `air` | ADS-B / UAT (`readsb` or `dump1090-fa`, `dump978-fa`, `adsbcot`, `gdltak`) |
| `maritime` | AIS (`ais-catcher`, `aiscot`) |
| `cuas` | Drones (`dronecot`, `sikw00fcot`) |
| `relay` | CoT routing only — no sensors |

The ADS-B decoder unit follows `ARYAOS_ADSB_DECODER` (`readsb` or `dump1090_fa`). Units missing from the image are skipped, not errors. See [Device roles](../config/device-roles.md).

## aryaos-import-tak-dp {#aryaos-import-tak-dp}

Imports an ATAK/iTAK **connection data package** (or a `tak://` enrollment deep-link) so AryaOS forwards its CoT to your TAK Server over TLS.

```bash
sudo aryaos-import-tak-dp connection-data-package.zip
sudo aryaos-import-tak-dp --enrollment-url-file /path/to/tak-url.txt
```

- Extracts the client and CA certificates, installs them under `/etc/aryaos/tls` (group `tak-certs`, keys `0640`), and writes a CharonTAK `lane:local-to-takserver` egress lane pointing at the server, then restarts CharonTAK.
- Supports `ssl`/`tls`/`tcp` connect strings; a `tak://com.atakmap.app/enroll` enrollment URL is resolved to a data package via PyTAK before import.
- Prints a JSON result describing the destination. This is the same import the **TAK connection** card runs. See [Connect to a TAK Server](../deploy/connect-tak-server.md).

## aryaos-config-backup {#aryaos-config-backup}

Backs up and restores the full AryaOS configuration set — site config, charontak lanes, gateway `/etc/default` files, saved networks, TAK certs, and Node-RED credentials — as a single tarball.

```bash
sudo aryaos-config-backup backup                 # full backup (includes secrets)
sudo aryaos-config-backup backup --no-secrets    # shareable; TLS keys + network/Node-RED secrets excluded
sudo aryaos-config-backup restore FILE           # restore an archive (prompts to confirm)
sudo aryaos-config-backup restore FILE --service # restore without prompting (Cockpit card)
aryaos-config-backup list                         # list existing backups (JSON)
```

- Archives land in `/var/lib/aryaos/backups/` as `aryaos-config_<hostname>_<timestamp>.tar.gz`, mode **`0600`** (dir `0700`). Keeps the **five newest**; records the latest in `/var/lib/aryaos/config-backup.json`.
- `restore` validates the archive by its `MANIFEST.txt`, unpacks in place preserving perms, then `try-restart`s the CoT fleet and `lighttpd`; recommends a reboot.

!!! danger "A full backup contains private keys and Wi-Fi PSKs"
    The default `backup` includes TAK client certs, TLS keys, NetworkManager PSKs, and Node-RED credentials — store it securely. Use `--no-secrets` for a shareable, config-only archive. Same action as the **Backup & restore** card. See [Back up & restore](../operations/backup-restore.md).

## aryaos-factory-reset {#aryaos-factory-reset}

Returns the box to its just-flashed, pre-first-boot state **without re-flashing**: restores AryaOS config from `/usr/share/aryaos/defaults`, deletes uploaded TAK certs, clears device identity (so `aryaos-firstboot` re-runs and picks a new suffix/hostname), re-expires the login password, then reboots. Keeps the OS, packages, and — by default — the network.

```bash
sudo aryaos-factory-reset                  # keep network; type the hostname to confirm; reboot
sudo aryaos-factory-reset --wipe-network   # ALSO remove saved Wi-Fi + hotspot password
sudo aryaos-factory-reset --service        # non-interactive (Cockpit card)
sudo aryaos-factory-reset --no-reboot      # reset but don't reboot (testing)
```

- **Not a secure erase** — it restores/clears config but does not sanitize the media. For decommission use [`aryaos-zeroize`](#aryaos-zeroize).
- Per-gateway `/etc/default/<svc>` files are reset via `apt-get --reinstall` **only when online**; offline they're left as-is.
- Same action as the **Factory reset** card. See [Factory reset](../operations/factory-reset.md).

## aryaos-zeroize {#aryaos-zeroize}

**Best-effort** sanitization for decommission or capture: shreds and overwrites every key, credential, log, recorded track, and identity, restores a secret-free site config, overwrites free space, TRIMs, then reboots to a clean first-boot state. The box stays usable (SSH host keys are regenerated).

```bash
sudo aryaos-zeroize                  # wipe everything incl. saved networks; type "ERASE <hostname>" to confirm; reboot
sudo aryaos-zeroize --keep-network   # preserve saved Wi-Fi/NetworkManager connections (they hold PSKs)
sudo aryaos-zeroize --service        # non-interactive (Cockpit card, which required a confirmation phrase)
sudo aryaos-zeroize --no-reboot      # wipe but don't reboot (testing)
```

!!! danger "Flash-media limitation"
    On flash (microSD/eMMC/NVMe), wear-leveling means overwrite + TRIM are **best-effort, not a guarantee** that prior contents are unrecoverable. For a hard guarantee use full-disk encryption + crypto-erase (roadmap) or physically destroy the media. Same action as the **Zeroize** card, which requires a typed confirmation phrase. See [Zeroize](../operations/zeroize.md).

## aryaos-firstboot.sh {#aryaos-firstboot}

Runs once automatically via `aryaos-firstboot.service` on the first boot — you should not need to invoke it by hand. It derives [`DEVICE_SUFFIX`](glossary.md#device_suffix), sets the hostname `aryaos-xxxx`, names the hotspot `AryaOS-xxxx`, regenerates the per-device web TLS certificate, and (on release images) expires the default `pi` password. See [First boot & first login](../get-started/first-boot.md).

## See also

<div class="grid cards" markdown>

- :material-view-dashboard: **AryaOS Site page** — The web equivalents of these commands. [AryaOS Site page](../admin/aryaos-site.md)
- :material-book-open: **Glossary** — Terms these commands touch. [Glossary](glossary.md)
- :material-shield-check: **Security posture** — Why passwords must be rotated. [Security posture](../security.md)

</div>
