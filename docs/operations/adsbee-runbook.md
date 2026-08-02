# Runbook — fitting an ADSBee to a unit

Operational procedure for swapping a unit's ADS-B RTL-SDR dongles for an
[ADSBee 1090U](../config/adsbee.md). Written for a technician with SSH or
console access to the box.

Budget about ten minutes, most of it waiting for aircraft.

## Before you start

- An **ADSBee 1090U** and a **data-capable** USB cable. A charge-only cable
  enumerates nothing and looks exactly like a dead device.
- Antennas for **both** bands if you want UAT: the 1090 and sub-GHz ports are
  separate, and antennas are sold separately.
- An AryaOS image containing `aryaos-adsbee` (check with
  `command -v aryaos-adsbee`). Older images will simply ignore the device.

!!! warning "Quiet the radios first on a marginal supply"
    On a Pi 5, or any unit on a questionable supply or cable, shed load before
    changing hardware — a brownout *during a write* can corrupt config:
    ```bash
    sudo aryaos-safe-mode on "fitting adsbee"
    #   ... do the work ...
    sudo aryaos-safe-mode off
    ```

## Procedure

**1. Fit the hardware.** Power down, remove the 1090 and 978 RTL dongles,
connect the ADSBee and its antenna(s), power up.

**2. Confirm it was found.**

```bash
sudo aryaos-adsbee info
```

Expect `"present": true` with a firmware version and part code. If it reports
nothing, see *Failure modes* below.

**3. Confirm readsb is driving it.**

```bash
ps -o args= -C readsb | head -1
```

Expect `--device-type modesbeast --beast-serial /dev/serial/by-id/usb-Raspberry_Pi_Pico_...`.

`/etc/default/readsb` will still contain the old RTL line. **That is correct and
deliberate** — the switch happens at runtime, so pulling the ADSBee returns the
unit to its SDR configuration with no edit required. Do not "fix" it.

**4. Enable the capability** (if not already):

```bash
sudo aryaos-role caps adsb
```

`dump978-fa` should be listed as `disable`. The ADSBee covers 978 UAT itself, and
dump978-fa would only crash-loop hunting a dongle that is no longer fitted.

**5. Confirm aircraft, then CoT.**

```bash
jq '.aircraft | length' /run/adsb/aircraft.json
sudo journalctl -u adsbcot -n 5      # "Retrieved N ADS-B aircraft messages."
```

Give it a few minutes. Traffic is genuinely intermittent, and a quiet sky is the
most common cause of a "failed" verification.

**6. Record the numbers.** For comparison against the unit's old RTL baseline:

```bash
ps -o time,%cpu -C readsb --no-headers   # expect ~0% and near-zero CPU time
vcgencmd measure_temp; vcgencmd get_throttled
```

## Acceptance checklist

- [ ] `aryaos-adsbee info` reports `present: true`
- [ ] `readsb` running with `--device-type modesbeast`
- [ ] `dump978-fa` inactive, and **not** crash-looping
- [ ] `systemctl --failed` is empty
- [ ] `aircraft.json` gains aircraft within a few minutes
- [ ] `adsbcot` logging retrievals; CoT visible on the mesh
- [ ] `readsb` CPU at or near 0%
- [ ] `get_throttled` is `0x0`

## Verifying the emissions posture

A factory ADSBee runs a Wi-Fi AP and carries four active public aggregator
feeds. Provisioning disables these on every boot; verify on any unit going to the
field:

```bash
sudo systemctl stop readsb        # the console is one port; readsb holds it
sudo aryaos-adsbee provision      # expect "configuration already correct"
sudo systemctl start readsb
```

To inspect directly, stop `readsb` and query the device — every `FEED` line must
end `,0,0,NONE`, and `WIFI_AP`/`WIFI_STA`/`ETHERNET` must all be `0`. Disabled
feed slots still *display* their original hostnames; that is cosmetic, the
`0,0,NONE` is what matters.

`ESP32_ENABLE` must be **1**. Setting it to 0 silences the device completely,
Beast over USB included — see [the ADSBee page](../config/adsbee.md).

## Failure modes

| Symptom | Cause | Action |
|---|---|---|
| `aryaos-adsbee info` finds nothing | Charge-only USB cable | Swap for a data cable |
| | `readsb` holds the port | `systemctl stop readsb`, re-probe |
| | Not an ADSBee (some other RP2040 board) | Probe replies only from ADSBee firmware |
| Found, but readsb still on `rtlsdr` | `ARYAOS_ADSB_RECEIVER` pinned | Set to `auto`, or run `readsb-use-adsbee.sh` |
| readsb runs, no aircraft ever | Antenna / sparse traffic | Listen on the port for `1a 32`/`1a 33` markers |
| No UAT (`adsr_icao`) aircraft | No 978 antenna fitted | Fit one; UAT is sparser than 1090 |
| `dump978-fa` crash-looping | Capability set stale | Re-run `sudo aryaos-role caps adsb` |
| Device went silent after config | ESP32 was disabled | `sudo aryaos-adsbee provision` re-pins it on |

## Rolling back

Unplug the ADSBee, refit the RTL dongles, reboot. `run_readsb.sh` finds no
ADSBee, falls through to the untouched `RECEIVER_OPTIONS` in
`/etc/default/readsb`, and `aryaos-role caps adsb` restores `dump978-fa`. No
configuration edit is needed in either direction.
