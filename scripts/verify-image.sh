#!/bin/bash
# verify-image.sh — loop-mount a built AryaOS image and assert expected contents.
#
# Usage: sudo scripts/verify-image.sh [--lab] <image>.img|.img.xz|.zip
#
#   --lab   Expect lab access (ARYAOS_LAB_ACCESS=1 build): dev SSH key and
#           aryaos-lab sudoers PRESENT. Default expects a release image where
#           both are ABSENT.
#
# Catches a class of regressions the build itself can't: a stage that silently
# skipped an install (bad SHARED_FILES, missing deb, sed no-op) still exits 0,
# but the artifact is broken. Run from CI after the image build, or locally
# against pi-gen deploy output.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

LAB_EXPECTED=0
if [[ "${1:-}" == "--lab" ]]; then
	LAB_EXPECTED=1
	shift
fi

IMAGE="${1:-}"
if [[ -z "${IMAGE}" || ! -f "${IMAGE}" ]]; then
	echo "Usage: sudo $0 [--lab] <image>.img|.img.xz|.zip" >&2
	exit 2
fi
if [[ "$(id -u)" != "0" ]]; then
	echo "Must run as root (loop-mounts the image)." >&2
	exit 2
fi

WORK="$(mktemp -d /tmp/aryaos-verify.XXXXXX)"
MNT="${WORK}/mnt"
LOOP=""
cleanup() {
	set +e
	mountpoint -q "${MNT}/boot/firmware" && umount "${MNT}/boot/firmware"
	mountpoint -q "${MNT}" && umount "${MNT}"
	[[ -n "${LOOP}" ]] && losetup -d "${LOOP}"
	rm -rf "${WORK}"
}
trap cleanup EXIT

case "${IMAGE}" in
	*.zip)
		# python3 zipfile: unzip is not installed everywhere (e.g. minimal build hosts)
		python3 -m zipfile -e "${IMAGE}" "${WORK}/extract"
		IMG="$(find "${WORK}/extract" -name '*.img' -print -quit)"
		;;
	*.img.xz | *.xz)
		IMG="${WORK}/image.img"
		xz -dkc "${IMAGE}" > "${IMG}"
		;;
	*.img)
		IMG="${IMAGE}"
		;;
	*)
		echo "Unsupported image format: ${IMAGE}" >&2
		exit 2
		;;
esac
if [[ -z "${IMG:-}" || ! -f "${IMG}" ]]; then
	echo "No .img found in ${IMAGE}" >&2
	exit 2
fi

LOOP="$(losetup -Pf --show "${IMG}")"
# Partition nodes can lag losetup -P briefly.
for _ in 1 2 3 4 5; do
	[[ -b "${LOOP}p2" ]] && break
	sleep 1
done
mkdir -p "${MNT}"
mount -o ro "${LOOP}p2" "${MNT}"
if [[ -b "${LOOP}p1" ]]; then
	mkdir -p "${MNT}/boot/firmware" 2>/dev/null || true
	mount -o ro "${LOOP}p1" "${MNT}/boot/firmware" 2>/dev/null || true
fi

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "ok:   $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# -L as well as -e: symlinks in the image often point at absolute paths
# (e.g. /etc/lighttpd/conf-available/...), which -e would wrongly resolve
# against the build host's root instead of the mounted image.
require_path() {
	if [[ -e "${MNT}$1" || -L "${MNT}$1" ]]; then ok "$1"; else fail "$1 missing"; fi
}
forbid_path() {
	if [[ ! -e "${MNT}$1" && ! -L "${MNT}$1" ]]; then ok "$1 absent"; else fail "$1 present (must not ship)"; fi
}
require_grep() {
	local pattern="$1" path="$2" label="$3"
	if grep -qsE "${pattern}" "${MNT}${path}"; then
		ok "${label}"
	else
		fail "${label} missing from ${path}"
	fi
}
forbid_grep() {
	local pattern="$1" path="$2" label="$3"
	if grep -qsE "${pattern}" "${MNT}${path}"; then
		fail "${label} — unexpectedly found ${pattern} in ${path}"
	else
		ok "${label}"
	fi
}
require_unit() {
	local u="$1" d
	for d in etc/systemd/system lib/systemd/system usr/lib/systemd/system; do
		if [[ -f "${MNT}/${d}/${u}" ]]; then ok "unit ${u} (${d})"; return; fi
	done
	fail "unit ${u} not found in any systemd unit dir"
}
require_pkg() {
	if awk -v pkg="$1" 'BEGIN{RS=""} $0 ~ "Package: "pkg"\n" && /Status: (install|hold) ok installed/ {found=1} END{exit !found}' \
		"${MNT}/var/lib/dpkg/status" 2>/dev/null; then
		ok "package $1 installed"
	else
		fail "package $1 not installed"
	fi
}
require_pkg_version() {
	local pkg="$1" minimum="$2" version
	version="$(awk -v pkg="${pkg}" 'BEGIN{RS=""} $0 ~ "Package: "pkg"\n" {for (i=1;i<=NF;i++) if ($i=="Version:") {print $(i+1); exit}}' \
		"${MNT}/var/lib/dpkg/status" 2>/dev/null)"
	if [[ -n "${version}" ]] && dpkg --compare-versions "${version}" ge "${minimum}"; then
		ok "package ${pkg} ${version} >= ${minimum}"
	else
		fail "package ${pkg} ${version:-missing} is older than ${minimum}"
	fi
}

echo "== AryaOS image content checks: ${IMG##*/} (lab=${LAB_EXPECTED}) =="

