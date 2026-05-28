# dronehone-bridge

Emulate a **DroneHone external Bluetooth sensor** on AryaOS: ingest Remote ID from DroneScout MQTT, map to DroneHone JSON, and export over Bluetooth Classic RFCOMM (and optionally BLE OpenDroneID).

See [docs/dronehone-bluetooth-protocol.md](docs/dronehone-bluetooth-protocol.md) for the wire format.

## Quick start (dev)

```bash
pip install -e .
dronehone-bridge
```

Configuration: `/etc/dronehone-bridge.ini` or `/etc/default/dronehone-bridge`.

## License

Apache-2.0 — Copyright Sensors & Signals LLC
