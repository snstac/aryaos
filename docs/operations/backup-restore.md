# Back up & restore configuration

An AryaOS box holds a lot of hard-won state: your site config, the sensor
role, charontak lanes, TAK client certificates, saved Wi-Fi networks, and the
Node-RED flows. The `aryaos-config-backup` helper packs all of it into one
restorable tarball — so you can snapshot a working unit before a change, or
migrate a whole configuration onto a replacement box in minutes.

## Make a backup

=== "In Cockpit (recommended)"

    1. Open **Cockpit → AryaOS Site → Backup & restore**.
    2. Click **Create backup**. AryaOS packs the config set into a tarball on
       the box and lists it under existing backups.
    3. Download it to your machine to keep a copy off the unit.

=== "From the shell"

    ```bash
    sudo aryaos-config-backup backup                 # full backup (includes secrets)
    sudo aryaos-config-backup backup --no-secrets    # shareable, key material excluded
    sudo aryaos-config-backup list                   # list existing backups (JSON)
    ```

    The command prints a one-line summary and the archive path on the last line
    of stdout:

    ```text
    Backup written (18422 bytes).
    /var/lib/aryaos/backups/aryaos-config_aryaos-1a2b_20260718T140355Z.tar.gz
    ```

## What's in a backup

The backup (`/usr/local/sbin/aryaos-config-backup`) captures the AryaOS
configuration set. Missing paths are skipped, not errors.

| Area | Contents |
| --- | --- |
| **Site & CoT config** | `/etc/aryaos` (site config + TLS material), `/etc/charontak.ini`, `/etc/charontak` (lanes + TLS). |
| **Onboarding / hotspot** | `/etc/comitup.conf`, `/etc/comitup.json`. |
| **Gateway defaults** | `/etc/default/{adsbcot,aiscot,dronecot,lincot,gpstak,gdltak,sikw00fcot,charontak,gpsd}` and the `/etc/{adsbcot,aiscot,dronecot,lincot}` config trees. |
| **Secrets** *(full backup only)* | `/etc/NetworkManager/system-connections` (Wi-Fi PSKs), Node-RED `settings.js` and `flows_cred.json`, and the TLS key material inside the config trees above. |

Every archive carries a `MANIFEST.txt` recording when it was made, the
hostname, the AryaOS version, whether secrets were included, and the exact list
of paths captured. That manifest is also how a restore validates the file is a
genuine AryaOS backup.

!!! danger "A full backup contains private keys and Wi-Fi passwords"
    The default `backup` includes **TAK client certificates and TLS private
    keys, NetworkManager Wi-Fi PSKs, and Node-RED credentials.** Anyone holding
    that archive can impersonate the unit and its TAK connection. AryaOS writes
    every archive **`0600` root** and keeps the directory `0700`, but once you
    copy it off the box it is your responsibility — **store full backups
    securely.**

    For a copy you can safely share (attach to a ticket, hand to a teammate,
    template across a fleet), use **`--no-secrets`**: it omits the TLS key
    material (`--exclude=etc/.../tls`) and the network/Node-RED secret files, so
    the archive carries the *shape* of your config without any credentials.

## Where backups land

Backups are written to **`/var/lib/aryaos/backups/`** as
`aryaos-config_<hostname>_<timestamp>.tar.gz`.

- Each archive is mode **`0600`** (root-only) and the directory is `0700`.
- Only the **five newest** backups are kept — older ones are pruned
  automatically each time you create a new one.
- The most recent backup's path and size are recorded in
  `/var/lib/aryaos/config-backup.json`, which is how the Cockpit card lists it.

## Restore a backup

=== "In Cockpit"

    Open **Cockpit → AryaOS Site → Backup & restore**, pick a backup, and
    click **Restore**. The card confirms with you first, then unpacks the
    archive and restarts the affected services.

=== "From the shell"

    ```bash
    sudo aryaos-config-backup restore /var/lib/aryaos/backups/aryaos-config_aryaos-1a2b_20260718T140355Z.tar.gz
    ```

    Restore prompts for confirmation before it overwrites current config (the
    Cockpit card, which already confirmed with you, passes `--service` to skip
    the prompt).

The restore validates the archive, unpacks it in place preserving
permissions and ownership, runs `systemctl daemon-reload`, and does a
`try-restart` of the CoT fleet (`charontak`, `gpstak`, `aiscot`, `lincot`,
`adsbcot`, `dronecot`) plus `lighttpd`.

!!! note "Reboot after a restore"
    The restore finishes with:

    > *Restore complete. A reboot is recommended to fully apply network and
    > identity changes.*

    Reboot the unit so network connections and device identity are fully
    re-applied.

## Migrating to a replacement box

Backups are the fast path when hardware fails or you're swapping a fielded unit:

1. On the **old box** (or from your last saved backup), make a **full** backup
   and download it — you want the TAK certs and Wi-Fi PSKs, so *do not* use
   `--no-secrets` here.
2. Flash AryaOS onto the **replacement box** and let it complete first boot.
3. Copy the archive onto the new box (over SSH or the
   [VPN](../networking/vpn-tailscale.md)) and run `aryaos-config-backup
   restore FILE`.
4. **Reboot.** The unit comes up with your site config, sensor role, TAK
   connection, lanes, and saved networks in place.

!!! tip "The replacement keeps its own identity"
    A restore lays your *configuration* over the new box, but the new unit keeps
    its own machine-id-derived [`DEVICE_SUFFIX`](../reference/glossary.md#device_suffix),
    hostname, and per-device web TLS certificate from its own first boot. You're
    migrating config, not cloning identity.

## Related

<div class="grid cards" markdown>

- :material-backup-restore: **Factory reset** — clear config back to defaults (back up first). [Factory reset](./factory-reset.md)
- :material-nuke: **Zeroize** — securely sanitize a box for decommission. [Zeroize](./zeroize.md)
- :material-console: **CLI helpers** — the full `aryaos-config-backup` reference. [CLI helpers](../reference/cli-helpers.md#aryaos-config-backup)
- :material-tune: **AryaOS Site** — the admin page hosting the backup card. [AryaOS Site](../admin/aryaos-site.md)

</div>
