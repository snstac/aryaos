# Firewall (firewalld)

AryaOS runs [firewalld](https://firewalld.org/) with an explicit inbound
**allowlist**: only the ports a field unit actually serves are open, and
everything else inbound is rejected. This page enumerates what's allowed by
default, how to manage it in Cockpit, and how to open something new.

## The default-zone allowlist

The default zone is **`AryaOS`** (`/etc/firewalld/zones/public.xml`). It permits
exactly the services below and rejects all other inbound traffic. Loopback is
implicitly accepted by firewalld.

| Service | Port(s) | Purpose |
| --- | --- | --- |
| `ssh` | 22/tcp | SSH administration (sshd hardened - see [Security](../security.md)). |
| `http` | 80/tcp | Web portal (lighttpd) and Cockpit proxy. |
| `https` | 443/tcp | TLS portal. Lighttpd terminates TLS and proxies `/admin` to Cockpit. |
| `mdns` | 5353/udp | mDNS/ZeroConf so the box is findable as `aryaos-xxxx.local`. |
| `dhcp` | 67/udp | DHCP leases - served only while the comitup hotspot runs. also leases [Bluetooth PAN](../bluetooth-pan.md) clients. |
| `dhcpv6-client` | 546/udp | DHCPv6 client. |
| `dns` | 53/tcp+udp | DNS - answered only while the comitup onboarding hotspot is up (dnsmasq is not otherwise active). |
| `aryaos-mesh-sa` | 6969/udp | TAK **Mesh SA** multicast - COTBridge and GutCheck CoT discovery on `239.2.3.1:6969`. |
| `aryaos-gutcheck-discovery` | 1900/udp | Identity-only GutCheck SSDP discovery on each local link. |
| `aryaos-gutcheck` | 8181/tcp | Token-protected GutCheck health dashboard/API on trusted links. |
| `aryaos-ais-catcher` | 8100/tcp | AIS-catcher live map / statistics dashboard. |
| `aryaos-comitup` | 9080/tcp | Comitup captive Wi-Fi onboarding portal (listens only in hotspot mode). |

!!! info "Custom `aryaos-*` service definitions"
    AryaOS-specific firewalld *services* are defined in
    `/etc/firewalld/services/aryaos-*.xml`
    (`aryaos-mesh-sa`, `aryaos-gutcheck-discovery`, `aryaos-gutcheck`,
    `aryaos-ais-catcher`, `aryaos-comitup`). Bundling ports into named services keeps the zone
    readable and lets you toggle a whole capability at once.

!!! note "Some ports only answer sometimes"
    `dhcp`, `dhcpv6-client`, and `dns` exist for onboarding: they are answered
    while the [comitup hotspot](wifi-hotspot.md) is running (and DHCP also
    leases Bluetooth PAN clients). The `9080` onboarding portal likewise only
    listens in hotspot mode. Opening the port in the zone does not mean a service
    is always behind it.

## Onboarding radios are isolated from the wired network

The `AryaOS` zone deliberately ships with **no intra-zone forwarding**. This
device is an appliance, not a router. A hotspot or
[Bluetooth PAN](../bluetooth-pan.md) client can reach the allowlisted services.
The firewall never routes that client to the upstream network.

Because the rule is enforced in the firewall's `FORWARD` path, it holds **even
When `net.ipv4.ip_forward` is enabled** on the host - which happens whenever
Docker is running. Without this, a hotspot client can otherwise be routed
straight onto the wired LAN. Docker's own container networking is unaffected (it
lives in a separate `docker` zone with its own forwarding rules).

To silence the radios entirely, see [EMCON & radio control](emcon.md).

For the canonical port/protocol reference across the whole system, see
[Ports & protocols](../reference/ports.md).

## The AntSDR trusted-zone note

Firewalld places the AntSDR point-to-point link in the **`trusted`** zone. The
drone sensor can then reach the `dronecot-dji` listener over its dedicated
cable. You do not need to open the field-facing allowlist. This is a private
sensor link, not a general network - treat the `trusted` zone as reserved for
it.

!!! info "Docker-published ports are separate"
    Ports published by Docker containers (for example a UAS broker)
    are governed by Docker's own firewalld integration, not the `AryaOS` zone.
    Manage those where the container is defined.

## Manage the firewall in Cockpit

Everything is editable from the browser - no shell needed.

1. Open **Cockpit > Networking > Firewall**.
2. The active zone (`AryaOS`) lists its allowed services. Toggle a service off
   to close its ports, or on to reopen them.
3. Add a service (below) to open a new capability.

!!! tip "Cockpit shows the same picture as `firewall-cmd`"
    Under the hood Cockpit drives firewalld. If you prefer the shell,
    `sudo firewall-cmd --list-all` shows the active zone and its services, and
    `sudo firewall-cmd --get-services` lists every defined service you can add.

## Add a service

Say you want to expose a new dashboard on TCP `8200`.

=== "In Cockpit"

    1. Open **Cockpit > Networking > Firewall**.
    2. Click **Add services** on the `AryaOS` zone.
    3. Pick a predefined service, or choose **Custom ports** and enter
       `8200/tcp`.
    4. Apply. The rule persists across reboots.

=== "Define a reusable service"

    Create a service definition so it shows up by name and survives upgrades,
    matching the AryaOS convention:

    ```xml title="/etc/firewalld/services/aryaos-mydash.xml"
    <?xml version="1.0" encoding="utf-8"?>
    <service>
      <short>My dashboard</short>
      <description>Example custom AryaOS dashboard.</description>
      <port protocol="tcp" port="8200"/>
    </service>
    ```

    Then load and enable it in the default zone:

    ```bash
    sudo firewall-cmd --reload
    sudo firewall-cmd --permanent --zone=AryaOS --add-service=aryaos-mydash
    sudo firewall-cmd --reload
    ```

!!! warning "Open only what you serve"
    The allowlist model is the point of the firewall. Every port you open is
    attack surface on a device that can sit on a hostile LAN. Close services you
    do not use. Reach internal tools through the [VPN](vpn-tailscale.md) or
    [Bluetooth PAN](../bluetooth-pan.md) instead of opening a public port.

## Related

<div class="grid cards" markdown>

- :material-lan: **Ports & protocols** - the full port reference. [Ports & protocols](../reference/ports.md)
- :material-shield-lock: **Security posture** - sshd, fail2ban, sysctl, TLS. [Security posture](../security.md)
- :material-wifi: **Wi-Fi & onboarding** - why `9080`/DHCP/DNS come and go. [Wi-Fi & onboarding hotspot](wifi-hotspot.md)
- :material-access-point-network: **Nearby nodes** - the Mesh SA `6969/udp` traffic. [Nearby nodes](../operations/neighbors.md)

</div>
