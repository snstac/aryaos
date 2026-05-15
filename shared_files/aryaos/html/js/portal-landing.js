/*
 * AryaOS portal landing — status via /cgi-bin/aryaos-portal-status (JSON).
 *
 * SPDX-License-Identifier: Apache-2.0
 * Copyright Sensors & Signals LLC https://www.snstac.com/
 */
(function () {
  var bh = document.getElementById("aos-browser-host");
  if (bh) {
    bh.textContent = window.location.hostname || "—";
  }

  var errEl = document.getElementById("aos-status-error");
  var gpsErrEl = document.getElementById("aos-gps-error");

  function showErr(msg) {
    if (!errEl) return;
    errEl.classList.remove("uk-hidden");
    errEl.textContent = msg;
  }

  function showGpsErr(msg) {
    if (!gpsErrEl) return;
    if (!msg) {
      gpsErrEl.classList.add("uk-hidden");
      gpsErrEl.textContent = "";
      return;
    }
    gpsErrEl.classList.remove("uk-hidden");
    gpsErrEl.textContent = msg;
  }

  function set(id, v) {
    var el = document.getElementById(id);
    if (el) el.textContent = v != null && v !== "" ? String(v) : "—";
  }

  function fmtNum(v, dec) {
    if (v == null || v === "") return null;
    var n = Number(v);
    if (!isFinite(n)) return null;
    return n.toFixed(dec);
  }

  function fillHost(d) {
    set("aos-hostname", d.hostname);
    set("aos-fqdn", d.fqdn);
    var pip = document.getElementById("aos-primary-ip");
    if (pip) pip.textContent = d.primary_ip || "—";
    var ipv4 = document.getElementById("aos-ipv4-block");
    if (ipv4) ipv4.textContent = d.ipv4_text || "—";
    set("aos-uptime", d.uptime);
  }

  function fillGps(g) {
    var ed = document.getElementById("aos-gps-errdetail");
    if (!g) {
      set("aos-gps-status", "no data");
      showGpsErr("");
      if (ed) ed.textContent = "—";
      return;
    }
    var ok = g.ok === true;
    var err = g.error || "";
    set("aos-gps-status", ok ? "gpsd reachable" : "check gpsd / USB");
    showGpsErr(g.error || "");

    set("aos-gps-fix", g.fix_type != null ? g.fix_type : "—");
    var la = fmtNum(g.lat, 6);
    var lo = fmtNum(g.lon, 6);
    var posEl = document.getElementById("aos-gps-pos");
    if (posEl) {
      posEl.textContent = la != null && lo != null ? la + ", " + lo : "—";
    }
    var alt = fmtNum(g.alt_m, 1);
    set("aos-gps-alt", alt != null ? alt + " m" : "—");

    var ex = fmtNum(g.epx_m, 1);
    var ey = fmtNum(g.epy_m, 1);
    var ev = fmtNum(g.epv_m, 1);
    var acc = "—";
    if (ex != null || ey != null || ev != null) {
      acc = (ex != null ? ex : "—") + " / " + (ey != null ? ey : "—") + " / " + (ev != null ? ev : "—") + " m";
    }
    set("aos-gps-acc", acc);

    set("aos-gps-grid", g.grid || "—");

    var vis = g.satellites_visible;
    var used = g.satellites_used;
    var satTxt = "—";
    if (vis != null || used != null) {
      satTxt = (used != null ? used : "?") + " used / " + (vis != null ? vis : "?") + " in view";
    }
    set("aos-gps-sats", satTxt);

    set("aos-gps-time", g.time || "—");

    var tr = fmtNum(g.track_deg, 1);
    var sp = fmtNum(g.speed_mps, 2);
    var cl = fmtNum(g.climb_mps, 2);
    var mot = "—";
    if (tr != null || sp != null || cl != null) {
      mot =
        (tr != null ? tr + "°" : "—") +
        " / " +
        (sp != null ? sp + " m/s" : "—") +
        " / " +
        (cl != null ? cl + " m/s" : "—");
    }
    set("aos-gps-motion", mot);

    if (ed) {
      var lines = [];
      if (err) lines.push(err);
      if (g.mode != null) lines.push("mode (raw): " + g.mode);
      ed.textContent = lines.length ? lines.join("\n") : "—";
    }
  }

  var KIND_LABELS = {
    wifi: "Wi-Fi",
    bluetooth: "Bluetooth",
    usb_sdr: "USB SDR",
    sdr_service: "Service",
    cellular: "Cellular",
    unknown: "Unknown",
  };

  function kindLabel(k) {
    return KIND_LABELS[k] || (k != null && k !== "" ? String(k) : "—");
  }

  function fillRadios(r) {
    var emptyEl = document.getElementById("aos-radios-empty");
    var tbody = document.getElementById("aos-radios-tbody");
    var tbl = document.getElementById("aos-rf-table");
    var errRf = document.getElementById("aos-radios-error");
    if (!tbody || !emptyEl) return;
    tbody.innerHTML = "";
    if (errRf) {
      errRf.classList.add("uk-hidden");
      errRf.textContent = "";
    }
    if (!r) {
      emptyEl.textContent = "Radio status unavailable (host error).";
      emptyEl.classList.remove("uk-hidden");
      if (tbl) tbl.classList.add("uk-hidden");
      return;
    }
    if (r.ok === false && r.error) {
      if (errRf) {
        errRf.textContent = r.error;
        errRf.classList.remove("uk-hidden");
      }
    }
    var list = r.devices || [];
    if (!list.length) {
      emptyEl.textContent = "No radio-class devices detected.";
      emptyEl.classList.remove("uk-hidden");
      if (tbl) tbl.classList.add("uk-hidden");
      return;
    }
    emptyEl.classList.add("uk-hidden");
    if (tbl) tbl.classList.remove("uk-hidden");
    list.forEach(function (dev) {
      var tr = document.createElement("tr");
      var notes = dev.detail != null && dev.detail !== "" ? String(dev.detail) : "—";
      var cells = [kindLabel(dev.kind), dev.label, dev.state, notes, dev.source];
      cells.forEach(function (text, idx) {
        var td = document.createElement("td");
        td.textContent = text != null && text !== "" ? String(text) : "—";
        if (idx === 4) td.className = "aos-rf-col-src uk-text-meta";
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
  }

  var api = "/cgi-bin/aryaos-portal-status";
  function loadStatus() {
    fetch(api, { credentials: "same-origin", cache: "no-store" })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (d) {
        errEl && errEl.classList.add("uk-hidden");
        fillHost(d);
        fillGps(d.gps || null);
        fillRadios(d.radios != null ? d.radios : { ok: true, devices: [], error: null });
      })
      .catch(function (e) {
        showErr("Could not load status from " + api + ". " + (e && e.message ? e.message : ""));
        fillRadios(null);
      });
  }
  loadStatus();
  setInterval(loadStatus, 8000);
})();
