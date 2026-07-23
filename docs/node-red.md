# Node-RED

AryaOS ships [Node-RED](https://nodered.org/) as an **optional** low-code
automation surface — it is **not required for any AryaOS functionality**. It
boots with **empty flows** and is **not the admin surface** (that's Cockpit).

## Accessing it

Node-RED binds **loopback only** and is served behind the box's HTTPS reverse
proxy — the flow editor is at **`https://<host>/nr/`** (accept the self-signed
cert). It is **not** reachable on `:1880` over the LAN; the public firewall zone
no longer opens the Node-RED port, so the editor (which can run code on the
device) is not exposed as walk-up attack surface. For remote access, reach
`/nr/` over the [VPN](networking/vpn-tailscale.md).

!!! warning "Set a strong Node-RED admin password before fielding a unit"
    The editor can run code on the device. Set a unique password from **AryaOS
    Site → Node-RED admin password** (see [AryaOS Site](admin/aryaos-site.md)) or
    with `sudo aryaos-set-nodered-password`.

## Optional legacy flows

The previous AryaOS demo flows (dashboard, Mesh SA map, TFR/recorder helpers)
are **no longer loaded by default**. The bundle still ships at
`/home/node-red/.node-red/aryaos_flows.json` — import it by hand from the editor
(**Menu → Import**) if you want those flows.

## Node-RED is not the admin surface

Earlier AryaOS builds used Node-RED to edit configuration. That role has moved
entirely to the [web console](admin/index.md) — Node-RED is now for
visualization and custom automation only. Configure the system here instead:

| Need | Where |
|------|-------|
| Site TAK destination, TLS, role, updates | [AryaOS Site page](admin/aryaos-site.md) |
| Where CoT flows (Mesh SA / TAK Server) | [Charontak lane editor](admin/charontak-lanes.md) |
| Per-sensor settings | [Gateway pages](admin/gateways.md) → `/etc/default/<svc>` |
| SDR serials & decoder | [Radios & SDRs](config/radios-sdr.md) |
| Wi-Fi / hotspot | [Wi-Fi & onboarding hotspot](networking/wifi-hotspot.md) |
| Services (start/stop/restart) | Cockpit → Services, or each gateway page |

## Security

- The **`node-red`** user is **not** in the `sudo` group and has no passwordless
  `sudo` rules (see `/etc/sudoers.d/aryaos`).
- Node-RED owns only its own configuration, not the AryaOS TLS material.
- Flows are provisioned at build time from
  [`shared_files/node-red/`](https://github.com/snstac/aryaos/tree/main/shared_files/node-red);
  Node-RED loads `flows.json` on restart: `sudo systemctl restart nodered`.

See the [security posture](security.md) for the full picture.
