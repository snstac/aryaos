# Configuration

## Web Configuration

**Primary surfaces (write):**

| Task | Where |
|------|--------|
| Live status (read) | HTTPS portal at **`https://<host>/`** |
| Services, networking, packages | **Cockpit** at **`https://<host>/admin/`** |
| Upstream CoT lanes (mesh / TAK Server / tools) | Cockpit → **Charontak** → **`/etc/charontak.ini`** |
| Feeder tuning (`adsbcot`, `aiscot`, `lincot`, …) | Cockpit feeder apps + **`/etc/default/*`** |
| WiFi join / hotspot recovery | **Comitup** at **`http://<host>:9080/`** |

The **Node-RED Dashboard** at **`:1880/ui`** is **deprecated for configuration**. It remains for maps, TFR injection, and optional recorder logging only. See [node-red.md](node-red.md).

After changing **Charontak lanes** in **`/etc/charontak.ini`** or advanced feeder defaults, restart the affected units:

```bash
sudo systemctl restart charontak adsbcot aiscot lincot dronecot
```

(Add **`aircot`** if enabled on your image.)

Many functions of the AryaOS can be controlled, configured and monitored via the AryaOS Web page. When connecting directly to the AryaOS in Hotspot mode (via **AryaOS-XXXX** WiFi, same **XXXX** as hostname **`aryaos-xxxx`**) you can access the AryaOS Web page at **`http://aryaos-xxxx.local/`** or **`https://aryaos-xxxx.local/`** (portal). Before first-boot personalization the factory hostname is **`aryaos`** (**`http://aryaos.local`**).

### Connect to WiFI

**N.B.**: If you are connected to AryaOS via the WiFi Hospot (AryaOS-XXXX), reconfiguring the WiFi to connect to another network will terminate your Hospot connection. To reach the AryaOS Web page after this point, you'll need to connect to the same network as AryaOS.

1. Connect to the AryaOS WiFi network and browse to http://AryaOS.local
2. Click the WiFi configuration option.
3. Enter WiFi credentials and apply.

## Reset WiFi

Use the AryaOS web portal (when connected to the device) or re-flash / follow network recovery steps in [Troubleshooting](troubleshooting.md). Advanced deployments may use Cockpit or SSH with tools shipped on the image.

## Disable WiFi

Disable or reconfigure wireless interfaces from **Cockpit** (Networking), **NetworkManager**, or SSH using the same tooling as upstream Raspberry Pi OS. Exact steps depend on whether you use hotspot mode or client WiFi.

## Change TAK / CoT destination (summary)

Local **\*cot** feeders read **`COT_URL`** from **`/etc/aryaos/aryaos-config.txt`** (default **`udp+wo://127.0.0.1:28087`** → Charontak). Upstream mesh, TAK Server, and tool fan-out lanes belong in **`/etc/charontak.ini`** (Cockpit → Charontak). For command-line edits and service restarts, see **Command-line Configuration → Change TAK / CoT Routing** below.

## Command-line Configuration

For advanced users. These steps require familiarity with command-line terminals using SSH. 

### Change default password

The AryaOS image contains a user with a default password. It is recommended that the 
owner of AryaOS gateway change this password.

To change the default password:

1. SSH into AryaOS: ``ssh pi@AryaOS.local``
2. Change the password: ``passwd``

**Please make note of this password. There is no password recovery feature.**

See also: [Raspberry Pi Insecure first user](https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/)

### Change TAK / CoT Routing

AryaOS uses a **two-tier** CoT routing model:

1. **Local feeders** (`adsbcot`, `aiscot`, `dronecot`, `lincot`, …) read **`COT_URL`** from **`/etc/aryaos/aryaos-config.txt`**. The image default sends CoT to **Charontak** on **`udp+wo://127.0.0.1:28087`**. Keep this value in place for normal AryaOS deployments.
2. **Charontak** listens on **`udp+ro://127.0.0.1:28087`**, reads **`/etc/charontak.ini`**, and forwards the same local feeder stream to Mesh SA, a TAK Server, another local tool, or multiple destinations. Manage lanes via **Cockpit → Charontak** at **`https://<host>/admin/`** (restart **`charontak.service`** after saves).

