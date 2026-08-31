# DHCP-less Ethernet and MANET fallback

AryaOS can remain reachable and publish Mesh SA when Ethernet has carrier but
the attached MANET has no DHCP server. The optional **MANET fallback (IPv4LL)**
feature uses NetworkManager's RFC 3927 link-local mode alongside DHCP:

- DHCP remains enabled and supplies the normal routed address when available.
- NetworkManager also assigns a collision-checked `169.254.x.x/16` address, so
  management and Mesh SA do not wait for repeated DHCP timeouts.
- When DHCP succeeds, both addresses coexist. AryaOS prefers the DHCP address
  for multicast output on that interface, avoiding duplicate Mesh SA events.
- Ethernet also keeps IPv6 link-local enabled. This gives NetworkManager a
  completed address family immediately, so DHCP can continue in the background
  without disconnect/retry cycles. It does not create routed IPv6 connectivity.
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
Profiles without an operator-selected firewall zone are assigned to `public`,
the normal AryaOS wired-LAN zone, so SSH, HTTPS, and Mesh SA remain reachable
over IPv4LL.

At boot, `aryaos-ipv4ll-apply.service` reconciles NetworkManager profiles that
were created after package installation. It immediately reapplies only changed,
active DHCP Ethernet profiles before `network-online.target`. This closes the
first-boot gap without reconnecting a live session when an operator changes the
setting later.

## Discover and use a DHCP-less device

The other MANET peer also needs an IPv4LL address. Once both ends have one, use
`aryaos-xxxx.local` through mDNS or inspect the AryaOS/LINCOT SA beacon on
`239.2.3.1:6969`. The web portal, Cockpit, SSH, Gutcheck, and Mesh SA retain the
normal wired-LAN firewall policy.

AryaOS resolves all active physical Ethernet and Wi-Fi addresses, plus `pan0`,
into `/run/aryaos/multicast.env`. COTBridge then sends each Mesh SA event once
on every resolved link. Container bridges, VPNs, tunnels, and trusted sensor
links are excluded. NetworkManager's dispatcher refreshes the list and restarts
multicast consumers whenever a link gains or loses an address, including after
a link assigns IPv4LL. The resolver's idempotent oneshot has no systemd start
limit because one NetworkManager transition can legitimately emit several
dispatcher events. Losing one link does not stop the remaining outputs.

AryaOS also defines `network-online.target` as any usable NetworkManager
connection rather than waiting for every optional DHCP attempt to settle. This
keeps offline boots healthy while Ethernet continues accepting a later lease.

For an advanced fixed selection, set a comma-separated list instead of `auto`:

```ini
PYTAK_MULTICAST_LOCAL_ADDRS=10.41.0.1,169.254.28.4
```

`PYTAK_MULTICAST_LOCAL_ADDR=0.0.0.0` does not mean fanout: it lets Linux select
one route. Use the plural setting for deterministic multi-link multicast.
