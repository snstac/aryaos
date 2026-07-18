# Zeroize (secure sanitize)

**Zeroize** removes and overwrites every secret, credential, key, log, recorded
track, and identity on the box, then TRIMs and overwrites free space and
reboots to a clean first-boot state. It's the control you reach for when a unit
is being **decommissioned** or is at risk of **capture** — when what matters is
that nothing sensitive can be recovered from it, not that it stays configured.

The box is **not bricked.** After a zeroize it reboots into a clean first-boot
state and is fully usable again — it just has no more secrets on it.

!!! danger "Flash-media limitation — read this before you rely on zeroize"
    On flash media (microSD, eMMC, NVMe) **wear-leveling means overwriting a
    file or free space does *not* guarantee the prior contents are
    unrecoverable.** The controller may have written your data elsewhere, and
    the old physical blocks can persist beyond software's reach.

    Zeroize removes secrets, shreds their current blocks, issues TRIM, and
    overwrites free space as a **best effort** — nothing more. It is honest
    hygiene, not a hardware guarantee.

    **For a hard guarantee, you need one of:**

    - **Full-disk encryption with key destruction (crypto-erase)** — if the data
      was only ever written encrypted, destroying the key makes it unrecoverable
      regardless of where the controller put the ciphertext. *(Full-disk
      encryption is on the AryaOS roadmap as the stronger sanitization path.)*
    - **Physical destruction of the media** — the only unconditional guarantee.

    Treat zeroize as the software best-effort layer, not a substitute for
    crypto-erase or physical destruction when the threat model demands
    certainty.

## What gets erased

Zeroize (`/usr/local/sbin/aryaos-zeroize`) shreds each file (single pass +
zero — multi-pass is pointless on flash), then removes it. In order, it wipes:

| Category | What is destroyed |
| --- | --- |
| **TLS / TAK key material** | `/etc/aryaos/tls`, `/etc/charontak/tls`, the per-gateway `tls` trees, the snakeoil key, and `/etc/lighttpd/ssl`. |
| **SSH host keys** | Wiped, then **regenerated** (`ssh-keygen -A`) so SSH still works after the reboot. |
| **VPN state** | `tailscale logout`, then `/var/lib/tailscale` wiped. |
| **Node-RED credentials** | `flows_cred.json` wiped; admin password reset to a **random, unrecorded** value (rotate it from the web console after reboot). |
| **Recorded tracks & local files** | `/var/www/html/recorder` (recorded CoT), `/var/lib/aryaos/backups`, `/var/lib/aryaos/support`, and the state JSON files. |
| **Saved networks** | `/etc/NetworkManager/system-connections` and the comitup hotspot password — **wiped by default** (they hold PSKs); `--keep-network` preserves them. |
| **Site-config secrets** | Restores the packaged default `aryaos-config.txt` (no secrets) and strips any remaining `PASSWORD`/`TOKEN`/`SECRET`/`PASSPHRASE`/`PSK` lines. |
| **Shell history & lab key** | `root` and per-user `.bash_history`; removes the `aryaos-dev-lab` key from `pi`'s `authorized_keys`. |
| **Logs** | Rotates and vacuums journald (already RAM-volatile), then shreds anything on disk under `/var/log`. |
| **Device identity** | Removes machine-id and firstboot markers so a **new** [`DEVICE_SUFFIX`](../reference/glossary.md#device_suffix)/hostname is derived on next boot. |
| **Free space** | Fills each writable filesystem with zeros until full, deletes the fill, then runs `fstrim -av` to return blocks to the controller. |

The free-space overwrite is the slow step — the command prints *"overwriting
free space (this can take a while)…"* while it runs. When it finishes the box
reboots into a clean first-boot state.

## How to run it

=== "In Cockpit (recommended)"

    1. Open **Cockpit → AryaOS Site → Zeroize**.
    2. The card requires you to **type a confirmation phrase** — this is
       destructive and irreversible, so there is no single-click path.
    3. Confirm. The card runs the wipe (`--service`), overwrites free space, and
       the box reboots clean.

=== "From the shell"

    ```bash
    sudo aryaos-zeroize                  # wipe everything incl. saved networks, then reboot
    sudo aryaos-zeroize --keep-network   # preserve saved Wi-Fi/NetworkManager connections
    sudo aryaos-zeroize --no-reboot      # do the wipe but stay up (testing)
    ```

    Interactively, zeroize requires you to type an explicit phrase to proceed:

    ```text
    !!! ZEROIZE: this destroys all keys, credentials, logs, tracks, and
    !!! identity on aryaos-1a2b and reboots it to a clean state.
    Type ERASE aryaos-1a2b to proceed:
    ```

    | Flag | Effect |
    | --- | --- |
    | *(none)* | Wipe everything, **including** saved networks, then reboot. |
    | `--keep-network` | Preserve saved Wi-Fi/NetworkManager connections (they contain PSKs — only for a box you're keeping on your own network). |
    | `--service` | Non-interactive (used by the Cockpit card, which required the confirmation phrase). |
    | `--no-reboot` | Do the wipe but don't reboot — for testing. |

## Zeroize vs. factory reset

Zeroize is the secure counterpart to a [factory reset](./factory-reset.md).
Factory reset restores config to defaults for **re-use** and keeps the network
by default; zeroize **destroys** everything for **decommission** and wipes the
network by default. If the box will leave your control, use zeroize. See the
[comparison table](./factory-reset.md#factory-reset-vs-zeroize).

## Related

<div class="grid cards" markdown>

- :material-backup-restore: **Factory reset** — the non-destructive clean-slate counterpart. [Factory reset](./factory-reset.md)
- :material-shield-lock: **Security posture** — where zeroize fits in decommissioning. [Security posture](../security.md#decommissioning)
- :material-console: **CLI helpers** — the full `aryaos-zeroize` reference. [CLI helpers](../reference/cli-helpers.md#aryaos-zeroize)

</div>
