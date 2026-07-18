# Factory reset

A **factory reset** returns a box to its just-flashed, pre-first-boot state
without re-flashing the media. It's the clean-slate button: hand a unit to a
new operator, recover from a botched configuration, or repurpose a box for a
different mission — all without touching the OS or reinstalling packages.

!!! info "This is not a secure wipe"
    Factory reset restores config and clears identity; it does **not** securely
    erase anything from the media. To sanitize a box for decommission or before
    it leaves your control, use **[Zeroize](./zeroize.md)** instead.

## What it does — and doesn't

=== "What it clears"

    - **Site config** — restores `/etc/aryaos/aryaos-config.txt` and
      `/etc/charontak.ini` from the packaged defaults in
      `/usr/share/aryaos/defaults`; resets `issue`, `issue.net`, and `motd`.
    - **Per-gateway `/etc/default/<svc>`** — reinstalled to package defaults
      **when online** (via `apt-get --reinstall`). Offline, these are left as-is
      — reset again online to restore them.
    - **Operator-uploaded TAK certificates** — deletes the files under
      `/etc/aryaos/tls`, `/etc/charontak/tls`, and the per-gateway `tls`
      directories (the directories themselves are kept).
    - **Device identity** — removes the machine-id and firstboot markers so
      `aryaos-firstboot` re-runs: the box gets a **new**
      [`DEVICE_SUFFIX`](../reference/glossary.md#device_suffix), hostname, and
      per-device web TLS certificate on the next boot, and the login password is
      re-expired.
    - **Local state** — drops update, support-bundle, and config-backup state
      JSON that referenced the old identity.

=== "What it keeps"

    - **The OS and all installed packages** — nothing is uninstalled or
      re-flashed.
    - **The network connection, by default** — saved Wi-Fi/NetworkManager
      connections and the onboarding hotspot password are **preserved** unless
      you pass `--wipe-network`, so a remote box isn't stranded off the network
      after a reset. (The AntSDR point-to-point link is always kept.)

After the reset the box **reboots into first-boot setup**, exactly like a
freshly flashed image — first boot re-derives identity and regenerates the web
TLS certificate.

## When to use it

- Re-issuing a unit to a new operator or a new mission.
- Recovering from a configuration you can't unwind by hand.
- Clearing a lab/test box back to a known baseline.

!!! warning "Back up first"
    A factory reset overwrites your site config and deletes uploaded TAK
    certs. If there's any chance you'll want the current setup again — or want
    to move it to a replacement box — make a
    [backup](./backup-restore.md) first.

## How to run it

=== "In Cockpit (recommended)"

    1. Open **Cockpit → AryaOS Site → Factory reset**.
    2. Read the confirmation, which lists what will be cleared, and confirm.
    3. The card runs the reset (`--service`) and the box reboots into first-boot
       setup.

=== "From the shell"

    ```bash
    sudo aryaos-factory-reset                  # keep network; prompt to confirm
    sudo aryaos-factory-reset --wipe-network   # ALSO remove saved Wi-Fi + hotspot password
    sudo aryaos-factory-reset --no-reboot      # do the reset but stay up (testing)
    ```

    Interactively, the command lists what it will clear and requires you to
    **type the hostname** to proceed:

    ```text
    Type the hostname (aryaos-1a2b) to proceed:
    ```

    | Flag | Effect |
    | --- | --- |
    | *(none)* | Reset config + identity, **keep** the network, prompt, then reboot. |
    | `--wipe-network` | Also remove saved Wi-Fi/NetworkManager connections and the hotspot password (box reverts to open onboarding). |
    | `--service` | Non-interactive (used by the Cockpit card, which already confirmed). |
    | `--no-reboot` | Do the reset but don't reboot — for testing. |

## Factory reset vs. zeroize

Both return the box to a clean first-boot state, but they answer different
questions:

| | Factory reset | [Zeroize](./zeroize.md) |
| --- | --- | --- |
| **Goal** | Clean slate for re-use | Secure sanitize for decommission/capture |
| **Config & identity** | Restored to defaults / cleared | Destroyed |
| **Certs & keys** | Uploaded TAK certs deleted | All key material shredded + overwritten |
| **Logs / tracks / history** | Not specifically wiped | Shredded; free space overwritten + TRIMmed |
| **Network** | **Kept** by default | **Wiped** by default (`--keep-network` to keep) |
| **Secure erase?** | **No** | Best-effort (see the flash-media caveat) |

If the box is going somewhere you don't control, use
**[Zeroize](./zeroize.md)**, not factory reset.

## Related

<div class="grid cards" markdown>

- :material-content-save: **Back up & restore** — snapshot config before you reset. [Back up & restore](./backup-restore.md)
- :material-nuke: **Zeroize** — the secure-erase counterpart for decommission. [Zeroize](./zeroize.md)
- :material-console: **CLI helpers** — the full `aryaos-factory-reset` reference. [CLI helpers](../reference/cli-helpers.md#aryaos-factory-reset)
- :material-restart: **First boot** — what the box does when it comes back up. [First boot & first login](../get-started/first-boot.md)

</div>