# Core identity and config (stage-aryaos)
# aryaos-overlay must be registered in dpkg (a 644 exec bit on the build
# script once skipped this silently — the [[ -x ]] guard in 00-run.sh).
require_pkg aryaos-overlay
require_path /etc/aryaos-release
require_path /etc/aryaos-version
require_pkg_version aryaos-overlay 2.1.13
require_path /etc/aryaos/aryaos-config.txt
require_path /etc/sudoers.d/aryaos
require_grep '^Defaults maxseq=128$' /etc/sudoers.d/aryaos "sudo I/O audit history bounded for /var/log tmpfs"
require_path /usr/local/sbin/aryaos-firstboot.sh
require_path /usr/local/sbin/aryaos-lincot-remarks
require_path /usr/local/sbin/aryaos-cot-detail
require_grep 'capabilities' /usr/local/sbin/aryaos-cot-detail "beacon advertises capabilities"
require_grep 'decoding' /usr/local/sbin/aryaos-cot-detail "beacon reports decoder activity"
# v4 dropped <product line="...">: it was baked in at build time and identical on
# every box, so it looked authoritative while carrying no information.
forbid_grep '"product"' /usr/local/sbin/aryaos-cot-detail "beacon does not advertise a product line"
forbid_grep '^ARYAOS_PRODUCT=' /etc/aryaos/aryaos-config.txt "no product line baked into the shipped config"
require_path /usr/local/sbin/aryaos-time-pps
require_path /etc/systemd/system/aryaos-time-pps.service
require_path /etc/udev/rules.d/99-aryaos-pps.rules
# Without this line the helper writes a refclock into /run that chrony never
# reads, and the PPS discipline silently does nothing -- which is exactly how
# this feature failed twice already. The /run path is deliberate: a refclock
# naming a not-yet-enumerated device is a FATAL chronyd error, so it must not
# persist across a reboot.
require_grep '^confdir /run/chrony-aryaos$' /etc/chrony/conf.d/aryaos.conf \
	"chrony reads the ephemeral PPS refclock dir"
# The helper must WRITE to /run. It still mentions the /etc path deliberately, to
# migrate it away on boxes from an older build, so assert the write target rather
# than the absence of the string.
require_grep '^CONF="\$\{RUN_DIR\}/' /usr/local/sbin/aryaos-time-pps \
	"PPS refclock is written under /run, not a path that survives reboot"
forbid_grep '^CONF="/etc/' /usr/local/sbin/aryaos-time-pps \
	"PPS refclock target is not in /etc"
require_path /etc/systemd/system/multi-user.target.wants/aryaos-time-pps.service
# Crash-loop guard: a sensor unit that restarts forever never enters `failed`,
# so a start limit is what makes the failure visible at all.
require_path /etc/systemd/system/readsb.service.d/aryaos-startlimit.conf
require_path /etc/systemd/system/adsbcot.service.d/aryaos-startlimit.conf
require_path /usr/local/sbin/aryaos-neighbord
require_path /etc/systemd/system/aryaos-firstboot.service
require_path /etc/systemd/system/aryaos-neighbord.service
require_grep '^COT_URL=udp\+wo://127\.0\.0\.1:28087$' /etc/aryaos/aryaos-config.txt "feeder COT_URL points to cotbridge"

# Portal (stage-aryaos)
require_path /var/www/html/index.html
require_path /usr/lib/cgi-bin/aryaos-portal-status
require_path /usr/lib/cgi-bin/aryaos-neighbors
require_path /usr/share/cockpit/branding/debian/branding.css
require_path /usr/share/cockpit/branding/debian/mark-aryaos-rev.svg
require_path /usr/share/cockpit/branding/default/branding.css
require_path /usr/share/cockpit/branding/default/mark-aryaos-rev.svg
require_grep 'mark-aryaos-rev\.svg' /usr/share/cockpit/branding/debian/branding.css \
	"Cockpit branding uses the canonical AryaOS reverse mark"
require_grep '#E4610F' /usr/share/cockpit/branding/debian/mark-aryaos-rev.svg \
	"Cockpit AryaOS mark uses Signal Orange"
require_path /etc/lighttpd/conf-enabled/95-aryaos-cockpit-https.conf
# The mutating TAK data-package import must NOT be an unauthenticated portal CGI:
# it moved to the authenticated Cockpit backend. Fail the build if the CGI ships
# or the lighttpd config re-exposes it.
forbid_path /usr/lib/cgi-bin/aryaos-tak-dp-upload
require_path /usr/local/sbin/aryaos-tak-dp-import
if grep -qsE 'alias\.url.*aryaos-tak-dp-upload' "${MNT}/etc/lighttpd/conf-available/95-aryaos-cockpit-https.conf"; then
	fail "lighttpd re-exposes the aryaos-tak-dp-upload CGI (unauth TAK takeover)"
else
	ok "TAK data-package import is not exposed as an unauthenticated CGI"
fi

# Offline documentation bundled into the portal (served at /docs/), plus the
# portal link + QR to the online docs.
require_path /var/www/html/docs/index.html
require_path /var/www/html/img/aryaos-docs-qr.svg
require_grep 'href="/docs/"' /var/www/html/index.html "portal links to on-device docs"

# AryaOS Site cockpit plugin (site-wide TAK config + TLS)
require_path /usr/share/cockpit/aryaos/manifest.json
require_path /usr/share/cockpit/aryaos/aryaos.js
require_grep 'id="card-neighbors"' /usr/share/cockpit/aryaos/index.html "cockpit-aryaos neighbor card"
require_grep 'refreshNeighbors' /usr/share/cockpit/aryaos/aryaos.js "cockpit-aryaos neighbor refresh"
require_grep 'id="card-updates"' /usr/share/cockpit/aryaos/index.html "cockpit-aryaos software updates card"
require_grep 'id="card-location"' /usr/share/cockpit/aryaos/index.html "cockpit-aryaos location chip card"
require_path /usr/share/cockpit/aryaos/aryaos-basemap.js
require_grep 'ARYAOS_BASEMAP' /usr/share/cockpit/aryaos/aryaos-basemap.js "cockpit-aryaos offline base map data"
require_grep 'get_throttled' /usr/share/cockpit/aryaos/aryaos.js "cockpit-aryaos power-health indicator"
require_grep 'id="safe-mode-banner"' /usr/share/cockpit/aryaos/index.html "cockpit-aryaos safe-mode banner"

