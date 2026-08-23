# Nearby nodes

AryaOS uses **GutCheck Discovery** to find nearby AryaOS systems without a
central server or a preconfigured address. Discovery works on ordinary LANs,
isolated Layer-2 MANETs, the onboarding hotspot, and Bluetooth PAN links.

## Discovery transports

GutCheck combines three complementary transports:

- **CoT Mesh SA** on `239.2.3.1:6969` carries the rich operational record:
  callsign, position, service state, capabilities, timing, and host remarks.
  LINCOT is the preferred host beacon. If LINCOT has not emitted recently,
  GutCheck sends a no-position fallback and never overwrites a newer LINCOT fix.
- **DNS-SD/mDNS** advertises `_aryaos._tcp.local.` and the HTTPS landing/admin
  URLs. It makes the appliance browsable by hostname on a local link.
- **SSDP** on `239.255.255.250:1900` supplies an additional Layer-2 discovery
  path for MANET software that does not browse DNS-SD.

DNS-SD and SSDP publish identity and service URLs only. They do not expose
position, health, capabilities, or credentials. Rich status remains on CoT and
the token-protected GutCheck API.

```mermaid
flowchart LR
    A[AryaOS A] -->|CoT 6969| G((local links))
    A -->|mDNS 5353| G
    A -->|SSDP 1900| G
    G --> B[AryaOS B / discovery client]
    B --> C[/run/gutcheck/neighbors.json]
    C --> D[Nearby nodes card]
```

## DHCP-less Ethernet

Multicast applications still need an IPv4 address to select an interface.
When Ethernet is connected to a MANET with no DHCP server, AryaOS's optional
RFC 3927 fallback gives the interface a `169.254.0.0/16` address. GutCheck then
binds CoT, mDNS, and SSDP to that link. The feature is enabled by default and is
controlled with:

```bash
sudo aryaos-ipv4ll enable
sudo aryaos-ipv4ll disable
```

See [DHCP-less MANET fallback](../networking/manet-ipv4ll.md).

## Cache and portal

GutCheck writes `/run/gutcheck/neighbors.json` atomically with mode `0644`.
Entries expire after 240 seconds. The `aryaos-neighbors` CGI preserves the
existing portal JSON contract, so the **Nearby AryaOS nodes** card continues to
show hostname, roles, health, position, last-seen age, and an admin link.

The discovery service is `gutcheck.service`; the retired
`aryaos-neighbord.service` is stopped and removed during an AryaOS overlay
upgrade.

## Troubleshooting

```bash
systemctl status gutcheck
journalctl -u gutcheck --since -10min
cat /run/gutcheck/neighbors.json
ip -4 -brief address
```

If a cable has carrier but no IPv4 address, verify IPv4LL is enabled. If CoT is
missing but identity discovery works, verify UDP 6969 and the site multicast
configuration. If SSDP is missing, verify UDP 1900 is allowed by firewalld.

## Related

- [Firewall](../networking/firewall.md)
- [Ports and protocols](../reference/ports.md)
- [AryaOS Site](../admin/aryaos-site.md)
