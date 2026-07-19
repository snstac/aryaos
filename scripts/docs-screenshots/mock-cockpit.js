/* Minimal mock of the Cockpit JS API — enough to render cockpit-aryaos with
   representative data for documentation screenshots. NOT a real backend. */
(function () {
  const CONFIG = `# AryaOS site configuration (demo)
COT_URL=udp+wo://127.0.0.1:28087
ARYAOS_ADSB_DECODER=readsb
ARYAOS_UAT_RTL_SERIAL=stx:978:0
ARYAOS_ROLE=multi
PYTAK_TLS_CLIENT_CERT=/etc/aryaos/tls/client.pem
PYTAK_TLS_CLIENT_KEY=/etc/aryaos/tls/client.key
PYTAK_TLS_CLIENT_CAFILE=/etc/aryaos/tls/ca.pem
DEVICE_SUFFIX=a1b2
COT_HOST_ID=aryaos-a1b2
AOS_SERVICES="charontak gpstak aiscot lincot adsbcot dronecot"
`;
  function proc(stdout) {
    const p = Promise.resolve(stdout || "");
    p.stream = (cb) => { if (stdout) cb(stdout); return p; };
    p.input = () => p; p.done = (cb) => { p.then(cb); return p; };
    p.fail = () => p; p.close = () => {};
    return p;
  }
  function has(a, s) { return a.some((x) => String(x).indexOf(s) !== -1); }
  function spawn(argv) {
    const a = argv.map(String);
    if (has(a, "aryaos-role") && has(a, "list"))
      return proc(JSON.stringify({ current: "multi", roles: {
        multi: { units: ["readsb","dump978-fa","adsbcot","gdltak","ais-catcher","aiscot","dronecot","sikw00fcot"] },
        air: { units: ["readsb","dump978-fa","adsbcot","gdltak"] },
        maritime: { units: ["ais-catcher","aiscot"] },
        cuas: { units: ["dronecot","sikw00fcot"] },
        relay: { units: [] } } }));
    if (has(a, "aryaos-sdr") && has(a, "list"))
      return proc(JSON.stringify({ devices: [
        { index: 0, vendor: "Realtek", product: "RTL2838UHIDIR", serial: "stx:1090:0" },
        { index: 1, vendor: "Realtek", product: "RTL2838UHIDIR", serial: "stx:978:0" } ] }));
    if (has(a, "tailscale") && has(a, "status"))
      return proc(JSON.stringify({ BackendState: "Running", TailscaleIPs: ["100.72.14.3"],
        Self: { DNSName: "aryaos-a1b2.tail9f2c.ts.net." } }));
    if (has(a, "aryaos-config-backup") && has(a, "list"))
      return proc(JSON.stringify({ backups: [] }));
    if (has(a, "is-active")) return proc("active");
    if (has(a, "systemctl") && has(a, "status"))
      return proc("● " + (a[2]||"service") + " - AryaOS gateway\n   Loaded: loaded (enabled)\n   Active: active (running)\n");
    if (has(a, "ls")) return proc("client.pem\nclient.key\nca.pem\n");
    if (has(a, "aryaos-update") || has(a, "check")) return proc(JSON.stringify({ upgradable: [] }));
    return proc("");
  }
  function file(path, opts) {
    opts = opts || {};
    let content = "";
    if (path === "/etc/aryaos/aryaos-config.txt") content = CONFIG;
    else if (path === "/etc/hostname") content = "aryaos-a1b2\n";
    const parsed = () => (opts.syntax ? (content ? JSON.parse(content) : null) : content);
    return {
      read: () => Promise.resolve(path.indexOf("config.txt") >= 0 || path === "/etc/hostname" ? content : null),
      replace: () => Promise.resolve("tag"),
      watch: (cb) => { setTimeout(() => cb(content, "tag", null), 30); return { remove() {}, close() {} }; },
      close: () => {},
    };
  }
  window.cockpit = {
    spawn, file,
    gettext: (s) => s,
    dbus: () => ({ call: () => Promise.reject(new Error("no dbus in mock")) }),
    transport: { host: "aryaos-a1b2" },
    format: (s) => s,
  };
})();
