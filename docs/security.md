# Security posture

AryaOS devices are field appliances. An operator wearing gloves must be able
to administer them through Cockpit. They must survive hostile LANs and support
recovery without key material. The hardening below reflects those
trade-offs. Everything ships in both dev/lab and release images - the two
flavors differ only in *access* (lab SSH key, passwordless sudo, password
expiry), never in posture.

## Access

- **Authorized-use notices** are shown before authentication over SSH
  (`/etc/issue.net`), on local consoles (`/etc/issue`), after login
  (`/etc/motd`), and persistently on the HTTPS landing page. The notice states
  that access is restricted and activity can be monitored, recorded, and
  audited. This is CMMC-aligned preparatory language, not a claim that a
  particular deployment is CMMC certified or compliant.
- **Default password** (`pi` / published) is force-expired at first login on
  release images (`chage -d 0`, `aryaos-firstboot.sh`).
- **sshd** (`/etc/ssh/sshd_config.d/50-aryaos.conf`): root login disabled,
  empty passwords disabled, `MaxAuthTries 4`, `LoginGraceTime 30`, no X11
  forwarding. Password authentication stays **enabled** by design - field
  operators can have no keys. See the default-password expiry above.
- **fail2ban** (`/etc/fail2ban/jail.d/aryaos.local`): sshd jail, systemd
  backend, 15 min bans. Bluetooth PAN clients (`10.44.0.0/24`) are never
  banned - that is the operator standing next to the box.
- **sudo** is fully logged (JSON I/O logging, `/etc/sudoers.d/aryaos`). No
  NOPASSWD on release images (asserted by `scripts/verify-image.sh`).

## Network

- **firewalld** is enabled with an explicit inbound allowlist in the default
  zone (`/etc/firewalld/zones/public.xml`): SSH, HTTP/HTTPS (portal +
  Cockpit proxy), mDNS, DHCP/DNS (comitup hotspot + Bluetooth PAN leases),
  Mesh SA multicast (`6969/udp`), GutCheck identity discovery (`1900/udp`),
  AIS-catcher dashboard (`8100`), and comitup onboarding (`9080`). Custom service
  definitions live in `/etc/firewalld/services/aryaos-*.xml`.
- Operators manage the firewall in **Cockpit > Networking > Firewall** (no
  shell needed).
- The AntSDR point-to-point link (`eth1`, `aryaos-antsdr.nmconnection`) is in
  the **trusted** zone. This lets the sensor reach the `dronecot-dji` listener.
- Docker-published ports (CloudTAK, UAS broker) are governed by Docker's own
  firewalld integration, not the public zone.
- **cockpit-ws** binds loopback only. Lighttpd terminates TLS on `:443` and
  proxies `/admin`.
- **sysctl** (`/etc/sysctl.d/90-aryaos-hardening.conf`): no ICMP redirects,
  no source routing, loose RPF (multi-homed + multicast), syncookies, kptr/
  dmesg restricted, unprivileged eBPF off.

## TLS keys

- pi-gen deletes SSH host keys at image build. They regenerate per device on
  first boot.
- The web (portal/Cockpit) TLS key is also **regenerated per device** at
  first boot (`aryaos-firstboot.sh`, marker
  `/etc/aryaos/.web-tls-regenerated`) - published images no longer share one
  snakeoil key across the fleet.
- Site TAK TLS material lives in `/etc/aryaos/tls` (`root:tak-certs`, key
  `0640`, dir `0750`). The Node-RED user owns only the site config file, not
  the TLS directory.

## Updates

- **Debian security fixes install automatically** every day
  (`unattended-upgrades`, `/etc/apt/apt.conf.d/52unattended-upgrades-aryaos`).
  No automatic reboots. The snstac sensor stack is *not* auto-upgraded -
  restarting sensors mid-operation is an operator decision.
- **One-click updates**: Cockpit > AryaOS Site > *Software updates* checks
  and installs everything (sensor stack included) from the signed
  [snstac apt repository](https://snstac.github.io/packages). The backend is
  `/usr/local/sbin/aryaos-update` (`check|apply|status`) run under
  `aryaos-update.service`, so an upgrade survives a closed browser session.
  `readsb` stays on `apt-mark hold` and is reported as held.
- Per-package operations: Cockpit > Software updates (PackageKit).

## Node-RED admin password

Node-RED ships with a publicly known default admin password (`aryaos415`).
The editor can run arbitrary code as the `node-red` user. **Change the password before
fielding a unit**. Cockpit > AryaOS Site > *Node-RED admin password* does
this in the browser. The backend is
`/usr/local/sbin/aryaos-set-nodered-password` (reads the new password on
stdin, bcrypt-hashes it with Node-RED's bundled bcryptjs, rewrites the
`adminAuth` entry in `settings.js`, restarts Node-RED).

## Support bundles

Cockpit > AryaOS Site > *Support bundle* generates a downloadable diagnostics
tarball via `/usr/local/sbin/aryaos-support-bundle`: system/package/service
state, capped journals, network and firewall state, and sensor-gateway
configs. Values of keys matching `PASSWORD/TOKEN/SECRET/PASSPHRASE/PSK` and
`tak://` enrollment credentials are redacted. Nothing from `/etc/aryaos/tls`
or other private key material is included. Bundles land in
`/var/lib/aryaos/support/` (`0600`, three newest kept).

## Decommissioning

AryaOS provides two teardown levels for reassignment, retirement, or capture.
If you need the configuration, **[back it up](operations/backup-restore.md)
first**. Store full backups securely because they contain private keys and Wi-Fi PSKs.

- **[Factory reset](operations/factory-reset.md)**
  (`/usr/local/sbin/aryaos-factory-reset`) - restores config to packaged
  defaults, deletes uploaded TAK certs, clears device identity so first boot
  re-runs, and reboots. Keeps the OS, packages, and (by default) the network.
  This is for **re-use**. It does **not** securely erase anything.
- **[Zeroize](operations/zeroize.md)** (`/usr/local/sbin/aryaos-zeroize`) - for
  **decommission or capture**. It erases keys, credentials, logs, tracks, and
  identity. It restores defaults, removes access, cleans free space, and
  reboots. The Cockpit card requires a typed confirmation phrase.

!!! danger "Zeroize is best-effort on flash media"
    Wear-leveling on microSD/eMMC/NVMe means overwrite and TRIM **cannot
    guarantee** prior contents are unrecoverable - the controller can have
    written data to blocks software cannot reach. For a hard guarantee, use
    full-disk encryption with crypto-erase (roadmap) or physically destroy the
    media. See [Zeroize](operations/zeroize.md).

## Enforcement

`scripts/verify-image.sh` loop-mounts every built image and asserts this
contract (packages, config files, enabled units, lab/release access split)
before CI publishes anything. Runtime checks live in
`scripts/aryaos-test/tests/09-security.sh` and run against a live unit via
`ARYAOS_SSH=pi@<host> ./scripts/aryaos-test/run.sh`.
