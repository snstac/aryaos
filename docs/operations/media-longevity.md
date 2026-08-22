# Install media longevity

AryaOS runs from flash: a microSD card, eMMC, or an NVMe SSD. Flash media wears
out by *writing* - every block has a finite number of program/erase cycles, and
a chatty Linux install (swap, logs, atime updates) can burn through a cheap SD
card in a single fire season. AryaOS is tuned from the factory to write to the
install media as little as possible, so a fielded box survives.

There is **nothing to configure** - the tuning below is on by default in every
image.

## What AryaOS does by default

| Technique | What it saves |
| --- | --- |
| **RAM-only zram swap** | No swapfile writes ever hit the SD/NVMe. Swap lives in RAM instead (`zstd`-compressed, sized `min(ram / 2, 4096)` MB), so a memory spike from multi-SDR + Node-RED + containers still can't OOM-kill a service - and it costs zero media writes. |
| **journald volatile (logs in RAM)** | The systemd journal is stored in RAM, not on disk, so the constant log churn from a running sensor stack never touches the media. |
| **tmpfs for `/tmp`, `/var/tmp`, `/var/log`** | These write-heavy directories are RAM-backed tmpfs mounts (`/tmp` and `/var/tmp` capped at 100 MB, `/var/log` at 50 MB). Scratch files and logs live and die in memory. |
| **Bounded sudo I/O audit history** | Sudo still records compressed command I/O for troubleshooting, but `Defaults maxseq=128` makes the history wrap after 128 sessions. This prevents audit traffic from exhausting the 50 MB `/var/log` tmpfs. |
| **`noatime` on the root filesystem** | Reading a file no longer triggers a metadata *write* to update its access time - a huge, invisible source of wear on a busy box. |
| **Weekly `fstrim` (TRIM)** | `fstrim.timer` is enabled, so the filesystem periodically tells the flash controller which blocks are free. That keeps wear-leveling effective and sustains write performance over the life of the card. |

!!! info "zram is swap in RAM, not on disk"
    `dphys-swapfile` is disabled on older Raspberry Pi OS releases. On Trixie,
    AryaOS explicitly pins `rpi-swap` to its file-free `zram` mechanism instead
    of the upstream `zram+file` default. The `zram-generator.conf` overlay
    creates `zram0` at priority 100. The box tolerates memory spikes without an
    OOM-kill, and without a writeback file on the install media. See the source
    tuning in `stages/stage-adsbcot/00-sys-tweaks/00-run-chroot.sh`.

## The tradeoff: logs live in RAM

Because the journal and `/var/log` are RAM-backed, **logs do not survive a
reboot.** That is a deliberate wear tradeoff: it spares the media from the
single biggest source of write traffic on an appliance, at the cost of
persistent on-disk history.

!!! tip "Capture logs before they're gone"
    If you need the logs from a misbehaving unit, grab them *while the problem
    is happening* - generate a [support bundle](./support-bundles.md), which
    snapshots the current journal into a redacted tarball you can attach to a
    field report. A reboot clears the RAM journal, so fresh is always better.

The sudo I/O history is also bounded by **session count, not elapsed time**.
Busy diagnostic or automation runs may therefore replace old command sessions
well before a reboot.

TAK clients can also be exposed to very long remote outages. PyTAK `7.5.2` and
newer retries transient TCP, TLS, WebSocket, and local network-policy failures
inside one process with bounded, jittered exponential backoff. The same
supervisor is available to gateways with custom worker graphs; GPSCOT `2.0.1`,
GDLCOT `2.0.1`, and SiKW00FCOT `1.0.2` rebuild their transports in process
instead of relying on a systemd crash loop. PKCS#12 client certificates are
loaded from short-lived extracted PEM files that are removed immediately, so a
week-long outage cannot fill `/tmp` or `/var/tmp` with reconnect artifacts.

## Check and recover tmpfs capacity

Run these checks when privileged commands start failing, after a long burn-in,
or as part of routine field validation:

```bash
df -h /var/log
df -h /tmp /var/tmp
sudo -n true
sudo -n grep '^Defaults maxseq=128$' /etc/sudoers.d/aryaos
sudo -n find /var/log/sudo-io -mindepth 3 -maxdepth 3 -type d | wc -l
sudo -n find /tmp /var/tmp -maxdepth 1 -type f -user acarscot -name 'tmp*.pem'
```

