# DHCP-less Ethernet and MANET fallback

AryaOS can remain reachable and publish Mesh SA when Ethernet has carrier but
the attached MANET has no DHCP server. The optional **MANET fallback (IPv4LL)**
feature uses NetworkManager's RFC 3927 fallback mode:

- DHCP remains the first choice.
- If no IPv4 address is obtained, NetworkManager assigns a collision-checked
  `169.254.x.x/16` address.
- If DHCP later succeeds, NetworkManager removes the fallback address.
- No routing, NAT, or bridge is created between Ethernet, Wi-Fi, and Bluetooth.

The feature is enabled by default. Control it in **Cockpit > AryaOS Site >
MANET fallback (IPv4LL)** or with:

```bash
aryaos-ipv4ll status
sudo aryaos-ipv4ll enable
sudo aryaos-ipv4ll disable
```

Enable and disable update ordinary DHCP Ethernet profiles but deliberately do
not reconnect them. The new state applies when Ethernet next activates or the
device reboots, preventing a web or SSH management session from being dropped.
Static-address profiles and the dedicated AntSDR link are never changed.

## Discover and use a DHCP-less device

The other MANET peer also needs an IPv4LL address. Once both ends have one, use
`aryaos-xxxx.local` through mDNS or inspect the AryaOS/LINCOT SA beacon on
`239.2.3.1:6969`. The web portal, Cockpit, SSH, Gutcheck, and Mesh SA retain the
normal wired-LAN firewall policy.

AryaOS resolves all active physical Ethernet and Wi-Fi addresses, plus `pan0`,
into `/run/aryaos/multicast.env`. COTBridge then sends each Mesh SA event once
on every resolved link. Container bridges, VPNs, tunnels, and trusted sensor
links are excluded. Losing one link does not stop the remaining outputs.

For an advanced fixed selection, set a comma-separated list instead of `auto`:

```ini
PYTAK_MULTICAST_LOCAL_ADDRS=10.41.0.1,169.254.28.4
```

`PYTAK_MULTICAST_LOCAL_ADDR=0.0.0.0` does not mean fanout: it lets Linux select
one route. Use the plural setting for deterministic multi-link multicast.
