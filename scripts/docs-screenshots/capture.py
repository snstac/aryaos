#!/usr/bin/env python3
"""Regenerate documentation screenshots from the real AryaOS front-end code.

Renders the pages with headless Chromium (Playwright) using representative,
canned data — no hardware or running Cockpit backend required. Output PNGs are
written into docs/media/screenshots/.

Surfaces:
  * The landing portal      (in-repo: shared_files/aryaos/html) — always.
  * The AryaOS Site page     (sibling repo ../cockpit-aryaos)   — if present.

The AryaOS Site page is vanilla JS that talks to a global ``window.cockpit``;
mock-cockpit.js provides that with canned responses. The portal's status CGI is
stubbed via request interception. React plugins (charontak lane editor, the
per-gateway pages) bundle the real Cockpit client and need a build-time cockpit
mock instead — see README.md.

Usage:
    pip install -r scripts/docs-screenshots/requirements.txt
    playwright install chromium
    python scripts/docs-screenshots/capture.py

Run from the repository root.
"""
from __future__ import annotations

import functools
import http.server
import json
import os
import socketserver
import threading

from playwright.sync_api import sync_playwright

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(REPO, "docs", "media", "screenshots")
MOCK = os.path.join(HERE, "mock-cockpit.js")

PORTAL_STATUS = {
    "ok": True, "error": None,
    "hostname": "aryaos-a1b2", "fqdn": "aryaos-a1b2.local",
    "primary_ip": "10.41.0.1",
    "ipv4_text": "wlan0        10.41.0.1/24\neth0         192.168.1.42/24\ntailscale0   100.72.14.3/32",
    "uptime": "3 days, 4:12",
    "tak_gateways": {"ok": True, "items": [
        {"id": "adsbcot", "state": "active", "title": "adsbcot — active"},
        {"id": "aiscot", "state": "active", "title": "aiscot — active"},
        {"id": "dronecot", "state": "active", "title": "dronecot — active"},
        {"id": "sikw00fcot", "state": "active", "title": "sikw00fcot — active"}]},
    "system": {"cpu_temp_c": 47.8, "load": {"1": 0.42, "5": 0.55, "15": 0.48},
               "throttle": {"state": "ok", "current": [], "history": []}, "mem": None},
    "gps": {"ok": True, "error": None, "fix_type": "3D fix", "mode": 3,
            "lat": 38.8895, "lon": -77.0353, "satellites_used": 11,
            "satellites_visible": 14, "alt_m": 21.4, "track_deg": 0, "speed_mps": 0,
            "time": "2026-07-18T22:41:00Z", "grid": "FM18lv"},
    "radios": {"ok": True, "error": None, "devices": [
        {"index": 0, "vendor": "Realtek", "product": "RTL2838UHIDIR", "serial": "stx:1090:0"},
        {"index": 1, "vendor": "Realtek", "product": "RTL2838UHIDIR", "serial": "stx:978:0"}]},
}
PORTAL_NEIGHBORS = {"ok": True, "items": [
    {"uid": "aryaos-c3d4", "host": {"name": "aryaos-c3d4", "admin_url": "https://aryaos-c3d4.local/admin/"},
     "roles": {"adsb": True, "uas": True}, "point": {"lat": 38.90, "lon": -77.04}, "age_s": 12},
    {"uid": "aryaos-e5f6", "host": {"name": "aryaos-e5f6", "admin_url": "https://aryaos-e5f6.local/admin/"},
     "roles": {"ais": True}, "point": {"lat": 38.88, "lon": -77.02}, "age_s": 45}]}


def serve(directory: str, port: int) -> socketserver.TCPServer:
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    httpd = socketserver.TCPServer(("127.0.0.1", port), handler)
    httpd.allow_reuse_address = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def route_json(page, pattern: str, payload) -> None:
    page.route(pattern, lambda r: r.fulfill(
        status=200, content_type="application/json", body=json.dumps(payload)))


def shoot_portal(browser) -> None:
    html = os.path.join(REPO, "shared_files", "aryaos", "html")
    httpd = serve(html, 8760)
    try:
        for name, width in [("portal-landing", 1280), ("portal-landing-mobile", 414)]:
            page = browser.new_page(viewport={"width": width, "height": 900}, device_scale_factor=2)
            route_json(page, "**/cgi-bin/aryaos-portal-status*", PORTAL_STATUS)
            route_json(page, "**/cgi-bin/aryaos-neighbors*", PORTAL_NEIGHBORS)
            page.goto("http://127.0.0.1:8760/index.html", wait_until="networkidle")
            page.wait_for_timeout(1200)
            page.screenshot(path=os.path.join(OUT, f"{name}.png"), full_page=True)
            page.close()
            print("wrote", name)
    finally:
        httpd.shutdown()


def shoot_aryaos_site(browser) -> None:
    plugin = os.path.join(REPO, "..", "cockpit-aryaos")
    if not os.path.isfile(os.path.join(plugin, "aryaos.js")):
        print("skip aryaos-site: ../cockpit-aryaos not found")
        return
    import shutil
    import tempfile
    work = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(work, "base1"))
        for f in ("index.html", "aryaos.js", "aryaos.css"):
            shutil.copy(os.path.join(plugin, f), os.path.join(work, f))
        shutil.copy(MOCK, os.path.join(work, "base1", "cockpit.js"))
        httpd = serve(work, 8761)
        try:
            page = browser.new_page(viewport={"width": 1120, "height": 1000}, device_scale_factor=2)
            route_json(page, "**/cgi-bin/aryaos-neighbors*", PORTAL_NEIGHBORS)
            route_json(page, "**/cgi-bin/aryaos-portal-status*", {"ok": True})
            page.goto("http://127.0.0.1:8761/index.html", wait_until="networkidle")
            page.wait_for_timeout(1500)
            page.screenshot(path=os.path.join(OUT, "aryaos-site-cockpit.png"), full_page=True)
            page.close()
            print("wrote aryaos-site-cockpit")
        finally:
            httpd.shutdown()
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        shoot_portal(browser)
        shoot_aryaos_site(browser)
        browser.close()
    print("done ->", OUT)


if __name__ == "__main__":
    main()