# GPSCOT network GPS (package from stage-pytak)
require_pkg gpscot
require_path /usr/bin/gpscot
require_path /lib/systemd/system/gpscot.service
require_path /etc/default/gpscot
require_path /usr/share/cockpit/gpscot/manifest.json

# cotbridge cockpit page (ships inside the cotbridge deb >= 0.1.12)
require_path /usr/share/cockpit/cotbridge/manifest.json
require_path /etc/cotbridge.ini
require_grep '^\[lane:site-output\]$' /etc/cotbridge.ini "cotbridge site-output lane"
require_grep '^egress_cot_url = udp\+wo://239\.2\.3\.1:6969$' /etc/cotbridge.ini "cotbridge Mesh SA egress"
require_grep '^ingress_cot_url = udp\+ro://127\.0\.0\.1:28087$' /etc/cotbridge.ini "cotbridge site-output local ingress"

# GNSS (stage-aryaos)
require_path /etc/default/gpsd

# snstac apt repository trust anchor (sensor stack installs from it)
require_path /usr/share/keyrings/snstac.gpg
require_path /etc/apt/sources.list.d/snstac.sources

# Bluetooth PAN (stage-bt-pan)
require_path /usr/local/sbin/aryaos-bt-ready.sh
require_path /usr/local/sbin/aryaos-bt-pan-nap
require_unit aryaos-bt-ready.service
require_unit aryaos-bt-pan.service

# dhbridge is private — public images must not ship it or its config
forbid_path /etc/dhbridge.ini
forbid_path /usr/bin/dhbridge
forbid_path /etc/systemd/system/dhbridge.service.d

# Sensor / CoT stack
require_pkg aiscot
require_pkg_version aiscot 7.3.1
require_pkg cockpit-gps
require_pkg cockpit-adsbcot
require_pkg_version cockpit-adsbcot 1.2.3
require_pkg cockpit-aiscot
require_pkg_version cockpit-aiscot 1.2.3
require_pkg cockpit-lincot
require_pkg_version cockpit-lincot 1.1.3
require_pkg cockpit-aiscatcher
require_pkg cockpit-dronecot
require_pkg_version cockpit-dronecot 1.1.3
require_pkg cockpit-cotbridge
require_pkg_version cockpit-cotbridge 1.2.2
require_pkg cockpit-gpscot
require_pkg cockpit-aryaos
require_pkg cockpit-spyserver
require_path /usr/share/cockpit/spyserver/manifest.json
require_pkg readsb
require_pkg python3-gps
require_pkg ais-catcher
require_pkg sikw00fcot
require_pkg_version sikw00fcot 1.0.2
require_pkg gpscot
require_pkg_version gpscot 2.0.1
require_pkg gdlcot
require_pkg_version gdlcot 2.0.1
require_pkg_version pytak 7.5.2
require_pkg_version acarscot 0.1.1
require_pkg acarsdec
require_pkg_version dronecot 2.3.9
require_unit adsbcot.service
require_unit aiscot.service
require_unit dronecot.service
require_unit sikw00fcot.service
require_unit acarscot.service
require_grep '^StateDirectory=acarscot$' /usr/lib/systemd/system/acarscot.service "acarscot enrollment state survives reboot"
require_grep '^Environment=HOME=/var/lib/acarscot$' /usr/lib/systemd/system/acarscot.service "acarscot uses persistent home"
# DroneScout DS101: 2nd dronecot instance (MAVLink Remote ID over serial), opt-in.
# The DS101 is an ESP32-S3 (303a:1001) pinned to /dev/dronescout by udev, NOT a
# CH340 — verified live 2026-07-24 against a DroneBeacon DB120.
require_path /etc/systemd/system/dronecot-dronescout.service
require_grep '/dev/dronescout' /etc/default/dronecot-dronescout "dronecot-dronescout reads the DS101 ESP32-S3 (/dev/dronescout)"
require_grep '^SERIAL_CRLF_NORMALIZE=1$' /etc/default/dronecot-dronescout "dronecot-dronescout repairs ESP console CRLF expansion"
require_grep '^STATUS_APP=dronecot-dronescout$' /etc/default/dronecot-dronescout "dronecot-dronescout has an isolated runtime status namespace"
require_grep '303a' /etc/udev/rules.d/99-aryaos-dronescout.rules "DS101 udev symlink rule present"
# AntSDR E200 management: console access + DroneID feed health watchdog.
require_path /usr/local/sbin/aryaos-antsdr-console
require_path /usr/local/sbin/aryaos-antsdr-health
require_path /etc/systemd/system/aryaos-antsdr-health.timer
require_grep 'tak_established' /usr/local/sbin/aryaos-antsdr-health "AntSDR health reports DroneCOT TAK egress"
require_grep '1a86' /etc/udev/rules.d/99-aryaos-antsdr-console.rules "AntSDR console udev rule present"
require_path /usr/bin/tio
# Wi-Fi Remote ID: opt-in dronecot instance (802.11 monitor-mode ODID capture).
# Needs python3-scapy for dronecot's WifiWorker.
require_path /etc/systemd/system/dronecot-wifi.service
require_grep 'wifi://' /etc/default/dronecot-wifi "dronecot-wifi captures 802.11 Remote ID"
require_path /usr/lib/python3/dist-packages/scapy/all.py
require_path /usr/local/sbin/aryaos-wifi-monitor
require_grep 'aryaos-wifi-monitor' /etc/systemd/system/dronecot-wifi.service "dronecot-wifi preps monitor mode via ExecStartPre"
require_grep 'SENSOR_TYPE' /etc/default/dronecot-wifi "dronecot-wifi carries SIGINT sensor detail"
require_grep '^STATUS_APP=dronecot-wifi$' /etc/default/dronecot-wifi "dronecot-wifi has an isolated runtime status namespace"
require_grep '^STATUS_APP=dronecot-ble$' /etc/default/dronecot-ble "dronecot-ble has an isolated runtime status namespace"
# Capability model.
require_grep 'ARYAOS_CAPABILITIES' /usr/local/sbin/aryaos-role "aryaos-role has the capability model"
require_grep 'acarsdec acarscot' /usr/local/sbin/aryaos-role "aryaos-role manages the ACARS decoder and gateway"
require_path /usr/local/sbin/aryaos-capability-scan
require_grep 'ADSBEE_VID_PID' /usr/local/sbin/aryaos-capability-scan "capability scan protocol-probes generic Pico ADSBee hardware"
require_grep 'device-type modesbeast' /usr/local/sbin/aryaos-role "aryaos-role configures ADSBee Beast serial input"
require_path /usr/local/libexec/aryaos/dronecot-serial-ready
require_grep 'ExecCondition=/usr/local/libexec/aryaos/dronecot-serial-ready' /etc/systemd/system/dronecot-dronescout.service "DroneScout missing serial device skips cleanly"
require_grep 'discover' /usr/local/sbin/aryaos-role "aryaos-role can discover hardware capabilities"
require_grep 'capability-scan' /usr/local/sbin/aryaos-firstboot.sh "firstboot auto-detects capabilities"
require_unit gdlcot.service
require_unit lincot.service
require_unit cotbridge.service
require_unit readsb.service
require_path /etc/systemd/system/lincot.service.d/aryaos-config.conf
require_grep '^EnvironmentFile=-/etc/aryaos/aryaos-config.txt$' /etc/systemd/system/lincot.service.d/aryaos-config.conf "lincot drop-in inherits AryaOS site config"
require_grep '^EnvironmentFile=/etc/default/lincot$' /etc/systemd/system/lincot.service.d/aryaos-config.conf "lincot service defaults keep precedence"
require_path /etc/systemd/system/sikw00fcot.service.d/aryaos-config.conf
require_grep '^EnvironmentFile=$' /etc/systemd/system/sikw00fcot.service.d/aryaos-config.conf "sikw00fcot resets vendor environment list"
require_grep '^EnvironmentFile=-/etc/aryaos/aryaos-config.txt$' /etc/systemd/system/sikw00fcot.service.d/aryaos-config.conf "sikw00fcot inherits AryaOS site config"
require_grep '^EnvironmentFile=/etc/default/sikw00fcot$' /etc/systemd/system/sikw00fcot.service.d/aryaos-config.conf "sikw00fcot keeps service defaults override"

