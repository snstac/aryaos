# Bluetooth PAN

AryaOS can expose a local IP link over Bluetooth by acting as a BlueZ Network
Access Point (NAP). This is intended for phone-to-box management and TAK data
paths when Wi-Fi or Ethernet is not available.

Default link behavior:

- AryaOS creates `pan0` at `10.44.0.1/24`.
- Paired clients receive DHCP leases from `10.44.0.20` to `10.44.0.60`.
- No IP forwarding, NAT, or internet egress is enabled.
- Phones should reach local services at `10.44.0.1`, for example Cockpit on
  `https://10.44.0.1:9090/`.

Configuration lives in `/etc/aryaos/aryaos-config.txt`:

```ini
BT_PAN_ENABLED=1
BT_PAN_BRIDGE=pan0
BT_PAN_ADDRESS=10.44.0.1
BT_PAN_PREFIX=24
BT_PAN_DHCP_START=10.44.0.20
BT_PAN_DHCP_END=10.44.0.60
BT_PAN_DHCP_LEASE=12h
```

The systemd service is `aryaos-bt-pan.service`. It keeps the BlueZ
`NetworkServer1` registration alive and runs a foreground `dnsmasq` DHCP server
bound only to the PAN bridge.

Pair the phone with AryaOS over Bluetooth, then select the paired AryaOS device
as a Bluetooth network/PAN device on the phone if the phone OS exposes that
option. Android support varies by vendor. iOS is generally less flexible for
arbitrary Bluetooth PAN client use.
