# Network SDR sharing

AryaOS can serve an onboard SDR **raw over the network** so a remote operator can
tune and demodulate it from a desktop client (SDR++, SDRangel, GQRX, SDR#,
`dump1090`, …) instead of decoding it on the box. A dongle can only do one job at
a time, so sharing a dongle **stops its decoder** first.

!!! danger "Raw SDR sharing is unauthenticated — opt-in only"
    Both servers below give any client that can reach the port **full control of
    the dongle** (tuning + raw IQ). They are **off by default**, and the firewall
    does **not** open their ports on any zone. Enable a share only on a **trusted
    or VPN** network — open the firewall service deliberately, or bind the server
    to your [VPN](../networking/vpn-tailscale.md) address (`AOS_RTLTCP_BIND` /
    `AOS_SOAPY_BIND`). Turn it back off when you're done.

## Servers

| Server | Devices | Client connects as | Port |
|---|---|---|---|
| **rtl_tcp** | RTL-SDR only (per dongle) | `rtl_tcp` host:port (SDR#, GQRX, dump1090…) | `1234 + index` |
| **SoapyRemote** | any SoapySDR device (RTL / LimeSDR / Airspy / HackRF) | `driver=remote,remote=<host>` (SDR++, SDRangel) | `55132` |

## Sharing a dongle

```bash
aryaos-sdr list                         # find the dongle index
sudo aryaos-sdr share 0 rtltcp          # RTL-SDR 0 over rtl_tcp on :1234
sudo aryaos-sdr share 0 soapy           # all SoapySDR devices over SoapyRemote :55132
sudo aryaos-sdr share 0 off             # stop sharing (then re-apply a role to decode)
aryaos-sdr share-status                 # JSON: which share servers are running
```

Resume normal decoding after sharing with `sudo aryaos-role set <role>`.

## Opening access (deliberately)

The share ports are closed by default. To reach a share, either **bind to the VPN**:

```bash
# rtl_tcp bound to the Tailscale address only:
sudo systemctl edit aryaos-rtltcp@0     # add: [Service]\nEnvironment=AOS_RTLTCP_BIND=100.x.y.z
```

…or **open the firewall service on a trusted zone** (the definitions ship but are
attached to no zone):

```bash
sudo firewall-cmd --zone=public --add-service=aryaos-rtltcp        # or aryaos-soapyremote
# make permanent only if you really want it always-on:
sudo firewall-cmd --permanent --zone=public --add-service=aryaos-rtltcp
```

## See also

- [Radios & SDRs](radios-sdr.md) — SDR serials and decoder assignment
- [SIGINT / wideband (LimeSDR)](../deploy/sigint-limesdr.md) — the dragonegg laydown
- [VPN (Tailscale)](../networking/vpn-tailscale.md) — the recommended path for remote SDR access