# Node-RED (stage-node-red)
require_path /home/node-red/.node-red/flows.json
require_grep '"version": "4\.2\.7"' /home/node-red/.node-red/node_modules/socket.io-parser/package.json "Node-RED Socket.IO parser has memory-exhaustion fix"
# Node-RED must NOT run as root: the upstream unit ships User=root out of
# /root/.node-red (no adminAuth = unauthenticated root-privileged admin API).
# AryaOS pins it to the node-red user via a drop-in.
require_path /etc/systemd/system/nodered.service.d/aryaos.conf
require_grep '^[[:space:]]*User=node-red' /etc/systemd/system/nodered.service.d/aryaos.conf "nodered runs as node-red (not root)"
# The hardened settings.js (the one node-red now uses) must carry adminAuth.
require_grep 'adminAuth' /home/node-red/.node-red/settings.js "node-red adminAuth configured"
# Node-RED is optional + tucked away: empty flows, bound to loopback, served under
# /nr behind the lighttpd HTTPS proxy, and NOT exposed on :1880 on the LAN.
require_grep '^\[\]' /home/node-red/.node-red/flows.json "node-red ships empty flows"
require_grep 'uiHost:[[:space:]]*"127.0.0.1"' /home/node-red/.node-red/settings.js "node-red binds loopback only"
require_grep 'httpAdminRoot:[[:space:]]*"/nr"' /home/node-red/.node-red/settings.js "node-red served under /nr"
require_grep 'port"[[:space:]]*=>[[:space:]]*1880' /etc/lighttpd/conf-available/95-aryaos-cockpit-https.conf "lighttpd reverse-proxies /nr to Node-RED"
if grep -qsE '<service name="aryaos-node-red"' "${MNT}/etc/firewalld/zones/public.xml"; then
	fail "public (LAN) zone still exposes Node-RED :1880 — should be proxied via /nr only"
else
	ok "Node-RED not exposed on the public (LAN) zone (reachable via /nr only)"
fi

