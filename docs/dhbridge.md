# DroneHone Bluetooth sensor bridge (dhbridge)

AryaOS can emulate an **external DroneHone Bluetooth sensor** so ATAK phones running the [DroneHone](https://github.com/) plugin receive Remote ID detections without a separate DroneScout handheld.

## Upstream project

Application source and releases: **[github.com/snstac/dhbridge](https://github.com/snstac/dhbridge)**.

AryaOS installs the **`dhbridge`** `.deb` from [`shared_files/dhbridge/`](../shared_files/dhbridge/) during **stage-pytak** (upstream [snstac/dhbridge](https://github.com/snstac/dhbridge) is private, so the image build cannot `curl` GitHub releases). Bump the vendored file when tagging a new upstream release. AryaOS-specific config is applied in **stage-dhbridge**.

Wire format: [dronehone-bluetooth-protocol.md](https://github.com/snstac/dhbridge/blob/master/docs/dronehone-bluetooth-protocol.md).

## Architecture

```
DroneScout (Docker) → MQTT (localhost:1883) → dhbridge → Bluetooth RFCOMM/BLE → ATAK DroneHone
dronecot (parallel)  → Charontak → TAK mesh
```

The bridge ingests the same DroneScout MQTT feed as `dronecot`, maps Open Drone ID fields to DroneHone JSON, and serves them over Bluetooth. Optional **CoT TCP** ingest listens on port **8087** (see upstream README).

## Service

| Item | Value |
|------|-------|
| Unit | `dhbridge.service` |
| Config | `/etc/dhbridge.ini` (AryaOS defaults in `shared_files/dhbridge/`) |
| Binary | `dhbridge` |
| Stage | `stage-pytak` (package) + `stage-dhbridge` (config) / Ansible tag `dhbridge` |

Enable or restart:

```bash
sudo systemctl enable --now dhbridge
sudo systemctl restart dhbridge
sudo journalctl -u dhbridge -f
```

## Configuration

Edit `/etc/dhbridge.ini`:

| Key | Default | Purpose |
|-----|---------|---------|
| `MQTT_ENABLED` | `false` | Enable DroneScout MQTT ingest |
| `MQTT_BROKER` | `localhost` | DroneScout MQTT broker |
| `MQTT_TOPIC` | `#` | Subscribe topic |
| `COT_ENABLED` | `true` | CoT TCP listener on `COT_LISTEN_PORT` (8087) |
| `RFCOMM_ENABLED` | `true` | Classic BT SPP sensor (pair with phone) |
| `BLE_ENABLED` | `false` | BLE OpenDroneID advertisements |
| `BT_ADAPTER` | `hci0` | Bluetooth adapter (use Pi built-in; leave USB BT to DroneScout) |
| `BT_NAME` | `AryaOS RemoteID` | Friendly name (required for DroneHone discovery) |
| `EMIT_INTERVAL_SEC` | `2.0` | JSON line interval (must stay under 5 s watchdog) |

Environment overrides: `DHBRIDGE_MQTT_BROKER`, `DHBRIDGE_BLE_ENABLED`, etc.

## ATAK / DroneHone pairing

1. Ensure DroneScout MQTT is producing detections (`dronecot` / Docker stack running).
2. On the Pi: `sudo systemctl status dhbridge` — adapter must be up (`hci0`).
3. On Android: pair with **AryaOS RemoteID** in system Bluetooth settings.
4. In ATAK DroneHone: add **External Bluetooth** scanner and select the paired device.
5. UAS markers should appear when Remote ID traffic is present.

### Troubleshooting

- **Device not listed in DroneHone:** confirm `BT_NAME` is set and adapter is discoverable (`bluetoothctl show`).
- **Connect then disconnect:** bridge must send data every &lt;5 s; check MQTT ingest in logs.
- **No aircraft:** verify DroneScout MQTT (`mosquitto_sub -h localhost -t '#'`).
- **Adapter conflict:** use built-in `hci0` for the bridge; assign USB Bluetooth to DroneScout (`BT_UART_1` in `dronescout.conf`).

## BLE mode (phase 2)

Set `BLE_ENABLED = true` to advertise OpenDroneID on UUID `0000fffa-…` for DroneHone’s **Internal Bluetooth Scanner** (no pairing). Requires BlueZ LE advertising support on the adapter.

## Development

Clone [snstac/dhbridge](https://github.com/snstac/dhbridge) and see its README for `pip install -e .`, `make test`, and `make deb`.
