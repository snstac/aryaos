#!/usr/bin/env python3
"""
GPSTAK: Network GPS for TAK — feed this device's GNSS position to ATAK/WinTAK.

ATAK's "External or Network GPS" listens on UDP 4349 for Cursor on Target XML
and adopts the received point as the device's own position (WinTAK also accepts
raw NMEA). GPSTAK reads gpsd and emits both:

  - CoT position events via PyTAK to COT_URL (default
    udp+broadcast://255.255.255.255:4349 — every ATAK device on the subnet),
  - optional raw NMEA ($GPGGA/$GPRMC passthrough from gpsd) to NMEA_TARGETS
    ("host:port host:port") for WinTAK.

Configuration is PyTAK-style via /etc/default/gpstak (systemd EnvironmentFile)
or the environment: COT_URL, GPSTAK_RATE, GPSTAK_UID, GPSTAK_COT_TYPE,
GPSTAK_STALE, GPSD_HOST, GPSD_PORT, NMEA_TARGETS.

See https://ampledata.org/network_gps.html

Copyright Sensors & Signals LLC https://www.snstac.com/
SPDX-License-Identifier: Apache-2.0
"""

import asyncio
import configparser
import json
import logging
import os
import socket
import xml.etree.ElementTree as ET

import pytak

VERSION = "1.0.0"
logger = logging.getLogger("gpstak")


def conf(key, default):
    return os.environ.get(key, default)


class GpsdClient:
    """Minimal asyncio gpsd watcher: keeps the latest TPV and raw NMEA lines."""

    def __init__(self, host, port, nmea_sink=None):
        self.host = host
        self.port = int(port)
        self.nmea_sink = nmea_sink
        self.tpv = None

    async def run(self):
        while True:
            try:
                reader, writer = await asyncio.open_connection(self.host, self.port)
                watch = {"enable": True, "json": True}
                if self.nmea_sink:
                    watch["nmea"] = True
                writer.write(("?WATCH=" + json.dumps(watch) + "\n").encode())
                await writer.drain()
                logger.info("connected to gpsd at %s:%s", self.host, self.port)
                while True:
                    line = await reader.readline()
                    if not line:
                        raise ConnectionError("gpsd closed connection")
                    text = line.decode(errors="replace").strip()
                    if text.startswith("$"):
                        if self.nmea_sink and text[3:6] in ("GGA", "RMC"):
                            self.nmea_sink(text)
                        continue
                    try:
                        msg = json.loads(text)
                    except ValueError:
                        continue
                    if msg.get("class") == "TPV" and msg.get("mode", 0) >= 2:
                        self.tpv = msg
            except (OSError, ConnectionError) as exc:
                logger.warning("gpsd: %s — retrying in 5s", exc)
                self.tpv = None
                await asyncio.sleep(5)


class NmeaFanout:
    """Raw NMEA passthrough over UDP for WinTAK network GPS."""

    def __init__(self, targets):
        self.addrs = []
        for t in targets.split():
            host, _, port = t.rpartition(":")
            if host and port.isdigit():
                self.addrs.append((host, int(port)))
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

    def send(self, sentence):
        data = (sentence + "\r\n").encode()
        for addr in self.addrs:
            try:
                self.sock.sendto(data, addr)
            except OSError as exc:
                logger.debug("nmea send %s: %s", addr, exc)


def cot_event(tpv, uid, cot_type, stale, source_name):
    """CoT position event from a gpsd TPV report."""
    lat = tpv.get("lat")
    lon = tpv.get("lon")
    if lat is None or lon is None:
        return None
    hae = tpv.get("altHAE", tpv.get("alt", 0.0)) or 0.0
    ce = max(float(tpv.get("epx", 0) or 0), float(tpv.get("epy", 0) or 0)) or 9999999.0
    le = float(tpv.get("epv", 0) or 0) or 9999999.0

    root = ET.Element("event")
    root.set("version", "2.0")
    root.set("type", cot_type)
    root.set("uid", uid)
    root.set("how", "m-g")
    root.set("time", pytak.cot_time())
    root.set("start", pytak.cot_time())
    root.set("stale", pytak.cot_time(stale))
    point = ET.SubElement(root, "point")
    point.set("lat", pytak.truncate_float(lat))
    point.set("lon", pytak.truncate_float(lon))
    point.set("hae", str(hae))
    point.set("ce", str(ce))
    point.set("le", str(le))
    detail = ET.SubElement(root, "detail")
    track = ET.SubElement(detail, "track")
    track.set("course", str(tpv.get("track", 0.0) or 0.0))
    track.set("speed", str(tpv.get("speed", 0.0) or 0.0))
    remarks = ET.SubElement(detail, "remarks")
    remarks.text = f"Network GPS from {source_name}"
    return ET.tostring(root)


class GpsWorker(pytak.QueueWorker):
    """Emit the latest gpsd fix as CoT at a fixed rate."""

    def __init__(self, queue, config, gpsd):
        super().__init__(queue, config)
        self.gpsd = gpsd

    async def run(self):
        rate = float(conf("GPSTAK_RATE", "1.0"))
        uid = conf("GPSTAK_UID", "GPSTAK-" + socket.gethostname())
        source_name = conf("GPSTAK_SOURCE_NAME", socket.gethostname())
        cot_type = conf("GPSTAK_COT_TYPE", "a-f-G")
        stale = int(conf("GPSTAK_STALE", "10"))
        logger.info("emitting CoT every %ss as uid=%s source=%s", rate, uid, source_name)
        while True:
            tpv = self.gpsd.tpv
            if tpv:
                event = cot_event(tpv, uid, cot_type, stale, source_name)
                if event:
                    await self.put_queue(event)
            await asyncio.sleep(rate)


async def main():
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s gpstak %(levelname)s %(message)s",
    )
    parser = configparser.ConfigParser()
    parser.read_dict({"gpstak": {
        "COT_URL": conf("COT_URL", "udp+broadcast://255.255.255.255:4349"),
        "PYTAK_NO_HELLO": "1",
    }})
    config = parser["gpstak"]
    # Pass through PYTAK_* (TLS etc.) from the environment.
    for key, val in os.environ.items():
        if key.startswith("PYTAK_"):
            config[key] = val

    nmea = None
    targets = conf("NMEA_TARGETS", "").strip()
    if targets:
        nmea = NmeaFanout(targets)
        logger.info("NMEA passthrough to: %s", targets)

    gpsd = GpsdClient(conf("GPSD_HOST", "127.0.0.1"), conf("GPSD_PORT", "2947"),
                      nmea_sink=nmea.send if nmea else None)

    clitool = pytak.CLITool(config)
    await clitool.setup()
    clitool.add_tasks({GpsWorker(clitool.tx_queue, config, gpsd)})
    await asyncio.gather(clitool.run(), gpsd.run())


if __name__ == "__main__":
    asyncio.run(main())
