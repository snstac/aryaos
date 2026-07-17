# Support bundles

When a fielded unit misbehaves, generate a **support bundle**: one redacted
tarball with everything a troubleshooter needs — system state, service status,
recent logs, network and firewall state, and sensor configs — with passwords,
tokens, and enrollment credentials stripped out. Attach it to a field report
instead of describing the problem over the radio.

## Generate a bundle

=== "In Cockpit (recommended)"

    1. Open **Cockpit → AryaOS Site → Support bundle**.
    2. Click **Generate support bundle**. AryaOS collects diagnostics and packs
       them into a tarball.
    3. Click **Download** to save the `.tar.gz` to your machine, then attach it
       to your report.

=== "From the shell"

    ```bash
    sudo aryaos-support-bundle
    ```

    The command prints a one-line summary and the bundle path on the last line
    of stdout:

    ```text
    Bundle ready (48213 bytes; secrets redacted).
    /var/lib/aryaos/support/aryaos-support_aryaos-1a2b_20260717T140355Z.tar.gz
    ```

## What's collected

The bundle (`/usr/local/sbin/aryaos-support-bundle`) captures a snapshot across
these areas. Every command is time-limited so collection never hangs, and a
failing command is noted rather than aborting the bundle.

| Area | Contents |
| --- | --- |
| **System** | `uname`, AryaOS release/version, `os-release`, uptime, `free -h`, `df -h`, and (on Pi) CPU temperature and throttling from `vcgencmd`. |
| **Packages** | Installed versions and status for the sensor stack, Cockpit, decoders, Node-RED, and core services. |
| **Services** | `systemctl --failed`, plus per-unit `systemctl status` for the sensor gateways and infrastructure units. |
| **Journals** | The last 4000 lines of this boot's journal, plus per-unit logs (last 500 lines each) for the sensor gateways, `readsb`, and `gpsd`. |
| **Network** | `ip addr` / `ip route`, `resolv.conf`, `nmcli device status`, firewalld state and all zones, and listening sockets (`ss -tulnp`). |
| **Configs (redacted)** | Site config `aryaos-config.txt`, `charontak.ini`, and each gateway's `/etc/default/<svc>` — passed through the redactor. |
| **Sensor snapshots** | A capped `aircraft.json` (ADS-B), the neighbor cache `neighbors.json`, and a short `gpsd` sample. |

## What's redacted — and what's never included

This is the part to be sure of before you send a bundle to anyone.

!!! info "Redaction policy"
    - Any config value whose key matches
      **`PASSWORD` / `TOKEN` / `SECRET` / `PASSPHRASE` / `PSK`** is replaced with
      `[REDACTED]` before the file goes into the bundle.
    - `tak://` enrollment credentials — the `token=` and `username=` fields in
      TAK enrollment URLs — are redacted the same way.
    - **No private key material is ever included.** Nothing from
      `/etc/aryaos/tls` or `/etc/charontak/tls` (client certificates, keys, CA
      material) is copied into the bundle at all.

In short: the bundle carries the *shape* of your configuration — which services
run, how they're wired, what's failing — without the credentials that would let
someone impersonate the unit or its TAK connection.

!!! tip "Sanity-check with your eyes"
    A bundle is a plain gzipped tar of text files. If you want to confirm what's
    in one before sending it, extract it and read it:

    ```bash
    tar -tzf aryaos-support_*.tar.gz          # list contents
    tar -xzf aryaos-support_*.tar.gz          # extract to inspect
    ```

## Where bundles land

Bundles are written to **`/var/lib/aryaos/support/`** as
`aryaos-support_<hostname>_<timestamp>.tar.gz`.

- Each bundle file is mode **`0600`** (root-only) and the directory is `0700`.
- Only the **three newest** bundles are kept — older ones are pruned
  automatically each time you generate a new one.
- The most recent bundle's path and size are recorded in
  `/var/lib/aryaos/support-bundle.json`, which is how the Cockpit card offers
  the **Download** button.

!!! note "Download over an admin channel"
    The Cockpit **Download** button pulls the file over your existing
    authenticated Cockpit session. If you copy a bundle off the box by hand
    (`scp`, etc.), do it over SSH or the [VPN](../networking/vpn-tailscale.md) —
    the file is redacted, but it still describes your deployment.

## Attaching to a field report

1. Generate the bundle at the moment the problem is happening (journals are
   capped, so fresh is better).
2. Download it from the Cockpit card.
3. Attach the `.tar.gz` to your ticket or field report, and note what the unit
   was *supposed* to be doing and what it did instead.

## Related

<div class="grid cards" markdown>

- :material-update: **Updates** — rule out a stale build before deep-diving. [Updates](updates.md)
- :material-shield-lock: **Security posture** — the redaction policy in the wider hardening picture. [Security posture](../security.md)
- :material-access-point-network: **Nearby nodes** — check the rest of the fleet's health. [Nearby nodes](neighbors.md)
- :material-tune: **AryaOS Site** — the admin page hosting the support-bundle card. [AryaOS Site](../admin/aryaos-site.md)

</div>