# Hardening (stage-aryaos): firewall, brute-force protection, auto security
# updates, per-device web TLS, sysctl/sshd tightening
require_pkg firewalld
require_pkg fail2ban
require_pkg unattended-upgrades
require_pkg cockpit-packagekit
require_path /etc/ssh/sshd_config.d/50-aryaos.conf
require_grep '^PermitRootLogin no$' /etc/ssh/sshd_config.d/50-aryaos.conf "sshd: root login disabled"
require_path /etc/sysctl.d/90-aryaos-hardening.conf
require_path /etc/fail2ban/jail.d/aryaos.local
require_path /etc/apt/apt.conf.d/20auto-upgrades
require_path /etc/apt/apt.conf.d/52unattended-upgrades-aryaos
require_path /etc/firewalld/zones/public.xml
require_path /etc/firewalld/services/aryaos-mesh-sa.xml
require_grep 'aryaos-mesh-sa' /etc/firewalld/zones/public.xml "firewall zone allows Mesh SA"
require_path /etc/firewalld/services/aryaos-gutcheck.xml
require_grep 'aryaos-gutcheck' /etc/firewalld/zones/public.xml "firewall zone allows token-gated Gutcheck on the LAN"
require_path /etc/sudoers.d/aryaos-gutcheck-health
require_grep '^Cmnd_Alias ARYAOS_GUTCHECK_HEALTH = /usr/local/sbin/aryaos-health --json$' /etc/sudoers.d/aryaos-gutcheck-health "Gutcheck health privilege names only the read-only collector"
require_grep '^gutcheck ALL=\(root\) NOPASSWD: ARYAOS_GUTCHECK_HEALTH$' /etc/sudoers.d/aryaos-gutcheck-health "Gutcheck has only read-only health collector privilege"
require_path /etc/systemd/system/gutcheck.service.d/aryaos-health.conf
require_grep '^Environment="LOCAL_HEALTH_COMMAND=/usr/bin/sudo -n /usr/local/sbin/aryaos-health --json"$' /etc/systemd/system/gutcheck.service.d/aryaos-health.conf "Gutcheck uses the scoped AryaOS health collector"
require_grep 'UnitFileState' /usr/local/sbin/aryaos-health "gateway health records systemd enablement"
require_grep 'state.*!=.*disabled' /usr/local/sbin/aryaos-health "disabled gateways do not degrade aggregate health"
require_grep 'name="https"' /etc/firewalld/zones/public.xml "firewall zone allows HTTPS"
require_path /etc/systemd/system/multi-user.target.wants/firewalld.service
require_path /etc/systemd/system/multi-user.target.wants/fail2ban.service
require_grep 'zone=trusted' /etc/NetworkManager/system-connections/aryaos-antsdr.nmconnection "AntSDR link in trusted firewall zone"
require_grep 'web-tls-regenerated' /usr/local/sbin/aryaos-firstboot.sh "firstboot mints per-device web TLS cert"

# Sensors OFF by default: capability drives what runs. The sensor debs enable
# themselves in postinst, so this regresses the moment a package is added or
# reordered — assert the enablement symlinks are genuinely absent.
forbid_enabled() {
	local unit="$1" found=""
	local d
	for d in etc/systemd/system/multi-user.target.wants \
		etc/systemd/system/default.target.wants \
		usr/lib/systemd/system/multi-user.target.wants; do
		if [[ -e "${MNT}/${d}/${unit}" || -L "${MNT}/${d}/${unit}" ]]; then
			found="${d}"
			break
		fi
	done
	if [[ -z "${found}" ]]; then
		ok "${unit} not enabled by default"
	else
		fail "${unit} is enabled by default (${found}) — sensors must be capability-gated"
	fi
}
for _u in readsb.service dump978-fa.service adsbcot.service aiscot.service \
	dronecot.service sikw00fcot.service ais-catcher.service sapientcot.service \
	dronecot-wifi.service dronecot-ble.service dronecot-dronescout.service \
	acarsdec.service acarscot.service; do
	forbid_enabled "${_u}"
done
require_grep '^ARYAOS_CAPABILITIES=""$' /etc/aryaos/aryaos-config.txt "no sensor capabilities enabled out of the box"
# ...while the CoT core still runs unconditionally.
require_path /etc/systemd/system/multi-user.target.wants/cotbridge.service

# One-click updates (Cockpit -> AryaOS Site drives aryaos-update)
require_path /usr/local/sbin/aryaos-update
require_path /etc/systemd/system/aryaos-update.service

# Field support helpers (Cockpit -> AryaOS Site drives all three)
require_path /usr/local/sbin/aryaos-support-bundle
require_path /usr/local/sbin/aryaos-set-nodered-password
require_path /usr/local/sbin/aryaos-sdr
require_path /usr/local/sbin/aryaos-role
require_pkg rtl-sdr
# LimeSDR (dragonegg: AryaOS + LimeSDR Mini + GPS) — SoapySDR lms7 driver + tools
# + SoapyRemote for network SIGINT access (scripts/readsb-use-lime.sh drives ADS-B off it).
require_pkg soapysdr-module-lms7
require_pkg limesuite
require_pkg soapysdr-module-remote