Default Charontak egress is **`udp+wo://239.2.3.1:6969`** (Mesh SA) through the enabled **`local-to-mesh`** lane. Node-RED and other mesh listeners continue to use that group.

#### CoT routing COAs

| COA | Use case | Feeder `COT_URL` | Charontak lanes |
|-----|----------|------------------|-----------------|
| **Default Mesh SA** | Offline / local MANET / tablets listening to multicast | `udp+wo://127.0.0.1:28087` | Enable `local-to-mesh`: `udp+ro://127.0.0.1:28087` → `udp+wo://239.2.3.1:6969` |
| **TAK Server only** | Appliance sends all sensor CoT to one TAK Server | `udp+wo://127.0.0.1:28087` | Disable `local-to-mesh`; enable `local-to-takserver`: `udp+ro://127.0.0.1:28087` → `tls://<takserver>:8089` or `tcp://<takserver>:8087` |
| **Mesh SA + TAK Server** | Local tablets see Mesh SA while upstream also receives the same CoT | `udp+wo://127.0.0.1:28087` | Enable both `local-to-mesh` and `local-to-takserver` |
| **Other local tools** | Feed a recorder, processor, or sidecar without touching individual sensor daemons | `udp+wo://127.0.0.1:28087` | Add another lane from `udp+ro://127.0.0.1:28087` to that tool's CoT URL |
| **Legacy direct feeder routing** | Debug or bypass charontak entirely | Set each feeder directly, for example `udp+wo://239.2.3.1:6969` | Disable `charontak.service`; this is not the normal AryaOS pattern |

**Feeders only (advanced):** edit **`COT_URL`** in **`/etc/aryaos/aryaos-config.txt`** only when intentionally bypassing charontak, then restart the gateway units (for example ``sudo systemctl restart adsbcot``).

**Upstream TAK Server / extra lanes:** edit **`/etc/charontak.ini`** in Cockpit Charontak or with ``sudo nano /etc/charontak.ini``, then ``sudo systemctl restart charontak``. A disabled **`local-to-takserver`** lane template is shipped for TAK data package / enrollment URL imports; enable it and set **`egress_cot_url`** (and TLS paths) as needed.

**Legacy direct multicast:** to bypass Charontak entirely, set feeder **`COT_URL=udp+wo://239.2.3.1:6969`** in **`aryaos-config.txt`** and disable **`charontak.service`**.

### 1090 MHz ADS-B decoder (readsb vs dump1090-fa)

**readsb SDR backends (image default):** the pi-gen image rebuilds readsb with **RTL-SDR**, **SoapySDR** (Airspy and other Soapy devices), and **native HackRF**. Check on a running host:

```bash
readsb --help 2>&1 | grep -iE 'RTL-SDR|Soapy|HackRF'
```

Runtime helpers (SSH on the gateway):

| SDR | Script |
|-----|--------|
| RTL-SDR (EEPROM serial) | [`scripts/readsb-use-rtl-serial.sh`](../scripts/readsb-use-rtl-serial.sh) |
| Airspy (Soapy) | [`scripts/readsb-use-airspy.sh`](../scripts/readsb-use-airspy.sh) |
| HackRF (native or Soapy) | [`scripts/readsb-use-hackrf.sh`](../scripts/readsb-use-hackrf.sh) |

Only **one** of **readsb** and **dump1090-fa** may be enabled at a time: the image ships systemd **Conflicts=** drop-ins and enables **readsb** by default while **dump1090-fa** stays disabled.

**Unified JSON feed:** both decoders write **`/run/adsb/aircraft.json`**. **adsbcot** always uses ``FEED_URL=file:///run/adsb/aircraft.json`` — you do **not** change ``FEED_URL`` when switching decoders. The directory is set in **`ARYAOS_ADSB_JSON_DIR`** in ``/etc/aryaos/aryaos-config.txt`` (default ``/run/adsb``); readsb uses it via ``ADSB_JSON`` in ``/etc/default/readsb``.

**Image / Ansible:** set **`aryaos_adsb_decoder`** in **`vars.yml`** to ``readsb`` or ``dump1090_fa``. For pi-gen, export **`ARYAOS_ADSB_DECODER_DEFAULT=dump1090_fa`** during the build if you need dump1090-fa enabled instead of readsb.

