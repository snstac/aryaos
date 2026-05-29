# DroneHone Bluetooth sensor bridge

AryaOS can emulate an **external DroneHone Bluetooth sensor** so ATAK phones running the [DroneHone](https://github.com/) plugin receive Remote ID detections without a separate DroneScout handheld.

## Architecture

```
DroneScout (Docker) → MQTT (localhost:1883) → dronehone-bridge → Bluetooth RFCOMM/BLE → ATAK DroneHone
dronecot (parallel)  → Charontak → TAK mesh
```

The bridge ingests the same DroneScout MQTT feed as `dronecot`, maps Open Drone ID fields to DroneHone JSON, and serves them over Bluetooth.

Wire format: [dronehone-bridge/docs/dronehone-bluetooth-protocol.md](../dronehone-bridge/docs/dronehone-bluetooth-protocol.md).

## Service

| Item | Value |
|------|-------|
| Unit | `dronehone-bridge.service` |
| Config | `/etc/dronehone-bridge.ini` |
| Binary | `dronehone-bridge` |
| Stage | `stage-dronecot` (image build) / Ansible tag `dronehone-bridge` |

Enable or restart:

```bash
sudo systemctl enable --now dronehone-bridge
sudo systemctl restart dronehone-bridge
sudo journalctl -u dronehone-bridge -f
```

## Configuration

Edit `/etc/dronehone-bridge.ini`:

| Key | Default | Purpose |
|-----|---------|---------|
| `MQTT_BROKER` | `localhost` | DroneScout MQTT broker |
| `MQTT_TOPIC` | `#` | Subscribe topic |
| `RFCOMM_ENABLED` | `true` | Classic BT SPP sensor (pair with phone) |
| `BLE_ENABLED` | `false` | BLE OpenDroneID advertisements |
| `BT_ADAPTER` | `hci0` | Bluetooth adapter (use Pi built-in; leave USB BT to DroneScout) |
| `BT_NAME` | `AryaOS RemoteID` | Friendly name (required for DroneHone discovery) |
| `EMIT_INTERVAL_SEC` | `1.0` | JSON line interval (must stay under 5 s watchdog) |

Environment overrides: `DRONEHONE_BRIDGE_MQTT_BROKER`, `DRONEHONE_BRIDGE_BLE_ENABLED`, etc.

## ATAK / DroneHone pairing

1. Ensure DroneScout MQTT is producing detections (`dronecot` / Docker stack running).
2. On the Pi: `sudo systemctl status dronehone-bridge` — adapter must be up (`hci0`).
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

Source: [`dronehone-bridge/`](../dronehone-bridge/) in this repository.

```bash
cd dronehone-bridge
python3 -m unittest discover -s tests
pip install -e .
dronehone-bridge
```

Package builds during image creation in `stage-dronecot/00-install/01-run.sh` and `01-run-chroot.sh`.