A current image should accept passwordless sudo, report the `maxseq` line, keep
no more than 128 completed I/O sessions, leave all three tmpfs mounts below 95%
use, and produce no ACARSCOT PEM listing. The HIL service and security modules
check the configuration and capacity automatically:

```bash
ARYAOS_DEV_DEVICE=aryaos-e406 ./scripts/aryaos-test/run.sh
```

The characteristic exhausted-tmpfs error is:

```text
sudo: unable to write to I/O log file: No space left on device
sudo: error initializing I/O plugin sudoers_io
```

For a TAK client, the equivalent symptom is `No usable temporary directory`
or `No space left on device` during certificate loading, often accompanied by
many root-level `tmp*.pem` files owned by the gateway account. Upgrade PyTAK to
`7.5.2` or newer before restarting the gateway. If cleanup is required, stop
the affected unit and remove only the confirmed root-level temporary PEMs owned
by that service account; never remove its persistent certificate cache under
`/var/lib/<service>/.pytak/certs`.

Capture a support bundle before recovery if sudo and enough log space remain.
A controlled reboot is the normal recovery: `/var/log` is RAM-backed, so the
reboot clears the full tmpfs. If sudo is already unusable, recover from a local
root console or perform the controlled reboot through the appliance power/UI
path; do not recursively delete `/var/log`. After recovery, install AryaOS
overlay `2.0.6` or newer, reboot once, and rerun the security check above.

## NVMe vs SD cards

The tuning above applies to every AryaOS box regardless of media, but the media
itself matters:

=== "SNS-supplied boxes (NVMe/eMMC)"

    The hardware Sensors & Signals sells runs from **NVMe SSD or eMMC** -
    endurance-rated flash with a real controller and far higher write budgets
    than an SD card. Combined with the write-avoidance tuning, these units are
    built to run continuously for years. TRIM (`fstrim.timer`) keeps NVMe write
    performance from degrading over time.

=== "End-user microSD cards"

    If you flashed AryaOS onto your own **microSD card**, media longevity is the
    variable you control. The AryaOS tuning does the heavy lifting, but the card
    itself is the weakest link:

    - Use a reputable, endurance-rated ("high endurance" / industrial) card, not
      the cheapest one on the shelf.
    - A worn or counterfeit card shows up as filesystem corruption or a box that
      won't boot. If a unit starts misbehaving after long service, suspect the
      card.
    - For a long-lived fixed installation, consider moving to an
      [NVMe/eMMC box](../purchase.md).

### Validate a newly flashed card before reboot/reset testing

Run the full HIL suite after the first boot and before any reset burn-in:

```bash
ARYAOS_SSH=pi@<box-address> ./scripts/aryaos-test/run.sh
```

The storage module rejects an SD device that reports a zero manufacturer ID,
a binary or wrong-root `cmdline.txt`, or missing/implausibly small kernel and
initramfs files. Treat any of those as a media failure: capture a support bundle
while the box is still running, do not reboot it, and replace the card. Repeated
reflashing does not rehabilitate counterfeit or failing flash.

AryaOS `2.0.16` also verifies the first-boot FAT command-line rewrite before
the initramfs continues. It writes a separate candidate, syncs and remounts the
boot filesystem, reads the candidate back byte-for-byte, then remounts and
verifies the final path; a bad write is retried on a new allocation instead of
silently leaving an unbootable appliance.

!!! note "This is why logs and swap moved off disk"
    Every one of these techniques exists to keep write traffic off the install
    media so the card outlives the deployment. It's the same philosophy as the
    rest of AryaOS: a field appliance you set down and forget.

## Related

<div class="grid cards" markdown>

- :material-briefcase-search: **Support bundles** - capture the RAM-only journal before a reboot loses it. [Support bundles](./support-bundles.md)
- :material-content-save: **Back up & restore** - persist your *configuration* off the box (config, not logs). [Back up & restore](./backup-restore.md)
- :material-cart: **Buy hardware** - the NVMe/eMMC boxes built for continuous field use. [Buy hardware](../purchase.md)

</div>