**Runtime switch (example — use dump1090-fa):** ``sudo systemctl disable --now readsb`` then ``sudo systemctl enable --now dump1090-fa``, then ``sudo systemctl restart adsbcot``. Reverse the steps to return to **readsb**. No ``FEED_URL`` edit is required.

**Upgrading an older image** that used ``/run/readsb/aircraft.json``:

```bash
sudo sed -i 's|^ADSB_JSON=.*|ADSB_JSON=/run/adsb|' /etc/default/readsb
sudo sed -i 's|^FEED_URL=.*|FEED_URL=file:///run/adsb/aircraft.json|' /etc/default/adsbcot
sudo systemctl daemon-reload
sudo systemctl restart readsb adsbcot
```

The value **``ARYAOS_ADSB_DECODER``** in ``/etc/aryaos/aryaos-config.txt`` documents which decoder should be enabled; toggling **services** is still required when changing decoders on a live system.

### Change dump1090-fa & dump978-fa SDR serial numbers

Pre-assembled AryaOS devices use a **factory pairing**: **1090 MHz** traffic uses serial **`stx:1090:0`** on **readsb** (default) *or* **dump1090-fa** if you select that decoder at build time — not both. **978 MHz UAT** goes to **dump978-fa** on **`stx:978:0`** (Nooelec NESDR Nano 3 “978” sticks ship with that UAT preset). The 1090 and UAT serials **must differ**; the Ansible image build fails if `adsb_sdr_sn` and `uat_sdr_sn` are equal.

On a running system you can override the UAT binding without editing **`/etc/default/dump978-fa`** by hand:

1. Edit **`/etc/aryaos/aryaos-config.txt`** and set **`ARYAOS_UAT_RTL_SERIAL=`** to the `rtl_test` serial string for your 978 dongle.
2. Restart the service: **`sudo systemctl restart dump978-fa`**  
   (Each start runs **`apply-dump978-serial.sh`**, which merges that value into **`/etc/default/dump978-fa`**.)

When you plug in a Nano 3 programmed as **`stx:978:0`**, **udev** may **`systemctl try-restart dump978-fa`** automatically (see **`/etc/udev/rules.d/99-aryaos-dump978-uat-rtlsdr.rules`**). If your kernel exposes a different **`ATTRS{serial}`** string, adjust that rule using **`udevadm info -a`** on the device path under **`/dev/bus/usb/`**.

You may still need to change dump1090 / dump978 serials manually (sections below) if:

1. Using a self-assmbled AryaOS device.
2. There is need to change these values (for example, replacing an SDR).