# Network SDR sharing (aryaos-sdr share): rtl_tcp per-dongle + SoapyRemote, both
# on-demand and NOT firewalled by default (raw unauthenticated SDR = opt-in).
require_grep 'share INDEX' /usr/local/sbin/aryaos-sdr "aryaos-sdr share subcommand"
require_unit aryaos-rtltcp@.service
require_unit aryaos-soapyremote.service
require_path /etc/firewalld/services/aryaos-rtltcp.xml
require_path /etc/firewalld/services/aryaos-soapyremote.xml
# SDR re-tasking (aryaos-sdr task): move a dongle between adsb/uat/ais; RTL-mode
# AIS via a dedicated unit; persisted jobs re-applied at boot.
require_grep 'task INDEX' /usr/local/sbin/aryaos-sdr "aryaos-sdr task subcommand"
require_unit ais-catcher-rtl@.service
require_grep 'AIS-catcher -X off' /lib/systemd/system/ais-catcher.service "serial AIS community sharing disabled"
require_grep 'AIS-catcher -X off' /etc/systemd/system/ais-catcher-rtl@.service "RTL AIS community sharing disabled"
require_unit aryaos-sdr-tasks.service
# Universal SDR (DragonEgg): aryaos-sdr enumerates/tasks any SoapySDR device
# (Airspy/HackRF/Lime), not just RTL. Generic AIS unit for non-RTL SDRs.
require_grep 'SoapySDRUtil' /usr/local/sbin/aryaos-sdr "aryaos-sdr universal SoapySDR enumeration"
require_grep 'device-type soapy' /usr/local/sbin/aryaos-sdr "aryaos-sdr tasks non-RTL SDRs via SoapySDR"
require_unit aryaos-ais-sdr.service
require_grep 'AIS-catcher -X off' /etc/systemd/system/aryaos-ais-sdr.service "generic SDR AIS community sharing disabled"
require_pkg soapysdr-tools
# APRS over RF (aryaos-sdr task N aprs): rtl_fm + Dire Wolf -> KISS -> aprscot -> CoT.
require_grep 'aprs' /usr/local/sbin/aryaos-sdr "aryaos-sdr aprs task job"
require_pkg direwolf
require_pkg aprscot
require_pkg cockpit-aprscot
require_pkg_version cockpit-aprscot 0.1.1
require_path /usr/share/cockpit/aprscot/manifest.json
require_unit aryaos-direwolf@.service
require_path /etc/aryaos/direwolf.conf
require_grep 'KISS_HOST=127.0.0.1' /etc/default/aprscot "aprscot reads local KISS TNC (offline, not APRS-IS)"
# SAPIENT C-UAS gateway (sapientcot): BSI Flex 335 DetectionReports -> CoT; the
# sapient-msg protobuf binding is pip-installed (not in Debian apt).
require_pkg sapientcot
require_pkg cockpit-sapientcot
require_pkg_version cockpit-sapientcot 0.1.1
require_path /usr/share/cockpit/sapientcot/manifest.json
require_path /etc/default/sapientcot
require_grep 'SAPIENT_HOST' /etc/default/sapientcot "sapientcot SAPIENT node config"
if compgen -G "${MNT}/usr/local/lib/python3*/dist-packages/sapient_msg" >/dev/null 2>&1 || \
   compgen -G "${MNT}/usr/lib/python3*/dist-packages/sapient_msg" >/dev/null 2>&1; then
	ok "sapient-msg protobuf bindings installed"
else
	fail "sapient-msg python bindings not found (pip install in stage-aiscot)"
fi
# SpyServer (Airspy) sharing (aryaos-sdr share N spyserver): runtime always ships;
# config never lists in the public directory. The proprietary binary is a
# best-effort build-time download, so its presence is NOT asserted here.
require_grep 'spyserver' /usr/local/sbin/aryaos-sdr "aryaos-sdr spyserver share mode"
require_unit aryaos-spyserver@.service
require_path /usr/local/sbin/aryaos-spyserver-run
require_path /usr/share/aryaos/spyserver.config.tmpl
require_path /etc/firewalld/services/aryaos-spyserver.xml
require_grep 'list_in_directory = 0' /usr/share/aryaos/spyserver.config.tmpl "SpyServer OPSEC (no public directory listing)"
for z in public aryaos-hotspot; do
	if grep -qsE '<service name="aryaos-(rtltcp|soapyremote|spyserver)"' "${MNT}/etc/firewalld/zones/${z}.xml"; then
		fail "${z} zone exposes a raw SDR share server by default (must be opt-in)"
	else
		ok "${z} zone does not open SDR-share servers by default"
	fi
done

# Robust serial assignment (GPS vs AIS/dAISy by protocol sniffing) — no
# hardcoded ttyUSB*/single-make by-id, which broke on differing adapters.
require_path /usr/local/sbin/aryaos-serial-assign
require_path /usr/local/libexec/aryaos/aryaos-serial-classify
require_grep 'valid_sirf_frame' /usr/local/libexec/aryaos/aryaos-serial-classify "binary SiRF GPS protocol detection"
require_unit aryaos-serial-assign.service
require_grep '^DEVICES=""' /etc/default/gpsd "gpsd device not hardcoded (aryaos-serial-assign owns it)"
require_grep '^SERIAL_PORT=$' /etc/default/ais-catcher "ais-catcher serial not hardcoded (aryaos-serial-assign owns it)"

# Lifecycle helpers (Cockpit -> AryaOS Site: backup/restore, factory reset, zeroize)
require_path /usr/local/sbin/aryaos-config-backup
require_grep '^etc/default/gutcheck$' /usr/local/sbin/aryaos-config-backup "Gutcheck settings included in full config backups"
require_path /usr/local/sbin/aryaos-factory-reset
require_grep '\.capabilities-autodetected' /usr/local/sbin/aryaos-factory-reset "factory reset re-arms hardware discovery"
require_grep 'aryaos-role caps none' /usr/local/sbin/aryaos-factory-reset "factory reset releases sensor devices before discovery"
require_grep 'aryaos-safe-mode reset-for-factory' /usr/local/sbin/aryaos-factory-reset "factory reset clears false crash-loop state"
require_grep 'dpkg --configure -a' /usr/local/sbin/aryaos-factory-reset "factory reset recovers interrupted gateway configuration"
require_path /usr/local/sbin/aryaos-zeroize
require_path /etc/systemd/system/aryaos-factory-reset.service
require_path /etc/systemd/system/aryaos-zeroize.service
require_path /usr/share/aryaos/defaults/cotbridge.ini

# Radios: WiFi hotspot control + EMCON/radio-silence (Cockpit -> AryaOS Site)
require_path /usr/local/sbin/aryaos-radio
require_path /etc/systemd/system/aryaos-radio-silence.service
# EMCON must survive a reboot: aryaos-radio disables WiFi at the NM level (rfkill
# alone gets re-enabled by NetworkManager), and comitup/bt-pan/bt-ready are gated
# off while the flag exists so they don't un-block the radios on boot.
require_grep 'nmcli radio wifi off' /usr/local/sbin/aryaos-radio "aryaos-radio disables WiFi via NetworkManager for EMCON"
for svc in comitup aryaos-bt-pan aryaos-bt-ready; do
	require_grep 'ConditionPathExists=!/etc/aryaos/emcon' "/etc/systemd/system/${svc}.service.d/emcon.conf" "${svc} gated off during EMCON"
