# Boot from NVMe

AryaOS boots from a **microSD card** by default. On hardware with an NVMe slot — the Waveshare
PoE M.2 HAT+, other M.2 HATs, or SNS-supplied boxes — you can run AryaOS from an **NVMe SSD**
instead, which is far more endurance-friendly for continuous field use (see
[Media longevity](media-longevity.md)) and noticeably faster.

Booting from NVMe is a **Raspberry Pi bootloader change**, not something the AryaOS image does
for you — the steps below are one-time, per unit.

## 1. Fit the drive

Seat an M.2 **NVMe** SSD (2230/2242/2260/2280) in the HAT. The Pi&nbsp;5 auto-detects the PCIe
link; no `config.txt` change is needed for detection. To force PCIe Gen&nbsp;3 (faster, but not
all HATs/SSDs are stable):

```
# /boot/firmware/config.txt
dtparam=pciex1_gen=3
```

The Waveshare PoE M.2 HAT+ runs at Gen&nbsp;2 by default, which is plenty for AryaOS.

## 2. Put AryaOS on the NVMe

Either flash the AryaOS `.img` directly to the NVMe from another machine, or clone a running
SD install to the NVMe on the box:

```bash
lsblk                              # confirm the NVMe is /dev/nvme0n1
# Option A — clone the running SD card to NVMe:
sudo rpi-clone nvme0n1             # if rpi-clone is available
# Option B — write a downloaded image (see the OS image backup card in Cockpit):
sudo sh -c 'xzcat /var/lib/aryaos/image/*.img.xz > /dev/nvme0n1'
```

`findmnt /` afterwards should still show the SD root until you change the boot order.

## 3. Set the boot order to prefer NVMe

Edit the bootloader EEPROM config and set `BOOT_ORDER` so the Pi tries NVMe first, then SD:

```bash
sudo rpi-eeprom-config --edit
```

```
BOOT_ORDER=0xf416
```

Boot-order digits are read right-to-left: `6`=NVMe, `1`=SD, `4`=USB, `f`=retry. `0xf416` means
**NVMe → SD → USB → repeat**, so a box with no NVMe still falls back to the SD card. Reboot.

## 4. Verify

```bash
findmnt /                          # root should now be /dev/nvme0n1p2
rpi-eeprom-config | grep BOOT_ORDER
```

!!! warning "Power headroom"
    NVMe adds roughly **2–4&nbsp;W** on the PCIe link. On a marginal supply — a 5V/3A brick, or
    a PoE HAT fed from plain **802.3af** — adding NVMe (plus SDRs) can tip the box into a
    brownout. Pair NVMe boot with a proper **5V/5A (27&nbsp;W)** supply or a true **PoE+
    (802.3at)** source. AryaOS surfaces under-voltage via power-health and falls back to
    [safe mode](../get-started/hardware.md#safe-mode) if it crash-loops. See
    [Hardware & requirements](../get-started/hardware.md#power--battery-for-backpack-ops).

## See also

- [Media longevity](media-longevity.md) — why NVMe/eMMC beats SD for continuous use
- [OS image backup](backup-restore.md) — pulling the unit's own `.img` to re-flash
