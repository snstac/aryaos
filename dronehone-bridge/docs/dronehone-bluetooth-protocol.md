# DroneHone Bluetooth Protocol (reverse-engineered)

Reference: ATAK DroneHone plugin source in `remote-id-maintenance-5.2` (Nine Hill Technologies / PAR Government).

AryaOS `dronehone-bridge` emulates an **external Bluetooth detection sensor**. DroneHone on ATAK is the **client** (initiates pairing and reads data).

## Phase 1: Bluetooth Classic RFCOMM / SPP

| Item | Value |
|------|-------|
| Profile | Serial Port Profile (SPP) |
| UUID | `00001101-0000-1000-8000-00805F9B34FB` |
| Framing | One JSON object per line (`\n` terminated) |
| Discovery | Classic BT inquiry; device **must have a non-null friendly name** |

### Connection lifecycle

1. ATAK discovers the sensor (`ExternalBluetoothDeviceFinder`).
2. User selects device; plugin bonds if needed, opens RFCOMM socket to SPP UUID.
3. Sensor must send **DeviceInfo** JSON within **500 ms** or connect fails.
4. Sensor must send at least one line every **5 s** (watchdog) or plugin disconnects.

### Message types

#### DeviceInfo (first line after connect)

Required keys: `version`, `manufacturer`. Optional: `make`, `serialNumber`.

```json
{"version":"1.0.0","manufacturer":"Sensors & Signals LLC","make":"AryaOS","serialNumber":"ds240100000100"}
```

Parsed by `DeviceInfo.tryFromJson` in the plugin.

#### UAS update (detection)

Required keys: `uasId`, `rssi`, `recvMethod`.

Optional keys (from `DetectedUas.tryFromJson`):

| JSON key | Type | Notes |
|----------|------|-------|
| `uasType` | int | `UAType` enum ordinal |
| `uasLat`, `uasLon`, `uasHae` | double | Aircraft position (HAE metres) |
| `uasHeading` | double | Track direction degrees |
| `uasHag`, `uasHat` | double | Height AGL / above takeoff |
| `uasHorizontalError`, `uasVerticalError` | double | Accuracy metres |
| `uasHSpeed`, `uasVSpeed` | double | m/s |
| `uasHSpeedError`, `uasVSpeedError` | double | |
| `uasBaroPressure`, `uasBaroPressureAcc` | double | |
| `opLat`, `opLon`, `opHae` | double | Operator location |
| `opId` | string | |
| `opLocationType` | int | `OperatorLocationSource` ordinal |
| `opStatus` | int | `OperationalStatus` ordinal |
| `description` | string | Self-ID text |
| `serialNumber`, `remoteId`, `sessionId`, `utmId`, `caaRegId` | string | ID variants by `IDType` |

Example:

```json
{"uasId":"1581F5YHX24BB002FUBN","rssi":-62,"recvMethod":1,"uasType":2,"uasLat":37.7599566,"uasLon":-122.4983164,"uasHae":212.0,"uasHeading":126.0,"uasHSpeed":12.75,"opLat":37.7599983,"opLon":-122.4973975,"opId":"WCzFzGDgIzxEnUcT","opStatus":2,"description":"Recreational"}
```

#### Battery (optional)

If a line is not a DeviceInfo or UAS update, plugin tries battery parse:

```json
{"batteryLevel":0.85}
```

`batteryLevel` is a fraction 0.0–1.0 (displayed as percent).

### `recvMethod` codes (`TransmissionMethod.fromCode`)

| Code | Method |
|------|--------|
| 1 | WiFiBeacon24Ghz |
| 2 | WiFiNaN24Ghz |
| 4 | WiFiBeacon5Ghz |
| 8 | WiFiNaN5Ghz |
| 16 | BluetoothLegacy |
| 32 | BluetoothLongRange |
| other | Other |

## Phase 2: BLE OpenDroneID (internal scanner path)

DroneHone **Internal Bluetooth Scanner** (`BluetoothScanner`) filters LE advertisements:

| Item | Value |
|------|-------|
| Service UUID | `0000fffa-0000-1000-8000-00805f9b34fb` |
| Service data prefix | `0x0D` |
| Scan mode | Non-legacy, LE all PHY, low latency |

Advertisement payload (after AD headers) contains ASTM OpenDroneID message(s). Message type is high nibble of first byte per message:

| Nibble | Type |
|--------|------|
| 0 | BASIC_ID |
| 1 | LOCATION_VECTOR |
| 2 | AUTHENTICATION |
| 3 | SELF_ID |
| 4 | SYSTEM |
| 5 | OPERATOR_ID |
| 0xF | MESSAGE_PACK (0x19 byte pages) |

Plugin aggregates messages per MAC address (500 ms throttle) before emitting CoT.

## References

- `BluetoothDeviceScanner.kt` — RFCOMM client, JSON parsing, watchdog timers
- `ExternalBluetoothDeviceFinder.kt` — classic BT discovery
- `BluetoothScanner.kt` — BLE LE scan filter and ODID decode
- `DetectedUas.kt` — UAS JSON schema