done

# Safe mode: brownout / crash-loop fail-safe (powers off USB, withholds sensors).
require_path /usr/local/sbin/aryaos-safe-mode
require_unit aryaos-crash-guard.service
require_unit aryaos-safe-mode.service
require_unit aryaos-boot-stable.timer
require_pkg uhubctl
for svc in readsb adsbcot ais-catcher; do
	require_grep 'ConditionPathExists=!/etc/aryaos/safe-mode' "/etc/systemd/system/${svc}.service.d/safe-mode.conf" "${svc} withheld in safe mode"
done
# USB current cap relaxed so the Pi 5 can feed SDRs on a 5A / PoE+ supply.
require_grep 'usb_max_current_enable=1' /boot/firmware/config.txt "USB current cap relaxed for SDRs (Pi 5)"
# AP/PAN isolation: the default zone must NOT enable intra-zone forwarding, or a
# hotspot/Bluetooth client could be routed onto the wired ethernet.
require_path /etc/firewalld/zones/public.xml
if grep -qsE '<forward\s*/?>' "${MNT}/etc/firewalld/zones/public.xml"; then
	fail "public zone has <forward/> — hotspot/PAN could gateway to ethernet"
else
	ok "public zone has no intra-zone forwarding (AP/PAN isolated from eth)"
fi
# The comitup onboarding portal (9080) must NOT be open on the wired LAN — only the
# onboarding radios (aryaos-hotspot zone) need it.
if grep -qsE '<service name="aryaos-comitup"' "${MNT}/etc/firewalld/zones/public.xml"; then
	fail "public zone opens the comitup portal (9080) to the wired LAN"
else
	ok "comitup onboarding portal not exposed on the wired LAN"
fi
# aryaos-neighbord parses untrusted multicast CoT — it must reject DTD/entity
# (billion-laughs) payloads before ElementTree parsing.
require_grep '<!DOCTYPE' /usr/local/sbin/aryaos-neighbord "neighbord rejects DTD/entity CoT (billion-laughs guard)"
# aryaos-neighbord parses untrusted network input as root — it must be sandboxed.
require_grep '^NoNewPrivileges=yes' /etc/systemd/system/aryaos-neighbord.service "neighbord is systemd-sandboxed"

# Onboarding hotspot zone: tight INPUT (assigned to wlan0 in AP mode by
# comitup-callback). Must exist, must NOT expose ssh / Node-RED / mesh, and
# must have no intra-zone forwarding.
require_path /etc/firewalld/zones/aryaos-hotspot.xml
if grep -qsE '<service name="(ssh|aryaos-node-red|aryaos-mesh-sa|aryaos-gutcheck)"' "${MNT}/etc/firewalld/zones/aryaos-hotspot.xml"; then
	fail "aryaos-hotspot zone exposes ssh/node-red/mesh to onboarding clients"
else
	ok "aryaos-hotspot zone withholds ssh/node-red/mesh from onboarding clients"
fi
require_grep '(aryaos-hotspot|--change-interface)' /usr/local/sbin/comitup-callback.sh "comitup-callback assigns wlan0 to the hotspot zone"
require_grep '^bind-dynamic$' /usr/share/comitup/dns/dns-hotspot.conf "WiFi hotspot DHCP coexists with Bluetooth PAN DHCP"
require_grep '^bind-dynamic$' /usr/share/comitup/dns/dns-connected.conf "WiFi connecting DHCP coexists with Bluetooth PAN DHCP"
require_grep 'dhcp6-change\|reapply' /etc/NetworkManager/dispatcher.d/99-aryaos-dispatcher "dispatcher accepts NetworkManager reapply events"
# Bluetooth PAN (pan0) is the other onboarding radio — it must be confined to the
# hotspot zone too (statically in the zone XML + at bridge-up in the bt-pan NAP).
require_grep '<interface name="pan0"/>' /etc/firewalld/zones/aryaos-hotspot.xml "pan0 statically bound to hotspot zone"
require_grep 'aryaos-hotspot' /usr/local/sbin/aryaos-bt-pan-nap "bt-pan confines pan0 to the hotspot zone"

# Offline image self-backup: helper + the build-commit stamp it resolves against.
require_path /usr/local/sbin/aryaos-image-download
require_path /etc/aryaos/image-commit
require_grep '^[0-9a-f]{7,}' /etc/aryaos/image-commit "image-commit stamped with a real SHA (not 'unknown')"

# Time service: chrony (GPS-disciplined NTP server for the local networks)
require_pkg chrony
require_path /etc/chrony/conf.d/aryaos.conf
require_grep '<service name="ntp"' /etc/firewalld/zones/public.xml "NTP served on the AryaOS (LAN) zone"

# Media longevity: zram swap config + periodic TRIM
require_pkg systemd-zram-generator
require_path /etc/systemd/zram-generator.conf
require_grep '^\[zram0\]' /etc/systemd/zram-generator.conf "zram swap configured"
require_path /etc/rpi/swap.conf.d/90-aryaos.conf
require_grep '^Mechanism=zram$' /etc/rpi/swap.conf.d/90-aryaos.conf "rpi-swap cannot create a disk-backed swapfile"
forbid_path /var/swap
require_path /etc/modules-load.d/lighttpd-mod-openssl.conf
require_path /usr/share/aryaos/initramfs/set_partuuid
require_path /etc/initramfs-tools/hooks/zz-aryaos-set-partuuid
require_grep 'write_verified' /usr/share/aryaos/initramfs/set_partuuid "first-boot cmdline rewrite verifies FAT readback"
require_grep 'cmp -s.*destination' /usr/share/aryaos/initramfs/set_partuuid "first-boot cmdline verifies the final boot path"

