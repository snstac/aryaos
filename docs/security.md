# Security posture

AryaOS units are field appliances: they must be administrable through a
browser (Cockpit) by an operator wearing gloves, survive hostile LANs, and
still be recoverable without key material. The hardening below reflects those
trade-offs. Everything ships in both dev/lab and release images — the two
flavors differ only in *access* (lab SSH key, passwordless sudo, password
expiry), never in posture.

## Access

- **Default password** (`pi` / published) is force-expired at first login on
  release images (`chage -d 0`, `aryaos-firstboot.sh`).
- **sshd** (`/etc/ssh/sshd_config.d/50-aryaos.conf`): root login disabled,
  empty passwords disabled, `MaxAuthTries 4`, `LoginGraceTime 30`, no X11
  forwarding. Password authentication stays **enabled** by design — field
  operators may have no keys; see the default-password expiry above.
- **fail2ban** (`/etc/fail2ban/jail.d/aryaos.local`): sshd jail, systemd
  backend, 15 min bans. Bluetooth PAN clients (`10.44.0.0/24`) are never
  banned — that is the operator standing next to the box.
- **sudo** is fully logged (JSON I/O logging, `/etc/sudoers.d/aryaos`); no
  NOPASSWD on release images (asserted by `scripts/verify-image.sh`).

## Network

- **firewalld** is enabled with an explicit inbound allowlist in the default
  zone (`/etc/firewalld/zones/public.xml`): SSH, HTTP/HTTPS (portal +
  Cockpit proxy), mDNS, DHCP/DNS (comitup hotspot + Bluetooth PAN leases),
  Mesh SA multicast (`6969/udp`), Node-RED (`1880`, adminAuth-protected),
  AIS-catcher dashboard (`8100`), comitup onboarding (`9080`). Custom service
  definitions live in `/etc/firewalld/services/aryaos-*.xml`.
- Operators manage the firewall in **Cockpit → Networking → Firewall** (no
  shell needed).
- The AntSDR point-to-point link (`eth1`, `aryaos-antsdr.nmconnection`) is in
  the **trusted** zone so the sensor can reach the dronecot listener.
- Docker-published ports (CloudTAK, UAS broker) are governed by Docker's own
  firewalld integration, not the public zone.
- **cockpit-ws** binds loopback only; lighttpd terminates TLS on `:443` and
  proxies `/admin`.
- **sysctl** (`/etc/sysctl.d/90-aryaos-hardening.conf`): no ICMP redirects,
  no source routing, loose RPF (multi-homed + multicast), syncookies, kptr/
  dmesg restricted, unprivileged eBPF off.

## TLS keys

- pi-gen deletes SSH host keys at image build; they regenerate per device on
  first boot.
- The web (portal/Cockpit) TLS key is also **regenerated per device** at
  first boot (`aryaos-firstboot.sh`, marker
  `/etc/aryaos/.web-tls-regenerated`) — published images no longer share one
  snakeoil key across the fleet.
- Site TAK TLS material lives in `/etc/aryaos/tls` (`root:tak-certs`, key
  `0640`, dir `0750`). The Node-RED user owns only the site config file, not
  the TLS directory.

## Updates

- **Debian security fixes install automatically** every day
  (unattended-upgrades; `/etc/apt/apt.conf.d/52unattended-upgrades-aryaos`).
  No automatic reboots. The snstac sensor stack is *not* auto-upgraded —
  restarting sensors mid-operation is an operator decision.
- **One-click updates**: Cockpit → AryaOS Site → *Software updates* checks
  and installs everything (sensor stack included) from the signed
  [snstac apt repository](https://snstac.github.io/packages). The backend is
  `/usr/local/sbin/aryaos-update` (`check|apply|status`) run under
  `aryaos-update.service`, so an upgrade survives a closed browser session.
  `readsb` stays on `apt-mark hold` and is reported as held.
- Per-package operations: Cockpit → Software updates (PackageKit).

## Node-RED admin password

Node-RED ships with a publicly known default admin password (`aryaos415`) and
the editor can run arbitrary code as the `node-red` user — **rotate it before
fielding a unit**. Cockpit → AryaOS Site → *Node-RED admin password* does
this in the browser; the backend is
`/usr/local/sbin/aryaos-set-nodered-password` (reads the new password on
stdin, bcrypt-hashes it with Node-RED's bundled bcryptjs, rewrites the
`adminAuth` entry in `settings.js`, restarts Node-RED).

## Support bundles

Cockpit → AryaOS Site → *Support bundle* generates a downloadable diagnostics
tarball via `/usr/local/sbin/aryaos-support-bundle`: system/package/service
state, capped journals, network and firewall state, and sensor-gateway
configs. Values of keys matching `PASSWORD/TOKEN/SECRET/PASSPHRASE/PSK` and
`tak://` enrollment credentials are redacted; nothing from `/etc/aryaos/tls`
or other private key material is included. Bundles land in
`/var/lib/aryaos/support/` (`0600`, three newest kept).

## Enforcement

`scripts/verify-image.sh` loop-mounts every built image and asserts this
contract (packages, config files, enabled units, lab/release access split)
before CI publishes anything. Runtime checks live in
`scripts/aryaos-test/tests/09-security.sh` and run against a live unit via
`ARYAOS_SSH=pi@<host> ./scripts/aryaos-test/run.sh`.
