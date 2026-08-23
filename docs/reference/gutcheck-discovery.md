# GutCheck Discovery v1

GutCheck Discovery is AryaOS's tactical local-link discovery contract. Its
layered shape is informed by military service-discovery requirements, including
the kinds of capabilities described around NATO/STANAG 4817, but version 1 is
an AryaOS protocol and makes **no STANAG conformance claim**.

## Identity document

`GET /.well-known/gutcheck` is unauthenticated and returns only:

- schema and protocol version;
- a stable opaque UUID derived from (but not revealing) the machine ID;
- product name, hostname, and `.local` FQDN;
- discovery, landing-page, and admin service URLs.

It deliberately excludes location, health, roles, sensor capabilities,
interface inventory, credentials, and TAK destinations. GutCheck's operational
API on port 8181 remains bearer-token protected.

## Transports

| Transport | Contract | Purpose |
| --- | --- | --- |
| CoT | `239.2.3.1:6969`, `<detail><__aryaos>` | Rich trusted-operation status and position. |
| DNS-SD | `_aryaos._tcp.local.`, mDNS UDP 5353 | Browse identity and HTTPS service location. |
| SSDP | `urn:snstac-com:service:gutcheck:1`, UDP 1900 | Broad L2 identity discovery and active search. |

SSDP responses are rate-limited per source. Parsers reject oversized,
ambiguous, duplicate-header, and malformed datagrams. CoT XML rejects DTD and
entity declarations before parsing.

All three transports bind to each active, multicast-capable IPv4 interface.
On a DHCP-less Ethernet MANET, the [IPv4LL fallback](../networking/manet-ipv4ll.md)
provides the address needed to join multicast groups.

## Source precedence

The same opaque discovery ID joins CoT, DNS-SD, and SSDP observations into one
node. DNS-SD/SSDP may refresh network presence and service URLs, but may not
refresh or replace CoT-derived health and position. LINCOT is the preferred
AryaOS self beacon; GutCheck emits a no-fix CoT fallback only after LINCOT is
stale.
