# Install media longevity

AryaOS runs from flash: a microSD card, eMMC, or an NVMe SSD. Flash media wears
out by *writing* — every block has a finite number of program/erase cycles, and
a chatty Linux install (swap, logs, atime updates) can burn through a cheap SD
card in a single fire season. AryaOS is tuned from the factory to write to the
install media as little as possible, so a fielded box survives.

There is **nothing to configure** — the tuning below is on by default in every
image.

## What AryaOS does by default

| Technique | What it saves |
| --- | --- |
| **`dphys-swapfile` disabled + zram swap** | No swapfile writes ever hit the SD/NVMe. Swap lives in RAM instead (`zstd`-compressed, sized `min(ram / 2, 4096)` MB), so a memory spike from multi-SDR + Node-RED + containers still can't OOM-kill a service — and it costs zero media writes. |
| **journald volatile (logs in RAM)** | The systemd journal is stored in RAM, not on disk, so the constant log churn from a running sensor stack never touches the media. |
| **tmpfs for `/tmp`, `/var/tmp`, `/var/log`** | These write-heavy directories are RAM-backed tmpfs mounts (`/tmp` and `/var/tmp` capped at 100 MB, `/var/log` at 50 MB). Scratch files and logs live and die in memory. |
| **`noatime` on the root filesystem** | Reading a file no longer triggers a metadata *write* to update its access time — a huge, invisible source of wear on a busy box. |
| **Weekly `fstrim` (TRIM)** | `fstrim.timer` is enabled, so the filesystem periodically tells the flash controller which blocks are free. That keeps wear-leveling effective and sustains write performance over the life of the card. |

!!! info "zram is swap in RAM, not on disk"
    `dphys-swapfile` is disabled at build time; the AryaOS
    `zram-generator.conf` overlay replaces it with a compressed RAM swap device
    (`zram0`, priority 100). The box tolerates memory spikes without an
    OOM-kill, and without a single write to the install media. See the source
    tuning in `stages/stage-adsbcot/00-sys-tweaks/00-run-chroot.sh`.

## The tradeoff: logs live in RAM

Because the journal and `/var/log` are RAM-backed, **logs do not survive a
reboot.** That is a deliberate wear tradeoff: it spares the media from the
single biggest source of write traffic on an appliance, at the cost of
persistent on-disk history.

!!! tip "Capture logs before they're gone"
    If you need the logs from a misbehaving unit, grab them *while the problem
    is happening* — generate a [support bundle](./support-bundles.md), which
    snapshots the current journal into a redacted tarball you can attach to a
    field report. A reboot clears the RAM journal, so fresh is always better.

## NVMe vs SD cards

The tuning above applies to every AryaOS box regardless of media, but the media
itself matters:

=== "SNS-supplied boxes (NVMe/eMMC)"

    The hardware Sensors & Signals sells runs from **NVMe SSD or eMMC** —
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

!!! note "This is why logs and swap moved off disk"
    Every one of these techniques exists to keep write traffic off the install
    media so the card outlives the deployment. It's the same philosophy as the
    rest of AryaOS: a field appliance you set down and forget.

## Related

<div class="grid cards" markdown>

- :material-briefcase-search: **Support bundles** — capture the RAM-only journal before a reboot loses it. [Support bundles](./support-bundles.md)
- :material-content-save: **Back up & restore** — persist your *configuration* off the box (config, not logs). [Back up & restore](./backup-restore.md)
- :material-cart: **Buy hardware** — the NVMe/eMMC boxes built for continuous field use. [Buy hardware](../purchase.md)

</div>
