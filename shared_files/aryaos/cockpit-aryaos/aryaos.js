/*
 * AryaOS Site — site-wide TAK configuration Cockpit plugin.
 * Edits /etc/aryaos/aryaos-config.txt (inherited by every PyTAK gateway via
 * EnvironmentFile), installs site-wide TLS certs, restarts the sensor fleet.
 *
 * Copyright Sensors & Signals LLC https://www.snstac.com/
 * SPDX-License-Identifier: Apache-2.0
 */
/* global cockpit */
"use strict";

const CONFIG_PATH = "/etc/aryaos/aryaos-config.txt";
const TLS_DIR = "/etc/aryaos/tls";
const TLS_GROUP = "tak-certs";
// Gateways shown in the services card and restarted on save. AOS_SERVICES in
// the site config wins when set.
const DEFAULT_SERVICES = ["charontak", "adsbcot", "aiscot", "dronecot", "lincot", "dhbridge", "readsb", "ais-catcher"];

const $ = (id) => document.getElementById(id);
const configFile = cockpit.file(CONFIG_PATH, { superuser: "try" });
let configText = "";

function setStatus(el, msg, ok) {
    el.textContent = msg;
    el.className = "aos-status " + (ok ? "ok" : "err");
    if (ok) setTimeout(() => { el.textContent = ""; }, 6000);
}

