# Nearby nodes

An AryaOS fleet finds itself. Every unit quietly beacons its identity on the TAK
Mesh SA multicast group, and every unit listens for the others — so any box's
**Nearby AryaOS nodes** card shows the rest of the fleet, their roles, health,
position, and a one-click admin link. No central server, no manual inventory.

## How self-discovery works

The `aryaos-neighbord` daemon runs on each box and does two things at once on
the Mesh SA group **`239.2.3.1:6969`** (the same multicast lane Charontak uses
for Situational Awareness — see [Firewall](../networking/firewall.md)):

- **Beacon** — periodically it multicasts a small Cursor on Target (CoT) event
  describing itself: hostname, roles, health, and GPS position (from `gpsd`,
  falling back to a no-fix marker).
- **Listen** — it joins the multicast group and, for every AryaOS beacon it
  hears, records the neighbor into a local cache with the time it was last seen.

```mermaid
flowchart LR
    subgraph mesh["Mesh SA — 239.2.3.1:6969"]
      direction LR
      A[aryaos-alpha] -- beacon --> M(( ))
      B[aryaos-bravo] -- beacon --> M
      C[aryaos-charlie] -- beacon --> M
    end
    M --> A
    M --> B
    M --> C
    A --> J[/run/aryaos/neighbors.json]
    J --> Card[Nearby nodes card]
```

The cache is written to **`/run/aryaos/neighbors.json`** (world-readable,
`0644`, on tmpfs so it never persists across reboots). Entries carry a
**time-to-live of 240 seconds** — a neighbor that stops beaconing ages out of
the list, so what you see is what's currently alive on the mesh.

!!! info "It's just CoT on the SA lane"
    Because discovery rides standard CoT multicast on the same `239.2.3.1:6969`
    lane as Situational Awareness, no extra network configuration is needed:
    anywhere your Mesh SA reaches, the fleet discovers itself. That includes a
    disconnected backpack mesh with no infrastructure at all.

## The Nearby AryaOS nodes card

The **Nearby AryaOS nodes** card on **Cockpit → AryaOS Site** reads
`/run/aryaos/neighbors.json` (via the `aryaos-neighbors` CGI endpoint) and
refreshes every few seconds. Each heard node is one row:

| Column | Shows | Source |
| --- | --- | --- |
| **Node** | The neighbor's hostname (`aryaos-xxxx`), or its UID / source IP if the name is unknown. | beacon `host` |
| **Roles** | Which sensor pipelines it runs — e.g. `ADS-B / AIS / UAS`, or `base` if none. | beacon `roles` |
| **Health** | System load, memory %, CPU temperature, and active/total service count (e.g. `load 0.42 \| mem 61% \| 47 C \| 8/9 svc`). | beacon `system` / `services` |
| **Position** | Latitude, longitude — or `no fix` when GPS has no lock. | beacon `point` |
| **Seen** | How long ago the node was last heard (`12s`, `3m`, `1h`). | cache `age_s` |
| **Admin** | An **Open** link straight to that node's Cockpit, when it advertises one. | beacon `host.admin_url` |

The summary line reports how many nodes are currently heard on Mesh SA; if none
are, it shows *"Listening for AryaOS CoT beacons…"* — which usually just means
you're the only unit on the mesh right now.

!!! tip "Jump straight to a neighbor's Cockpit"
    When a node advertises its admin URL, the **Open** link in the Admin column
    takes you directly to that unit's [AryaOS Site](../admin/aryaos-site.md)
    page. That's the fast path for triaging a fleet: open one box, see the
    others, click into whichever one looks unhealthy.

## Using it to run a fleet

- **Muster check** — glance at the card to confirm every unit you deployed is up
  and beaconing. A missing node either dropped off the mesh or aged past its
  240-second TTL.
- **Triage** — the **Health** column surfaces load, memory, temperature, and
  failed services at a glance; the **Position** column tells you where each unit
  physically is. Spot the unhealthy one, click **Open**, and dig in.
- **Coverage** — because roles are shown per node, you can see at a glance that
  your air, maritime, and drone coverage are all present on the mesh.

!!! note "Discovery is read-only and low-cost"
    Beacons are tiny CoT events sent about once a minute with a multicast TTL of
    1, and the cache lives on tmpfs. Neighbor discovery doesn't move sensor data
    or reconfigure anything — it only tells you who else is out there.

## Related

<div class="grid cards" markdown>

- :material-wall-fire: **Firewall** — the Mesh SA `6969/udp` rule this rides on. [Firewall](../networking/firewall.md)
- :material-tune: **AryaOS Site** — the admin page hosting the nearby-nodes card. [AryaOS Site](../admin/aryaos-site.md)
- :material-briefcase-search: **Support bundles** — the neighbor cache is included for diagnostics. [Support bundles](support-bundles.md)
- :material-view-grid: **Operating a fleet** — the day-2 overview. [Operating a fleet](index.md)

</div>
