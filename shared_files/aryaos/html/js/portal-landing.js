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

  function fallbackCopyText(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    var ok = false;
    try {
      ok = document.execCommand("copy");
    } catch (e1) {
      ok = false;
    }
    document.body.removeChild(ta);
    return ok;
  }

  function copyTextToClipboard(text) {
    var t = text != null ? String(text) : "";
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(t).then(
        function () {
          return true;
        },
        function () {
          return fallbackCopyText(t);
        }
      );
    }
    return Promise.resolve(fallbackCopyText(t));
  }

  document.addEventListener("click", function (ev) {
    var btn = ev.target.closest && ev.target.closest(".aos-copy-btn");
    if (!btn) return;
    ev.preventDefault();
    var id = btn.getAttribute("data-copy-for");
    if (!id) return;
    var node = document.getElementById(id);
    if (!node) return;
    var text = node.textContent != null ? node.textContent : "";
    if (btn._aosCopyTimer) {
      clearTimeout(btn._aosCopyTimer);
      btn._aosCopyTimer = null;
    }
    btn.classList.remove("aos-copy-btn--ok", "aos-copy-btn--fail");
    copyTextToClipboard(text).then(function (ok) {
      btn.classList.add(ok ? "aos-copy-btn--ok" : "aos-copy-btn--fail");
      btn._aosCopyTimer = setTimeout(function () {
        btn.classList.remove("aos-copy-btn--ok", "aos-copy-btn--fail");
        btn._aosCopyTimer = null;
      }, 1500);
    });
  });

  var dpForm = document.getElementById("aos-tak-dp-form");
  var dpFile = document.getElementById("aos-tak-dp-file");
  var dpFileLabel = document.getElementById("aos-tak-dp-file-label");
  var dpSubmit = document.getElementById("aos-tak-dp-submit");
  var dpResult = document.getElementById("aos-tak-dp-result");

  function setDpResult(kind, text) {
    if (!dpResult) return;
    dpResult.classList.remove("uk-hidden", "aos-upload-result--ok", "aos-upload-result--bad");
    dpResult.classList.add(kind === "ok" ? "aos-upload-result--ok" : "aos-upload-result--bad");
    dpResult.textContent = text || "";
  }

  if (dpFile && dpFileLabel) {
    dpFile.addEventListener("change", function () {
      var file = dpFile.files && dpFile.files[0];
      dpFileLabel.textContent = file ? file.name : "Select package";
    });
  }

  if (dpForm) {
    dpForm.addEventListener("submit", function (ev) {
      ev.preventDefault();
      if (!dpFile || !dpFile.files || !dpFile.files.length) {
        setDpResult("bad", "Select a TAK connection package first.");
        return;
      }
      var body = new FormData();
      body.append("package", dpFile.files[0]);
      if (dpSubmit) dpSubmit.disabled = true;
      setDpResult("ok", "Uploading...");
      fetch("/cgi-bin/aryaos-tak-dp-upload", {
        method: "POST",
        body: body,
        credentials: "same-origin",
        cache: "no-store",
      })
        .then(function (r) {
          return r.json().then(function (payload) {
            if (!r.ok || !payload.ok) {
              throw new Error(payload && payload.error ? payload.error : "HTTP " + r.status);
            }
            return payload;
          });
        })
        .then(function (payload) {
          setDpResult("ok", "Imported " + (payload.cot_url || "TAK Server connection") + ".");
          loadStatus();
        })
        .catch(function (e) {
          setDpResult("bad", e && e.message ? e.message : "Upload failed.");
        })
        .finally(function () {
          if (dpSubmit) dpSubmit.disabled = false;
        });
    });
  }

  var errEl = document.getElementById("aos-status-error");
  var gpsErrEl = document.getElementById("aos-gps-error");
  var takErrEl = document.getElementById("aos-tak-error");

  var TAK_STATE_CLASSES = [
    "aos-tak--up",
    "aos-tak--down",
    "aos-tak--degraded",
    "aos-tak--absent",
    "aos-tak--disabled",
    "aos-tak--pending",
    "aos-tak--unavailable",
  ];

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

  var PILL_CLASSES = ["aos-pill--pending", "aos-pill--ok", "aos-pill--warn", "aos-pill--bad"];

  function setGpsStatusPill(g) {
    var el = document.getElementById("aos-gps-status-pill");
    if (!el) return;
    PILL_CLASSES.forEach(function (c) {
      el.classList.remove(c);
    });
    el.classList.add("aos-pill");
    if (!g) {
      el.classList.add("aos-pill--pending");
      el.title = "";
      return;
    }
    if (!g.ok) {
      el.classList.add("aos-pill--bad");
      el.title = "No GNSS data";
      return;
    }
    if (g.error) {
      el.classList.add("aos-pill--warn");
      el.title = String(g.error);
      return;
    }
    var ft = (g.fix_type != null ? String(g.fix_type) : "").toLowerCase();
    if (ft.indexOf("3d") !== -1 || ft.indexOf("3 d") !== -1) {
      el.classList.add("aos-pill--ok");
      el.title = "3D fix";
      return;
    }
    if (ft.indexOf("2d") !== -1 || ft.indexOf("2 d") !== -1) {
      el.classList.add("aos-pill--warn");
      el.title = "2D fix";
      return;
    }
    el.classList.add("aos-pill--ok");
    el.title = "gpsd reachable";
  }

  function fillGps(g) {
    var ed = document.getElementById("aos-gps-errdetail");
    if (!g) {
      set("aos-gps-status", "no data");
      setGpsStatusPill(null);
      set("aos-gps-fix", "—");
      set("aos-gps-pos", "—");
      set("aos-gps-alt-msl", "—");
      set("aos-gps-alt-hae", "—");
      set("aos-gps-ce-le", "—");
      set("aos-gps-grid", "—");
      set("aos-gps-sats", "—");
      set("aos-gps-time", "—");
      set("aos-gps-motion", "—");
      showGpsErr("");
      if (ed) ed.textContent = "—";
      return;
    }
    var ok = g.ok === true;
    var err = g.error || "";
    set("aos-gps-status", ok ? "gpsd reachable" : "check gpsd / USB");
    setGpsStatusPill(g);
    showGpsErr(g.error || "");

    set("aos-gps-fix", g.fix_type != null ? g.fix_type : "—");
    var la = fmtNum(g.lat, 6);
    var lo = fmtNum(g.lon, 6);
    var posEl = document.getElementById("aos-gps-pos");
    if (posEl) {
      posEl.textContent = la != null && lo != null ? la + ", " + lo : "—";
    }
    var altM = fmtNum(g.alt_m, 1);
    set("aos-gps-alt-msl", altM != null ? altM + " m" : "—");
    var altH = fmtNum(g.alt_hae_m, 1);
    set("aos-gps-alt-hae", altH != null ? altH + " m" : "—");

    var ce = fmtNum(g.ce_m, 1);
    var le = fmtNum(g.le_m, 1);
    var ceLe = "—";
    if (ce != null && le != null) {
      ceLe = ce + " m CE / " + le + " m LE";
    } else if (ce != null) {
      ceLe = ce + " m CE / — m LE";
    } else if (le != null) {
      ceLe = "— m CE / " + le + " m LE";
    }
    set("aos-gps-ce-le", ceLe);

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

  function showTakErr(msg) {
    if (!takErrEl) return;
    if (!msg) {
      takErrEl.classList.add("uk-hidden");
      takErrEl.textContent = "";
      return;
    }
    takErrEl.classList.remove("uk-hidden");
    takErrEl.textContent = msg;
  }

  function setTakChipState(chipEl, state, title) {
    if (!chipEl) return;
    TAK_STATE_CLASSES.forEach(function (c) {
      chipEl.classList.remove(c);
    });
    var cls =
      state === "up"
        ? "aos-tak--up"
        : state === "down"
          ? "aos-tak--down"
          : state === "degraded"
            ? "aos-tak--degraded"
            : state === "absent"
              ? "aos-tak--absent"
              : state === "disabled"
                ? "aos-tak--disabled"
                : state === "unavailable"
                  ? "aos-tak--unavailable"
                  : "aos-tak--pending";
    chipEl.classList.add(cls);
    if (title != null && title !== "") {
      chipEl.setAttribute("title", String(title));
    }
  }

  function fillTakGateways(tg) {
    var ids = ["adsbcot", "aiscot", "dronecot", "sikw00fcot"];
    if (!tg || tg.ok === false) {
      showTakErr(tg && tg.error ? tg.error : "TAK gateway status unavailable.");
      ids.forEach(function (id) {
        setTakChipState(document.getElementById("aos-tak-chip-" + id), "unavailable", id);
      });
      return;
    }
    showTakErr("");
    var items = tg.items || [];
    var byId = {};
    items.forEach(function (it) {
      if (it && it.id) byId[it.id] = it;
    });
    ids.forEach(function (id) {
      var it = byId[id];
      var chip = document.getElementById("aos-tak-chip-" + id);
      if (!it) {
        setTakChipState(chip, "unavailable", id + " (no data)");
        return;
      }
      setTakChipState(chip, it.state, it.title || id);
    });
  }

  function setPowerPill(throttle) {
    var el = document.getElementById("aos-sys-power-pill");
    if (!el) return;
    PILL_CLASSES.forEach(function (c) {
      el.classList.remove(c);
    });
    el.classList.add("aos-pill");
    if (!throttle) {
      el.classList.add("aos-pill--pending");
      el.textContent = "…";
      el.title = "";
      return;
    }
    var state = throttle.state || "ok";
    var current = throttle.current || [];
    var history = throttle.history || [];
    var tip = [];
    if (current.length) tip.push("Now: " + current.join("; "));
    if (history.length) tip.push("Since boot: " + history.join("; "));
    el.title = tip.join(" ") || "No throttling issues";

    if (state === "bad") {
      el.classList.add("aos-pill--bad");
      el.textContent = current.length ? current[0] : "Throttled";
      return;
    }
    if (state === "warn") {
      el.classList.add("aos-pill--warn");
      el.textContent = current.length ? current[0] : history.length ? "Past issue" : "Caution";
      return;
    }
    el.classList.add("aos-pill--ok");
    el.textContent = "OK";
  }

  function fillSystem(s) {
    if (!s) {
      set("aos-sys-temp", "—");
      set("aos-sys-load", "—");
      setPowerPill(null);
      return;
    }
    var temp = s.cpu_temp_c;
    set(
      "aos-sys-temp",
      temp != null && isFinite(Number(temp)) ? fmtNum(temp, 1) + " °C" : "—"
    );
    var load = s.load;
    if (load && load["1"] != null) {
      var l1 = fmtNum(load["1"], 2);
      var l5 = fmtNum(load["5"], 2);
      var l15 = fmtNum(load["15"], 2);
      set(
        "aos-sys-load",
        l1 + " / " + (l5 != null ? l5 : "—") + " / " + (l15 != null ? l15 : "—")
      );
    } else {
      set("aos-sys-load", "—");
    }
    setPowerPill(s.throttle || null);
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

  function truthy(v) {
    return v === true || v === "true" || v === "1" || v === 1;
  }

  function fmtAge(seconds) {
    var n = Number(seconds);
    if (!isFinite(n) || n < 0) return "—";
    if (n < 60) return Math.round(n) + "s";
    if (n < 3600) return Math.round(n / 60) + "m";
    return Math.round(n / 3600) + "h";
  }

  function roleText(roles) {
    var out = [];
    if (truthy(roles && roles.adsb)) out.push("ADS-B");
    if (truthy(roles && roles.ais)) out.push("AIS");
    if (truthy(roles && roles.uas)) out.push("UAS");
    return out.length ? out.join(" / ") : "base";
  }

  function healthText(item) {
    var sys = item.system || {};
    var svc = item.services || {};
    var parts = [];
    if (sys.load1) parts.push("load " + sys.load1);
    if (sys.mem_pct) parts.push("mem " + sys.mem_pct + "%");
    if (sys.temp_c) parts.push(sys.temp_c + " °C");
    var active = Object.keys(svc).filter(function (k) { return svc[k] === "active"; }).length;
    var total = Object.keys(svc).length;
    if (total) parts.push(active + "/" + total + " svc");
    return parts.join(" · ") || "—";
  }

  function positionText(point) {
    if (!point) return "—";
    var ce = Number(point.ce);
    var le = Number(point.le);
    if (ce >= 999000 || le >= 999000) return "no fix";
    var lat = fmtNum(point.lat, 4);
    var lon = fmtNum(point.lon, 4);
    if (lat == null || lon == null) return "—";
    return lat + ", " + lon;
  }

  function fillNeighbors(n) {
    var err = document.getElementById("aos-neighbors-error");
    var empty = document.getElementById("aos-neighbors-empty");
    var table = document.getElementById("aos-neighbor-table");
    var tbody = document.getElementById("aos-neighbors-tbody");
    if (!empty || !table || !tbody) return;
    tbody.innerHTML = "";
    if (err) {
      err.classList.add("uk-hidden");
      err.textContent = "";
    }
    if (!n || n.ok === false) {
      if (err) {
        err.textContent = n && n.error ? n.error : "Neighbor cache unavailable.";
        err.classList.remove("uk-hidden");
      }
      empty.textContent = "No AryaOS neighbor data available.";
      empty.classList.remove("uk-hidden");
      table.classList.add("uk-hidden");
      return;
    }
    var items = n.items || [];
    if (!items.length) {
      empty.textContent = "Listening for AryaOS CoT beacons…";
      empty.classList.remove("uk-hidden");
      table.classList.add("uk-hidden");
      return;
    }
    empty.classList.add("uk-hidden");
    table.classList.remove("uk-hidden");
    items.forEach(function (item) {
      var host = item.host || {};
      var tr = document.createElement("tr");
      var admin = host.admin_url || "";
      var cells = [
        host.name || item.uid || item.source_ip || "—",
        roleText(item.roles || {}),
        healthText(item),
        positionText(item.point || {}),
        fmtAge(item.age_s),
      ];
      cells.forEach(function (text) {
        var td = document.createElement("td");
        td.textContent = text != null && text !== "" ? String(text) : "—";
        tr.appendChild(td);
      });
      var td = document.createElement("td");
      if (admin) {
        var a = document.createElement("a");
        a.href = admin;
        a.textContent = "Open";
        a.rel = "noopener noreferrer";
        td.appendChild(a);
      } else {
        td.textContent = "—";
      }
      tr.appendChild(td);
      tbody.appendChild(tr);
    });
  }

  var api = "/cgi-bin/aryaos-portal-status";
  var neighborsApi = "/cgi-bin/aryaos-neighbors";
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
        fillTakGateways(d.tak_gateways != null ? d.tak_gateways : null);
        fillSystem(d.system != null ? d.system : null);
      })
      .catch(function (e) {
        showErr("Could not load status from " + api + ". " + (e && e.message ? e.message : ""));
        fillRadios(null);
        fillGps(null);
        fillTakGateways(null);
        fillSystem(null);
      });
  }

  function loadNeighbors() {
    fetch(neighborsApi, { credentials: "same-origin", cache: "no-store" })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (d) {
        fillNeighbors(d);
      })
      .catch(function (e) {
        fillNeighbors({ ok: false, error: e && e.message ? e.message : "Neighbor fetch failed." });
      });
  }

  loadStatus();
  loadNeighbors();
  setInterval(loadStatus, 8000);
  setInterval(loadNeighbors, 8000);
})();