# Lab access must match the build flavor
if [[ "${LAB_EXPECTED}" == "1" ]]; then
	require_path /etc/sudoers.d/aryaos-lab
	if grep -qs 'aryaos-dev-lab' "${MNT}/home/pi/.ssh/authorized_keys"; then
		ok "aryaos-dev-lab key present (lab build)"
	else
		fail "aryaos-dev-lab key missing from authorized_keys (lab build)"
	fi
else
	forbid_path /etc/sudoers.d/aryaos-lab
	if grep -qs 'aryaos-dev-lab' "${MNT}/home/pi/.ssh/authorized_keys"; then
		fail "aryaos-dev-lab key present in authorized_keys (release build must not ship lab access)"
	else
		ok "no aryaos-dev-lab key in authorized_keys"
	fi
	if grep -qs 'NOPASSWD' "${MNT}/etc/sudoers.d/aryaos"; then
		fail "NOPASSWD rule in /etc/sudoers.d/aryaos (release build)"
	else
		ok "no NOPASSWD rule in /etc/sudoers.d/aryaos"
	fi
fi

# Regression guard for a data-loss bug found on a live box: aryaos-config-backup
# captured a literal, hand-maintained list of config paths, and it had gone stale.
# aprscot, sapientcot, ais-catcher, dronecot-ble, dronecot-wifi,
# dronecot-dronescout and readsb all existed in /etc/default and NONE were backed
# up, so a factory reset + restore came back with those capabilities silently
# reverted to defaults.
#
# "Is this file AryaOS configuration?" is decided from dpkg ownership, NOT from a
# second hardcoded list here -- a second list would rot exactly the same way. A
# /etc/default entry is ours if no package in the image claims it (our stage
# scripts wrote it), or if the claiming package is one we install from the snstac
# apt repo. Private Gutcheck is intentionally absent from that public manifest,
# so its secret-bearing defaults also have an explicit check above.
backup_covers_gateway_configs() {
	local script="${MNT}/usr/local/sbin/aryaos-config-backup"
	if [[ ! -r "${script}" ]]; then
		fail "aryaos-config-backup not readable; cannot check backup coverage"
		return
	fi

	local -a pats=()
	# Take the path lines straight out of the config_paths() block. Matching the
	# heredoc markers instead needs nested quoting that is easy to get wrong --
	# a first attempt at it silently extracted nothing and the check "passed" by
	# doing nothing at all.
	mapfile -t pats < <(sed -n "/^config_paths() {/,/^}/p" "${script}" \
		| grep -E '^(etc|home|usr|var)/')
	if [[ "${#pats[@]}" -eq 0 ]]; then
		fail "could not read config_paths() out of aryaos-config-backup"
		return
	fi

	# Packages we install from the snstac repo, per the build manifest. Resolved
	# relative to this script, not the caller's cwd.
	local manifest
	manifest="$(dirname "${BASH_SOURCE[0]}")/../manifests/aryaos-sensor-packages.yml"
	local -a ours=()
	mapfile -t ours < <(grep -oE '^\s*-\s+[A-Za-z0-9._+-]+' "${manifest}" 2>/dev/null \
		| sed -E 's/^\s*-\s+//' || true)

	local -a missing=()
	local f base rel owner is_ours covered pat pkg
	for f in "${MNT}"/etc/default/*; do
		[[ -f "${f}" ]] || continue
		base="$(basename "${f}")"
		rel="etc/default/${base}"

		# Is this file ours? Two independent signals, either is sufficient:
		#
		#   1. it is NAMED like one of our gateways, or
		#   2. the package that ships it is in the build manifest.
		#
		# Ownership alone is not enough in either direction. UNOWNED does not
		# mean ours -- Debian generates console-setup, keyboard and locale here
		# at configure time and no package .list claims them, and treating
		# unowned as ours flagged all three and failed a build. OWNED does not
		# mean Debian's either: aprscot and sapientcot ship their own
		# /etc/default file but are installed outside the manifest, so an
		# ownership-only rule skipped them silently -- the exact blind spot this
		# check exists to prevent.
		#
		# Trade-off, stated: a future gateway named outside these families AND
		# absent from the manifest would not be checked.
		is_ours=0
		case "${base}" in
			*cot*|*tak*|ais-catcher|readsb|dump*-fa|gpsd) is_ours=1 ;;
		esac
		if [[ "${is_ours}" -eq 0 ]]; then
			# grep finding nothing must not be an error: under `set -euo
			# pipefail` a failing grep propagated through `head` and killed the
			# whole script -- no FAIL line, no summary, just a dead build.
			owner="$(grep -lFx "/${rel}" "${MNT}"/var/lib/dpkg/info/*.list 2>/dev/null | head -1 || true)"
			if [[ -n "${owner}" ]]; then
				pkg="$(basename "${owner}" .list)"
				pkg="${pkg%%:*}"
				for p in ${ours[@]+"${ours[@]}"}; do
					if [[ "${pkg}" == "${p}" ]]; then
						is_ours=1
						break
					fi
				done
			fi
		fi
		[[ "${is_ours}" -eq 1 ]] || continue

		covered=0
		for pat in ${pats[@]+"${pats[@]}"}; do
			# Unquoted RHS is deliberate: glob matching is the point here.
			# shellcheck disable=SC2053
			if [[ "${rel}" == ${pat} ]]; then
				covered=1
				break
			fi
		done
		if [[ "${covered}" -ne 1 ]]; then
			missing+=("${base}")
		fi
	done

	if [[ "${#missing[@]}" -gt 0 ]]; then
		fail "aryaos-config-backup would not back up: ${missing[*]}"
	else
		ok "aryaos-config-backup covers every AryaOS config in /etc/default"
	fi
}
backup_covers_gateway_configs

echo "== ${PASS} ok, ${FAIL} failed =="
[[ "${FAIL}" -eq 0 ]]
