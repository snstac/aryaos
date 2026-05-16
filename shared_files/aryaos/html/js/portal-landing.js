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
    if (!btn.dataset.copySaved) {
      btn.dataset.copySaved = btn.textContent || "Copy";
    }
    var saved = btn.dataset.copySaved;
    copyTextToClipboard(text).then(function (ok) {
        btn.textContent = ok ? "Copied" : "Failed";
        setTimeout(function () {
          btn.textContent = saved;
        }, 1500);
      });
  });

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

  function fillGps(g) {
    var ed = document.getElementById("aos-gps-errdetail");
    if (!g) {
      set("aos-gps-status", "no data");
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
    var ids = ["adsbcot", "aiscot", "dronecot"];
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
        fillTakGateways(d.tak_gateways != null ? d.tak_gateways : null);
      })
      .catch(function (e) {
        showErr("Could not load status from " + api + ". " + (e && e.message ? e.message : ""));
        fillRadios(null);
        fillGps(null);
        fillTakGateways(null);
      });
  }
  loadStatus();
  setInterval(loadStatus, 8000);
})();