An AryaOS Web Dashboard method of doing this is under development. See Issue [#21](https://github.com/snstac/AryaOS/issues/21). Until then use SSH, Cockpit file editor, or [`scripts/readsb-use-rtl-serial.sh`](../scripts/readsb-use-rtl-serial.sh).

**cockpit-lincot:** LINCOT v1.2.0 ships the daemon and **`/etc/default/lincot`** defaults; a **`cockpit-lincot`** `.deb` was not published on the v1.2.0 GitHub release — edit **`lincot`** defaults via Cockpit generic file editor or CLI until packaging lands.

#### Changing dump1090-fa SDR serial number

1. SSH into the AryaOS: ``ssh pi@AryaOS.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``

![Example rtl_test output with 1 SDR.](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/8d1ecb30-17f4-4225-a7c6-76eca789b645/Screen+Shot+2023-07-08+at+11.48.45+AM.png)

3. Using the Nano text editor, open the dump1090-fa configuration file: ``sudo nano /etc/default/dump1090-fa``

![dump1090-fa config line](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/44e90a93-624d-404b-b758-24d55377e626/Screen+Shot+2023-07-08+at+11.49.44+AM.png)

4. Find the line beginning with RECEIVER_SERIAL and change the value to match the SN value from the rtl_test command above.

5. Reload and restart dump1090-fa:
``sudo systemctl daemon-reload``
``sudo systemctl restart dump1090-fa``

### Changing dump978-fa SDR serial number

**Preferred:** set **`ARYAOS_UAT_RTL_SERIAL`** in **`/etc/aryaos/aryaos-config.txt`** to the value from **`rtl_test`**, then **`sudo systemctl restart dump978-fa`** (see **Change dump1090-fa & dump978-fa SDR serial numbers** above).

**Alternative (direct file edit):**

1. SSH into the AryaOS: ``ssh pi@AryaOS.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``
3. Using the Nano text editor, open the dump978-fa configuration file: 
``sudo nano /etc/default/dump978-fa``
4. Find the line containing ``driver=rtlsdr`` and set the ``serial=`` field to match your 978 SDR’s serial from ``rtl_test`` (see comments in the file for examples).
5. Reload and restart dump978-fa:

``sudo systemctl daemon-reload``

``sudo systemctl restart dump978-fa``

## Cockpit: the AryaOS admin surface

All administration happens in Cockpit at `https://<host>/admin/`:

- **AryaOS Site** ([cockpit-aryaos](https://github.com/snstac/cockpit-aryaos)) — site-wide settings in
  `/etc/aryaos/aryaos-config.txt`: the site `COT_URL`, ADS-B decoder selection, UAT serial,
  and **site-wide TAK TLS certificates** (PEM upload to `/etc/aryaos/tls/`, wired to
  `PYTAK_TLS_CLIENT_CERT/KEY/CAFILE`; the key is group-readable via `tak-certs`). Every
  gateway unit inherits the site config via `EnvironmentFile=`; per-service values override it.
- **Per-tool plugins** (from the snstac apt repo) — cockpit-adsbcot, cockpit-aiscot,
  cockpit-lincot, cockpit-dronecot, cockpit-aiscatcher, cockpit-gps: service control plus
  per-service config (`/etc/default/<svc>`) and per-service TLS overrides.
- **SiKW00FCOT** ([sikw00fcot](https://github.com/snstac/sikw00fcot)) — installed as
  `sikw00fcot.service` for SiKW00F MAVLink fan-out to CoT. It inherits the AryaOS
  site `COT_URL` first, so the default route is through Charontak; edit
  `/etc/default/sikw00fcot` for SiK-specific values such as `MAV_URL`.

## GPSTAK: Network GPS for ATAK / WinTAK

`gpstak` feeds the onboard GNSS to TAK devices so tablets can use
the sensor's GPS as their own position source: CoT position events to `COT_URL`
(default `udp+broadcast://255.255.255.255:4349` — ATAK's *External or Network GPS* port)
plus optional raw-NMEA passthrough for WinTAK (`NMEA_TARGETS`). PyTAK-style config in
`/etc/default/gpstak`; ships **disabled** — enable and configure in **Cockpit → GPSTAK**.
On the ATAK device: Settings → Device Preferences → GPS Preferences →
*External or Network GPS*. See https://ampledata.org/network_gps.html.

## LINCOT: Host Beacon Remarks And Accuracy

`lincot` sends the gateway's own host beacon to TAK. AryaOS keeps its `COT_URL` pointed
at Charontak and sets `GPS_INFO_CMD="gpspipe --json -n 5"`, so the beacon position comes
from the local gpsd TPV fix. LINCOT v1.3.1+ maps gpsd accuracy into CoT point fields:
`hae` from `altHAE` when present, `ce` from `eph` or `sqrt(epx^2 + epy^2)`, and `le`
from `epv`.

AryaOS also sets `REMARKS_EXTRA_CMD=/usr/local/sbin/aryaos-lincot-remarks`. LINCOT runs
that helper for each host beacon and appends a concise host environment snapshot to the
remarks: CPU/load, RAM, swap, root disk, temperature, uptime, and Raspberry Pi throttle
state when available.

For AryaOS-to-AryaOS discovery, the same LINCOT beacon also runs
`COT_DETAIL_XML_CMD=/usr/local/sbin/aryaos-cot-detail`. That helper emits a structured
`<__aryaos>` CoT detail block. `aryaos-neighbord.service` listens on Mesh SA
`239.2.3.1:6969`, caches those beacons in `/run/aryaos/neighbors.json`, and the portal
serves them from `/cgi-bin/aryaos-neighbors`. If a node has no current GNSS fix and
LINCOT is not emitting its normal host beacon, `aryaos-neighbord` sends a low-rate
status-only CoT beacon with a no-fix point so other AryaOS boxes can still show its
hostname, services, roles, and admin link.
