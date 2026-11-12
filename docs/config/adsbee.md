# ADSBee radio lockdown

AryaOS detects an ADSBee 1090U and records
`ARYAOS_ADSB_1090_SOURCE=adsbee` in `/etc/aryaos/aryaos-config.txt`.
`readsb` then decodes the Mode S Beast stream from the ADSBee USB console.
This page covers the radio lockdown that runs before every `readsb` start.

## Why

A factory ADSBee is not field-safe. Stock firmware enables the Wi-Fi access
point (SSID `ADSBee1090-<serial>`, password `yummyflowers`) and marks four
public aggregator feeds active: `feed.whereplane.xyz`, `feed.adsb.lol`,
`feed.airplanes.live` and `feed.adsb.fi`. Those feeds stay dormant only while
the device has no network. Give it a network and it reports the receiver
position and traffic to the internet.

## What the lockdown does

`readsb.service` runs `/usr/local/sbin/aryaos-adsbee-lockdown` in
`ExecStartPre`, before the decoder starts. When the 1090 source is the
ADSBee, the script reads the device settings over the USB console and writes
only the settings that differ. A converged device costs one read and zero
flash writes. On every `readsb` start the lockdown sets:

- Wi-Fi access point off, Wi-Fi station off, Ethernet off
- all ten feed slots inactive with protocol `NONE`
- console log level silenced, so debug text cannot corrupt the Beast stream
- `AT+PROTOCOL_OUT=CONSOLE,BEAST` and `AT+ESP32_ENABLE=1`

## Keeping the radios on

Set `ARYAOS_ADSBEE_RADIO=on` in `/etc/aryaos/aryaos-config.txt` to keep the
ADSBee radios active. The default is `off`. The lockdown then skips the
radio settings and logs the choice on every `readsb` start. Log level,
protocol and feed slot settings still apply, since the preloaded feeds are
an OPSEC risk even when the device has no network.

## The ESP32 stays enabled

The lockdown pins `AT+ESP32_ENABLE=1` and disables each radio individually.
With `AT+ESP32_ENABLE=0`, the device still sends Beast frames over USB.

Measured on firmware 0.9.1-rc11 with the lockdown settings, in alternating
120 s windows:

- Bench signal generator at 100 frames per second: 11,953 to 11,977
  frames per window with the ESP32 disabled, and 11,952 to 11,969 with
  the ESP32 enabled. Each window received at least 99.6 percent of the
  frames.
- Live antenna: 577 to 2,250 Mode S frames per window with the ESP32
  disabled, and 1,026 to 1,513 with the ESP32 enabled.
- After `AT+SETTINGS=SAVE` and a reboot: 702 and 1,202 frames with the
  ESP32 disabled, and 2,232 frames with the ESP32 enabled.

An earlier test on firmware 0.9.0-rc19 recorded zero bytes with the ESP32
disabled. That test ran at very low traffic. At low traffic, a 120 s window
can contain zero frames with either setting.

## Feed slots keep their hostnames

Clearing a feed slot does not erase its stored hostname. The settings dump
still shows, for example, `AT+FEED=6,feed.whereplane.xyz,0,0,NONE`. That is
cosmetic. The slot reads port 0, inactive, no protocol, and it is not a
live feed. The lockdown treats the slot as satisfied and does not rewrite
it on every boot.

## Troubleshooting

**Lockdown not applied.** Check `journalctl -u readsb` for lines from
`aryaos-adsbee-lockdown`. The script fails open. On any error it logs the
reason and lets `readsb` start. Common causes are a busy console port and
a missing `ARYAOS_ADSB_1090_DEVICE` path.
