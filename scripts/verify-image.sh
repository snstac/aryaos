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

echo "== AryaOS image content checks: ${IMG##*/} (lab=${LAB_EXPECTED}) =="

# Core identity and config (stage-aryaos)
# aryaos-overlay must be registered in dpkg (a 644 exec bit on the build
# script once skipped this silently — the [[ -x ]] guard in 00-run.sh).
require_pkg aryaos-overlay
require_path /etc/aryaos-release
require_path /etc/aryaos-version
require_path /etc/aryaos/aryaos-config.txt
require_path /etc/sudoers.d/aryaos
require_path /usr/local/sbin/aryaos-firstboot.sh
require_path /usr/local/sbin/aryaos-lincot-remarks
require_path /usr/local/sbin/aryaos-cot-detail
require_path /usr/local/sbin/aryaos-neighbord
require_path /etc/systemd/system/aryaos-firstboot.service
require_path /etc/systemd/system/aryaos-neighbord.service
require_grep '^COT_URL=udp\+wo://127\.0\.0\.1:28087$' /etc/aryaos/aryaos-config.txt "feeder COT_URL points to charontak"

# Portal (stage-aryaos)
require_path /var/www/html/index.html
require_path /usr/lib/cgi-bin/aryaos-portal-status
require_path /usr/lib/cgi-bin/aryaos-neighbors
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

# GPSTAK network GPS (package from stage-pytak)
require_pkg gpstak
require_path /usr/bin/gpstak
require_path /lib/systemd/system/gpstak.service
require_path /etc/default/gpstak
require_path /usr/share/cockpit/gpstak/manifest.json

# charontak cockpit page (ships inside the charontak deb >= 0.1.12)
require_path /usr/share/cockpit/charontak/manifest.json
require_path /etc/charontak.ini
require_grep '^\[lane:local-to-mesh\]$' /etc/charontak.ini "charontak local-to-mesh lane"
require_grep '^egress_cot_url = udp\+wo://239\.2\.3\.1:6969$' /etc/charontak.ini "charontak Mesh SA egress"
require_grep '^\[lane:local-to-takserver\]$' /etc/charontak.ini "charontak local-to-takserver lane"
require_grep '^ingress_cot_url = udp\+ro://127\.0\.0\.1:28087$' /etc/charontak.ini "charontak TAK Server lane local ingress"

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
require_pkg cockpit-gps
require_pkg cockpit-adsbcot
require_pkg cockpit-lincot
require_pkg cockpit-aiscatcher
require_pkg cockpit-dronecot
require_pkg cockpit-charontak
require_pkg cockpit-gpstak
require_pkg cockpit-aryaos
require_pkg cockpit-spyserver
require_path /usr/share/cockpit/spyserver/manifest.json
require_pkg readsb
require_pkg python3-gps
require_pkg ais-catcher
require_pkg sikw00fcot
require_pkg gdltak
require_unit adsbcot.service
require_unit aiscot.service
require_unit dronecot.service
require_unit sikw00fcot.service
# DroneScout DS101: 2nd dronecot instance (MAVLink Remote ID over serial), opt-in.
require_path /etc/systemd/system/dronecot-dronescout.service
require_grep 'serial://' /etc/default/dronecot-dronescout "dronecot-dronescout reads MAVLink serial"
require_unit gdltak.service
require_unit lincot.service
require_unit charontak.service
require_unit readsb.service
require_grep '^EnvironmentFile=/etc/aryaos/aryaos-config.txt$' /lib/systemd/system/sikw00fcot.service "sikw00fcot inherits AryaOS site config"
require_grep '^EnvironmentFile=/etc/default/sikw00fcot$' /lib/systemd/system/sikw00fcot.service "sikw00fcot keeps service defaults override"

