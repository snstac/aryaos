# Ports & protocols

Every port, multicast group, and network address AryaOS uses, and what each is for. Use this when configuring a firewall, troubleshooting connectivity, or reaching a service directly.

!!! info "Most services are localhost or firewalled by default"
    AryaOS runs a `firewalld` default-zone allowlist. Ports below that face the network (Cockpit, the portal, Node-RED, AIS-catcher, Mesh SA, comitup, SSH) are opened by explicit firewalld services; the rest bind to `127.0.0.1`. Manage the allowlist in **Cockpit → Networking → Firewall**. See [Firewall](../networking/firewall.md).

## Listening ports

| Port | Proto | Service | Purpose |
|---|---|---|---|
| 22 | TCP | SSH (`sshd`) | Optional remote shell. Hardened: no root login, `MaxAuthTries 4`, `fail2ban`. |
| 443 | TCP | Portal / proxy (`lighttpd`) | HTTPS portal; proxies `/admin` to Cockpit. Per-device TLS certificate. |
| 1880 | TCP | Node-RED | Low-code editor and dashboards. Admin API is password-protected via `adminAuth`. |
| 4000 | UDP | GDL90 (`gdltak`) | CoT-to-GDL90 output for ForeFlight / EFBs. Default destination port. |
| 4349 | TCP | GPSTAK | Default GPSTAK network-GPS / NMEA fan-out port. |
| 8100 | TCP | AIS-catcher web | AIS-catcher live map and statistics dashboard. |
| 9080 | TCP | Comitup portal | Captive Wi-Fi-onboarding web UI. Only listens while in hotspot mode. |
| 9090 | TCP | Cockpit | The web admin surface (HTTPS). Also reachable via the 443 portal proxy at `/admin`. |
| 28087 | UDP | CharonTAK hub | Local CoT hub. Feeders write `udp+wo://127.0.0.1:28087`; CharonTAK reads `udp+ro://127.0.0.1:28087`. **Localhost only.** |

!!! note "Standard infrastructure ports"
    AryaOS also uses the usual system services allowed by firewalld: mDNS (5353/udp, for `aryaos-xxxx.local`), DHCP, and DNS on the hotspot and PAN interfaces.

## Multicast groups

| Group | Port | Proto | Purpose |
|---|---|---|---|
| `239.2.3.1` | 6969 | UDP | **TAK Mesh SA** — CharonTAK egress/ingress and `aryaos-neighbord` neighbor discovery. `udp+wo://239.2.3.1:6969`. |

Multicast source binding is controlled by `PYTAK_MULTICAST_LOCAL_ADDR` in the site config (default `10.41.0.1`, the hotspot IP). See [Relay & routing](../deploy/relay-routing.md) and [Nearby nodes](../operations/neighbors.md).

## Network addresses

| Interface | Address | Purpose |
|---|---|---|
| Wi-Fi hotspot (`wlan0`) | `10.41.0.1/24` | Onboarding/AP network `AryaOS-xxxx`. Phones and laptops get DHCP here; this is the default multicast bind address. |
| Bluetooth PAN (`pan0`) | `10.44.0.1/24` | Local Bluetooth NAP. AryaOS serves DHCP (`10.44.0.20`–`10.44.0.60`) to paired phones. **No NAT or forwarding** — for reaching AryaOS services over Bluetooth. |

See [Wi-Fi & onboarding hotspot](../networking/wifi-hotspot.md) and [Bluetooth PAN](../bluetooth-pan.md).

## Egress (outbound)

AryaOS forwards CoT outward through CharonTAK:

| Destination | URL | When |
|---|---|---|
| Mesh SA multicast | `udp+wo://239.2.3.1:6969` | Default — phones on the hotspot see tracks with no server |
| TAK Server | `tls://host:port` (or `tcp://`) | When a TAK connection is imported |

TAK Server lanes are added by importing a connection data package or `tak://` enrollment link — see [Connect to a TAK Server](../deploy/connect-tak-server.md).

## See also

<div class="grid cards" markdown>

- :material-security: **Firewall** — Manage the allowlist. [Firewall](../networking/firewall.md)
- :material-book-open: **Glossary** — What these protocols are. [Glossary](glossary.md)
- :material-package: **Software suite** — The services behind each port. [Software suite](software-suite.md)

</div>
