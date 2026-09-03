/*
 * AryaOS portal v2 — big-tile dashboard JS.
 * Polls the same /cgi-bin/aryaos-portal-status endpoint as portal-landing.js
 * every 8 s and drives the v2 tile IDs.
 *
 * SPDX-License-Identifier: Apache-2.0
 * Copyright Sensors & Signals LLC https://www.snstac.com/
 */
(function () {
  /* ── Theme restore (before first paint) ─────────────────────────────── */
  /* Inline in <head> handles this; JS here handles the toggle button. */

  /* ── Browser-derived hostname (offline fallback before first poll) ───── */
  var hostEl = document.getElementById("aos-v2-appbar-host");
  if (hostEl && !hostEl.textContent.trim()) {
    hostEl.textContent = window.location.hostname || "—";
  }

  /* ── Tile state constants ────────────────────────────────────────────── */
  var TILE_STATE_CLASSES = [
    "aos-tile--ok",
    "aos-tile--warn",
    "aos-tile--bad",
    "aos-tile--pending",
  ];

  /* ── Helper: set tile state and value text ────────────────────────────── */
  function setTile(id, state, value) {
    var el = document.getElementById(id);
    if (!el) return;
    TILE_STATE_CLASSES.forEach(function (c) { el.classList.remove(c); });
    el.classList.add("aos-tile--" + (state || "pending"));
    var valEl = el.querySelector(".aos-tile-value");
    if (valEl) valEl.textContent = value || "—";
    /* ARIA: update label so screen readers get the new state. */
    var nameEl = el.querySelector(".aos-tile-name");
    var name = nameEl ? nameEl.textContent : (id || "");
    el.setAttribute("aria-label", name + ": " + (value || state || "pending"));
  }

  /* ── Online / offline indicator ─────────────────────────────────────── */
  function setOnline(ok) {
    var el = document.getElementById("aos-v2-online");
    if (!el) return;
    el.classList.toggle("aos-online--off", !ok);
    var dot = el.querySelector(".aos-online-dot");
    el.textContent = "";
    if (dot) { el.appendChild(dot); dot.setAttribute("aria-hidden", "true"); }
    el.appendChild(document.createTextNode(ok ? " ONLINE" : " OFFLINE"));
  }

  /* ── Error banner ────────────────────────────────────────────────────── */
  function showErr(msg) {
    var el = document.getElementById("aos-v2-error");
    if (!el) return;
    if (!msg) { el.hidden = true; el.textContent = ""; return; }
    el.hidden = false;
    el.textContent = msg;
  }

  /* ── TAK state → tile state ─────────────────────────────────────────── */
  function takToTileState(takState) {
    if (takState === "up") return "ok";
    if (takState === "degraded") return "warn";
    if (takState === "down" || takState === "disabled") return "bad";
    /* absent / unavailable / pending → pending */
    return "pending";
  }

  function takStateLabel(takState) {
    var MAP = {
      up: "ACTIVE",
      down: "DOWN",
      degraded: "DEGRADED",
      absent: "NOT DETECTED",
      disabled: "DISABLED",
      unavailable: "UNAVAILABLE",
      pending: "…",
    };
    return MAP[takState] || (takState ? String(takState).toUpperCase() : "…");
  }

  /* ── Fill AIRCRAFT tile (adsbcot) ────────────────────────────────────── */
  function fillAircraft(tg) {
    if (!tg || tg.ok === false) { setTile("aos-v2-tile-aircraft", "pending", "…"); return; }
    var items = tg.items || [];
    var it = null;
    items.forEach(function (i) { if (i && i.id === "adsbcot") it = i; });
    if (!it) { setTile("aos-v2-tile-aircraft", "pending", "NO DATA"); return; }
    setTile("aos-v2-tile-aircraft", takToTileState(it.state), takStateLabel(it.state));
  }

  /* ── Fill UAS tile (dronecot aggregate) ─────────────────────────────── */
  function fillUas(tg) {
    if (!tg || tg.ok === false) { setTile("aos-v2-tile-uas", "pending", "…"); return; }
    var items = tg.items || [];
    var droneIds = ["dronecot"];
    var relevant = items.filter(function (i) {
      return i && droneIds.indexOf(i.id) !== -1;
    });
    if (!relevant.length) { setTile("aos-v2-tile-uas", "pending", "NO DATA"); return; }
    var up = relevant.filter(function (i) { return i.state === "up"; }).length;
    var degraded = relevant.filter(function (i) { return i.state === "degraded"; }).length;
    var down = relevant.filter(function (i) { return i.state === "down"; }).length;
    var state = up > 0 ? "ok" : degraded > 0 ? "warn" : down > 0 ? "bad" : "pending";
    var label = up === relevant.length ? "ACTIVE"
      : up === 0 && down > 0 ? "DOWN"
      : up === 0 && degraded > 0 ? "DEGRADED"
      : up + "/" + relevant.length + " UP";
    setTile("aos-v2-tile-uas", state, label);
  }

  /* ── Fill MARITIME tile (aiscot) ─────────────────────────────────────── */
  function fillMaritime(tg) {
    if (!tg || tg.ok === false) { setTile("aos-v2-tile-maritime", "pending", "…"); return; }
    var items = tg.items || [];
    var it = null;
    items.forEach(function (i) { if (i && i.id === "aiscot") it = i; });
    if (!it) { setTile("aos-v2-tile-maritime", "pending", "NO DATA"); return; }
    setTile("aos-v2-tile-maritime", takToTileState(it.state), takStateLabel(it.state));
  }

  /* ── Fill SENSORS tile (active sensor count) ─────────────────────────── */
  function fillSensors(tg) {
    if (!tg || tg.ok === false) { setTile("aos-v2-tile-sensors", "pending", "…"); return; }
    var items = tg.items || [];
    var skip = { cotbridge: true, lincot: true };
    var sensors = items.filter(function (i) {
      return i && !skip[i.id] &&
        i.state !== "disabled" && i.state !== "absent" && i.state !== "unavailable";
    });
    var total = sensors.length;
    var up = sensors.filter(function (i) { return i.state === "up"; }).length;
    if (total === 0) { setTile("aos-v2-tile-sensors", "pending", "NONE"); return; }
    var state = up === total ? "ok" : up === 0 ? "bad" : "warn";
    setTile("aos-v2-tile-sensors", state, up + "/" + total + " ACTIVE");
  }

  /* ── Fill GNSS tile ──────────────────────────────────────────────────── */
  function fillGnss(g) {
    if (!g) { setTile("aos-v2-tile-gnss", "pending", "…"); return; }
    if (!g.ok) { setTile("aos-v2-tile-gnss", "bad", "OFFLINE"); return; }
    if (g.mode >= 2 && g.lat != null) {
      var label = (g.fix_type || g.mode + "D") + " FIX";
      setTile("aos-v2-tile-gnss", "ok", label);
    } else {
      setTile("aos-v2-tile-gnss", "warn", "NO FIX");
    }
  }

  /* ── Fill SYSTEM tile ────────────────────────────────────────────────── */
  function fillSystem(s) {
    if (!s) { setTile("aos-v2-tile-system", "pending", "…"); return; }
    var thr = s.throttle;
    if (!thr) { setTile("aos-v2-tile-system", "warn", "UNKNOWN"); return; }
    var state = thr.state === "bad" ? "bad" : thr.state === "warn" ? "warn" : "ok";
    var label = thr.state === "bad" ? "UNDER-VOLT" : thr.state === "warn" ? "CAUTION" : "OK";
    if (s.cpu_temp_c != null) {
      var t = Number(s.cpu_temp_c);
      if (isFinite(t)) label += " · " + t.toFixed(1) + "°C";
    }
    setTile("aos-v2-tile-system", state, label);
  }

  /* ── Fill hostname ────────────────────────────────────────────────────── */
  function fillHost(d) {
    var el = document.getElementById("aos-v2-appbar-host");
    if (el) el.textContent = (d && d.hostname) ? d.hostname : "";
  }

  /* ── Day/night theme toggle ──────────────────────────────────────────── */
  (function () {
    var root = document.documentElement;
    var btn = document.getElementById("aos-v2-theme-toggle");
    if (!btn) return;
    var txt = document.getElementById("aos-v2-theme-txt");
    var ico = btn.querySelector(".aos-theme-ico");
    var ORDER = ["auto", "day", "night"];
    var ICON  = { auto: "◐", day: "☀", night: "☾" };
    var LABEL = { auto: "Auto", day: "Day", night: "Night" };
    function current() {
      try {
        var t = localStorage.getItem("aos-theme");
        return t === "day" || t === "night" ? t : "auto";
      } catch (e) { return "auto"; }
    }
    function apply(mode) {
      if (mode === "day" || mode === "night") root.setAttribute("data-theme", mode);
      else root.removeAttribute("data-theme");
      try {
        mode === "auto" ? localStorage.removeItem("aos-theme")
                        : localStorage.setItem("aos-theme", mode);
      } catch (e) {}
      if (txt) txt.textContent = LABEL[mode];
      if (ico) ico.textContent = ICON[mode];
    }
    apply(current());
    btn.addEventListener("click", function () {
      apply(ORDER[(ORDER.indexOf(current()) + 1) % ORDER.length]);
    });
  })();

  /* ── Main poll loop ──────────────────────────────────────────────────── */
  var api = "/cgi-bin/aryaos-portal-status";

  function loadStatus() {
    fetch(api, { credentials: "same-origin", cache: "no-store" })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (d) {
        showErr("");
        setOnline(true);
        fillHost(d);
        fillAircraft(d.tak_gateways || null);
        fillUas(d.tak_gateways || null);
        fillMaritime(d.tak_gateways || null);
        fillSensors(d.tak_gateways || null);
        fillGnss(d.gps || null);
        fillSystem(d.system || null);
      })
      .catch(function (e) {
        var detail = e && e.message ? " Detail: " + e.message : "";
        showErr(
          "Status request failed for " + api +
          ". Examine the network connection and try again." + detail
        );
        setOnline(false);
        ["aircraft", "uas", "maritime", "sensors", "gnss", "system"].forEach(function (name) {
          setTile("aos-v2-tile-" + name, "pending", "—");
        });
      });
  }

  loadStatus();
  setInterval(loadStatus, 8000);
})();