# Node-RED (stage-node-red)
require_path /home/node-red/.node-red/flows.json
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
require_grep 'name="https"' /etc/firewalld/zones/public.xml "firewall zone allows HTTPS"
require_path /etc/systemd/system/multi-user.target.wants/firewalld.service
require_path /etc/systemd/system/multi-user.target.wants/fail2ban.service
require_grep 'zone=trusted' /etc/NetworkManager/system-connections/aryaos-antsdr.nmconnection "AntSDR link in trusted firewall zone"
require_grep 'web-tls-regenerated' /usr/local/sbin/aryaos-firstboot.sh "firstboot mints per-device web TLS cert"

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
require_unit aryaos-sdr-tasks.service
# Universal SDR (DragonEgg): aryaos-sdr enumerates/tasks any SoapySDR device
# (Airspy/HackRF/Lime), not just RTL. Generic AIS unit for non-RTL SDRs.
require_grep 'SoapySDRUtil' /usr/local/sbin/aryaos-sdr "aryaos-sdr universal SoapySDR enumeration"
require_grep 'device-type soapy' /usr/local/sbin/aryaos-sdr "aryaos-sdr tasks non-RTL SDRs via SoapySDR"
require_unit aryaos-ais-sdr.service
require_pkg soapysdr-tools
# APRS over RF (aryaos-sdr task N aprs): rtl_fm + Dire Wolf -> KISS -> aprscot -> CoT.
require_grep 'aprs' /usr/local/sbin/aryaos-sdr "aryaos-sdr aprs task job"
require_pkg direwolf
require_pkg aprscot
require_pkg cockpit-aprscot
require_path /usr/share/cockpit/aprscot/manifest.json
require_unit aryaos-direwolf@.service
require_path /etc/aryaos/direwolf.conf
require_grep 'KISS_HOST=127.0.0.1' /etc/default/aprscot "aprscot reads local KISS TNC (offline, not APRS-IS)"
# SAPIENT C-UAS gateway (sapientcot): BSI Flex 335 DetectionReports -> CoT; the
# sapient-msg protobuf binding is pip-installed (not in Debian apt).
require_pkg sapientcot
require_pkg cockpit-sapientcot
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

# Robust NMEA-serial assignment (GPS vs AIS/dAISy by sentence sniffing) — no
# hardcoded ttyUSB*/single-make by-id, which broke on differing adapters.
require_path /usr/local/sbin/aryaos-serial-assign
require_unit aryaos-serial-assign.service
require_grep '^DEVICES=""' /etc/default/gpsd "gpsd device not hardcoded (aryaos-serial-assign owns it)"
require_grep '^SERIAL_PORT=$' /etc/default/ais-catcher "ais-catcher serial not hardcoded (aryaos-serial-assign owns it)"

# Lifecycle helpers (Cockpit -> AryaOS Site: backup/restore, factory reset, zeroize)
require_path /usr/local/sbin/aryaos-config-backup
require_path /usr/local/sbin/aryaos-factory-reset
require_path /usr/local/sbin/aryaos-zeroize
require_path /etc/systemd/system/aryaos-factory-reset.service
require_path /etc/systemd/system/aryaos-zeroize.service
require_path /usr/share/aryaos/defaults/charontak.ini

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
if grep -qsE '<service name="(ssh|aryaos-node-red|aryaos-mesh-sa)"' "${MNT}/etc/firewalld/zones/aryaos-hotspot.xml"; then
	fail "aryaos-hotspot zone exposes ssh/node-red/mesh to onboarding clients"
else
	ok "aryaos-hotspot zone withholds ssh/node-red/mesh from onboarding clients"
fi
require_grep '(aryaos-hotspot|--change-interface)' /usr/local/sbin/comitup-callback.sh "comitup-callback assigns wlan0 to the hotspot zone"
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
require_path /etc/systemd/zram-generator.conf
require_grep '^\[zram0\]' /etc/systemd/zram-generator.conf "zram swap configured"

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

echo "== ${PASS} ok, ${FAIL} failed =="
[[ "${FAIL}" -eq 0 ]]