/* --- KEY=VALUE editing that preserves comments and unknown lines --- */
function getKey(text, key) {
    const m = text.match(new RegExp("^" + key + "=(.*)$", "m"));
    if (!m) return null;
    return m[1].replace(/^["']|["']$/g, "");
}

function setKey(text, key, value) {
    const line = key + "=" + value;
    const re = new RegExp("^#?\\s*" + key + "=.*$", "m");
    if (re.test(text)) return text.replace(re, line);
    return text.replace(/\n*$/, "\n") + line + "\n";
}

function serviceList(text) {
    const raw = getKey(text || "", "AOS_SERVICES");
    if (!raw) return DEFAULT_SERVICES;
    return raw.trim().split(/\s+/);
}

/* --- Config card --- */
function renderForm(text) {
    $("cot-url").value = getKey(text, "COT_URL") || "";
    const dec = getKey(text, "ARYAOS_ADSB_DECODER");
    if (dec) $("adsb-decoder").value = dec;
    $("uat-serial").value = getKey(text, "ARYAOS_UAT_RTL_SERIAL") || "";
    $("tls-dont-verify").checked = (getKey(text, "PYTAK_TLS_DONT_VERIFY") || "") === "1";
    $("raw-config").value = text;
}

function collectForm(text) {
    let out = $("raw-config").value !== configText ? $("raw-config").value : text;
    out = setKey(out, "COT_URL", $("cot-url").value.trim());
    if ($("adsb-decoder").value) out = setKey(out, "ARYAOS_ADSB_DECODER", $("adsb-decoder").value);
    if ($("uat-serial").value.trim()) out = setKey(out, "ARYAOS_UAT_RTL_SERIAL", $("uat-serial").value.trim());
    if ($("tls-dont-verify").checked) out = setKey(out, "PYTAK_TLS_DONT_VERIFY", "1");
    else if (getKey(out, "PYTAK_TLS_DONT_VERIFY") !== null) out = setKey(out, "PYTAK_TLS_DONT_VERIFY", "0");
    return out;
}

function saveConfig(restart) {
    const next = collectForm(configText);
    const el = $("save-status");
    cockpit.file(CONFIG_PATH, { superuser: "require" }).replace(next)
        .then(() => {
            configText = next;
            renderForm(next);
            if (!restart) {
                setStatus(el, "Saved.", true);
                return;
            }
            const units = serviceList(next);
            return cockpit.spawn(["systemctl", "try-restart", "--"].concat(units),
                { superuser: "require", err: "message" })
                .then(() => setStatus(el, "Saved; sensor services restarted.", true))
                .then(refreshServices);
        })
        .catch((ex) => setStatus(el, "Failed: " + (ex.message || ex), false));
}

/* --- TLS card --- */
function readPem(input, label) {
    return new Promise((resolve, reject) => {
        const f = input.files && input.files[0];
        if (!f) return resolve(null);
        const r = new FileReader();
        r.onerror = () => reject(new Error("could not read " + label));
        r.onload = () => {
            const text = String(r.result);
            if (!text.includes("-----BEGIN"))
                return reject(new Error(label + " is not PEM (convert .p12 with openssl pkcs12 first)"));
            resolve(text);
        };
        r.readAsText(f);
    });
}

function installTls() {
    const el = $("tls-status");
    Promise.all([
        readPem($("tls-cert"), "client certificate"),
        readPem($("tls-key"), "client key"),
        readPem($("tls-ca"), "CA chain"),
    ]).then(([cert, key, ca]) => {
        if (!cert && !key && !ca)
            throw new Error("choose at least one PEM file");
        if ((cert && !key && !tlsConfigured("KEY")) || (key && !cert && !tlsConfigured("CERT")))
            throw new Error("client certificate and key must both be present");

        const writes = [];
        const put = (name, content, mode) => {
            const path = TLS_DIR + "/" + name;
            writes.push(() =>
                cockpit.file(path, { superuser: "require" }).replace(content)
                    .then(() => cockpit.spawn(
                        ["/bin/sh", "-c",
                         "chmod " + mode + " '" + path + "'; " +
                         "chgrp " + TLS_GROUP + " '" + path + "' 2>/dev/null || true"],
                        { superuser: "require", err: "message" })));
            return path;
        };

        let next = configText;
        if (cert) next = setKey(next, "PYTAK_TLS_CLIENT_CERT", put("client.pem", cert, "0644"));
        if (key) next = setKey(next, "PYTAK_TLS_CLIENT_KEY", put("client.key", key, "0640"));
        if (ca) next = setKey(next, "PYTAK_TLS_CLIENT_CAFILE", put("ca.pem", ca, "0644"));

        return cockpit.spawn(["mkdir", "-p", TLS_DIR], { superuser: "require", err: "message" })
            .then(() => writes.reduce((p, w) => p.then(w), Promise.resolve()))
            .then(() => cockpit.file(CONFIG_PATH, { superuser: "require" }).replace(next))
            .then(() => {
                configText = next;
                renderForm(next);
                setStatus(el, "Certificates installed. Save & restart sensors to apply.", true);
                showCurrentTls();
            });
    }).catch((ex) => setStatus(el, "Failed: " + (ex.message || ex), false));
}

function tlsConfigured(which) {
    return getKey(configText, "PYTAK_TLS_CLIENT_" + which) !== null;
}

function showCurrentTls() {
    cockpit.spawn(["ls", "-l", TLS_DIR], { superuser: "try", err: "ignore" })
        .then((out) => {
            const files = out.split("\n").filter((l) => l.includes(".pem") || l.includes(".key"));
            $("tls-current").textContent = files.length
                ? "Installed: " + files.map((l) => l.trim().split(/\s+/).pop()).join(", ")
                : "";
        })
        .catch(() => { $("tls-current").textContent = ""; });
}

/* --- Services card --- */
function refreshServices() {
    const units = serviceList(configText);
    const tbody = $("svc-table").querySelector("tbody");
    tbody.innerHTML = "";
    units.forEach((u) => {
        const tr = document.createElement("tr");
        const dot = document.createElement("span");
        dot.className = "aos-dot unknown";
        const tdDot = document.createElement("td");
        tdDot.appendChild(dot);
        tdDot.appendChild(document.createTextNode(u));
        const tdState = document.createElement("td");
        tr.appendChild(tdDot);
        tr.appendChild(tdState);
        tbody.appendChild(tr);
        cockpit.spawn(["systemctl", "is-active", u + ".service"], { err: "ignore" })
            .then((out) => { dot.className = "aos-dot active"; tdState.textContent = out.trim(); })
            .catch((ex) => {
                const state = (ex.message || "").trim() || "not installed";
                dot.className = state === "inactive" || state === "failed" ? "aos-dot inactive" : "aos-dot unknown";
                tdState.textContent = state;
            });
    });
}

/* --- init --- */
configFile.watch((content) => {
    configText = content || "";
    renderForm(configText);
    refreshServices();
    showCurrentTls();
});
$("btn-save").addEventListener("click", () => saveConfig(true));
$("btn-save-only").addEventListener("click", () => saveConfig(false));
$("btn-tls-upload").addEventListener("click", installTls);
