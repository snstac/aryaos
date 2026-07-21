#!/bin/bash -e
# 00-run.sh
#
# Establishes base configuration for AryaOS on the build machine.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# pi-gen config exports SHARED_FILES (see repo config / config.docker), but some
# invocations do not propagate it into stage scripts. Without it,
# "${SHARED_FILES}/aryaos/..." becomes "/aryaos/..." and installs fail.
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

## AryaOS overlay Debian package: keep the appliance-owned files installable via dpkg
## as well as by the legacy pi-gen copy path below.
install -d -m 0755 "${ROOTFS_DIR}/usr/src"
REPO_ROOT="$(cd "${SHARED_FILES}/.." && pwd)"
if [[ -x "${REPO_ROOT}/scripts/build-aryaos-overlay-deb.sh" ]]; then
	ARYAOS_DEB_OUT_DIR="${ROOTFS_DIR}/usr/src" "${REPO_ROOT}/scripts/build-aryaos-overlay-deb.sh"
	OVERLAY_DEB="$(find "${ROOTFS_DIR}/usr/src" -maxdepth 1 -name 'aryaos-overlay_*_all.deb' | sort | tail -n1)"
	if [[ -n "${OVERLAY_DEB}" ]]; then
		cp -f "${OVERLAY_DEB}" "${ROOTFS_DIR}/usr/src/aryaos-overlay.deb"
	fi
fi


# Common

## Copy the AryaOS banner files to /etc/
install -v -m 0644 "${SHARED_FILES}/aryaos/motd" "${ROOTFS_DIR}/etc/motd"
install -v -m 0644 "${SHARED_FILES}/aryaos/issue" "${ROOTFS_DIR}/etc/issue"
install -v -m 0644 "${SHARED_FILES}/aryaos/issue.net" "${ROOTFS_DIR}/etc/issue.net"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-release" "${ROOTFS_DIR}/etc/aryaos-release"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-version" "${ROOTFS_DIR}/etc/aryaos-version"
install -v -m 0644 "${SHARED_FILES}/aryaos/README-aryaos.txt" "${ROOTFS_DIR}/"

## Copy the AryaOS sudoers file to /etc/sudoers.d/aryaos
install -v -m 0400 "${SHARED_FILES}/aryaos/aryaos.sudoers" "${ROOTFS_DIR}/etc/sudoers.d/aryaos"
## Copy the AryaOS configuration file to /etc/aryaos/
mkdir -p "${ROOTFS_DIR}/etc/aryaos/"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-config.txt" "${ROOTFS_DIR}/etc/aryaos/"
install -d -m 0755 "${ROOTFS_DIR}/usr/local/sbin"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-import-tak-dp" "${ROOTFS_DIR}/usr/local/sbin/aryaos-import-tak-dp"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-tak-dp-importd" "${ROOTFS_DIR}/usr/local/sbin/aryaos-tak-dp-importd"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-gps-time-sync" "${ROOTFS_DIR}/usr/local/sbin/aryaos-gps-time-sync"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-lincot-remarks" "${ROOTFS_DIR}/usr/local/sbin/aryaos-lincot-remarks"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-cot-detail" "${ROOTFS_DIR}/usr/local/sbin/aryaos-cot-detail"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-neighbord" "${ROOTFS_DIR}/usr/local/sbin/aryaos-neighbord"
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-gps-time-sync.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-gps-time-sync.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-tak-dp-importd.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-tak-dp-importd.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-neighbord.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-neighbord.service"

## Raspberry Pi: raise USB host current where firmware supports it (multi-SDR loads)
ARYAOS_USB_FRAG="${SHARED_FILES}/aryaos/boot/firmware/aryaos-usb-power.fragment"
if [[ -f "${ARYAOS_USB_FRAG}" ]]; then
	ARYAOS_USB_MARKER="# --- AryaOS: USB peripheral power ---"
	for cfg in "${ROOTFS_DIR}/boot/firmware/config.txt" "${ROOTFS_DIR}/boot/config.txt"; do
		if [[ ! -f "${cfg}" ]]; then
			continue
		fi
		if grep -qF "${ARYAOS_USB_MARKER}" "${cfg}" 2>/dev/null; then
			break
		fi
		cat "${ARYAOS_USB_FRAG}" >>"${cfg}"
		echo "Appended AryaOS USB power settings to ${cfg}"
		break
	done
fi

## Get throttled status on Raspberry Pi
install -v -m 0755 "${SHARED_FILES}/aryaos/get_throttled.sh" "${ROOTFS_DIR}/usr/local/sbin/"


# Hardening (release and lab builds alike; lab differs only in access, not posture)

## sshd: tightened defaults, password auth stays on (published default password
## is force-expired at first login — see aryaos-firstboot.sh).
install -d -m 0755 "${ROOTFS_DIR}/etc/ssh/sshd_config.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/sshd/50-aryaos.conf" "${ROOTFS_DIR}/etc/ssh/sshd_config.d/50-aryaos.conf"

## Kernel/network sysctl hardening
install -v -m 0644 "${SHARED_FILES}/aryaos/sysctl/90-aryaos-hardening.conf" "${ROOTFS_DIR}/etc/sysctl.d/90-aryaos-hardening.conf"

## fail2ban: SSH brute-force protection (systemd backend)
install -d -m 0755 "${ROOTFS_DIR}/etc/fail2ban/jail.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/fail2ban/aryaos.local" "${ROOTFS_DIR}/etc/fail2ban/jail.d/aryaos.local"

## unattended-upgrades: Debian security fixes auto-applied; snstac stack manual
install -d -m 0755 "${ROOTFS_DIR}/etc/apt/apt.conf.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/apt/20auto-upgrades" "${ROOTFS_DIR}/etc/apt/apt.conf.d/20auto-upgrades"
install -v -m 0644 "${SHARED_FILES}/aryaos/apt/52unattended-upgrades-aryaos" "${ROOTFS_DIR}/etc/apt/apt.conf.d/52unattended-upgrades-aryaos"

## firewalld: explicit inbound allowlist (Cockpit Networking -> Firewall manages it)
install -d -m 0755 "${ROOTFS_DIR}/etc/firewalld/services" "${ROOTFS_DIR}/etc/firewalld/zones"
for svc_xml in "${SHARED_FILES}/aryaos/firewalld/services/"*.xml; do
	install -v -m 0644 "${svc_xml}" "${ROOTFS_DIR}/etc/firewalld/services/"
done
for zone_xml in "${SHARED_FILES}/aryaos/firewalld/zones/"*.xml; do
	install -v -m 0644 "${zone_xml}" "${ROOTFS_DIR}/etc/firewalld/zones/"
done

## One-click updates: helper + oneshot unit (driven by Cockpit -> AryaOS Site)
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-update" "${ROOTFS_DIR}/usr/local/sbin/aryaos-update"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-update.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-update.service"

## Field support helpers (driven by Cockpit -> AryaOS Site)
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-support-bundle" "${ROOTFS_DIR}/usr/local/sbin/aryaos-support-bundle"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-set-nodered-password" "${ROOTFS_DIR}/usr/local/sbin/aryaos-set-nodered-password"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-sdr" "${ROOTFS_DIR}/usr/local/sbin/aryaos-sdr"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-role" "${ROOTFS_DIR}/usr/local/sbin/aryaos-role"

## Lifecycle helpers: backup/restore, factory reset, zeroize (Cockpit-driven)
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-config-backup" "${ROOTFS_DIR}/usr/local/sbin/aryaos-config-backup"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-factory-reset" "${ROOTFS_DIR}/usr/local/sbin/aryaos-factory-reset"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-zeroize" "${ROOTFS_DIR}/usr/local/sbin/aryaos-zeroize"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-factory-reset.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-factory-reset.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-zeroize.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-zeroize.service"

## Radios: WiFi hotspot control + EMCON/radio-silence (Cockpit-driven)
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-radio" "${ROOTFS_DIR}/usr/local/sbin/aryaos-radio"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-radio-silence.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-radio-silence.service"
# EMCON gate: comitup/bt-pan/bt-ready must not start (and un-block the radios)
# while /etc/aryaos/emcon exists.
for svc in comitup aryaos-bt-pan aryaos-bt-ready; do
	install -v -D -m 0644 "${SHARED_FILES}/aryaos/systemd/${svc}.service.d/emcon.conf" \
		"${ROOTFS_DIR}/etc/systemd/system/${svc}.service.d/emcon.conf"
done

## Media longevity: zram swap (compressed RAM swap instead of a swapfile) +
## the packaged charontak.ini default (source of truth for factory reset).
install -v -m 0644 "${SHARED_FILES}/aryaos/zram-generator.conf" "${ROOTFS_DIR}/etc/systemd/zram-generator.conf"
install -v -D -m 0644 "${SHARED_FILES}/charontak/charontak.ini" "${ROOTFS_DIR}/usr/share/aryaos/defaults/charontak.ini"

## gpsd: USB GNSS defaults (see shared_files/aryaos/gpsd.default)
install -v -m 0644 "${SHARED_FILES}/aryaos/gpsd.default" "${ROOTFS_DIR}/etc/default/gpsd"


# UUID

## First-boot DEVICE_SUFFIX and hostname (aryaos-xxxx)
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-device-suffix.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-firstboot.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-firstboot.service" "${ROOTFS_DIR}/etc/systemd/system/"


# Portal

mkdir -p "${ROOTFS_DIR}/var/www/"

rsync -va "${SHARED_FILES}/aryaos/html/" "${ROOTFS_DIR}/var/www/html/"
chmod 0655 "${ROOTFS_DIR}/var/www/html"


## Portal status CGI (JSON) for the landing page — no Node-RED
install -d -m 0755 "${ROOTFS_DIR}/usr/lib/cgi-bin"
install -v -m 0755 "${SHARED_FILES}/aryaos/cgi-bin/aryaos-portal-status" "${ROOTFS_DIR}/usr/lib/cgi-bin/aryaos-portal-status"
install -v -m 0755 "${SHARED_FILES}/aryaos/cgi-bin/aryaos-tak-dp-upload" "${ROOTFS_DIR}/usr/lib/cgi-bin/aryaos-tak-dp-upload"
install -v -m 0755 "${SHARED_FILES}/aryaos/cgi-bin/aryaos-neighbors" "${ROOTFS_DIR}/usr/lib/cgi-bin/aryaos-neighbors"

## Lab access (ARYAOS_LAB_ACCESS=1 only): trust aryaos-dev-lab.pub for user pi and
## grant pi passwordless sudo. Release builds (default) get neither — see
## shared_files/aryaos/ssh/README.md and docs/build.md.
if [[ "${ARYAOS_LAB_ACCESS:-0}" == "1" ]]; then
	install -v -m 0400 "${SHARED_FILES}/aryaos/aryaos-lab.sudoers" "${ROOTFS_DIR}/etc/sudoers.d/aryaos-lab"
fi

LAB_PUB="${SHARED_FILES}/aryaos/ssh/aryaos-dev-lab.pub"
if [[ "${ARYAOS_LAB_ACCESS:-0}" == "1" && -f "${LAB_PUB}" ]]; then
	install -d -m 0700 "${ROOTFS_DIR}/home/pi/.ssh"
	AK="${ROOTFS_DIR}/home/pi/.ssh/authorized_keys"
	touch "${AK}"
	PUB_LINE="$(tr -d '\r' < "${LAB_PUB}" | head -n1)"
	if ! grep -qF "${PUB_LINE}" "${AK}" 2>/dev/null; then
		{
			echo ""
			echo "# aryaos-dev-lab (see shared_files/aryaos/ssh/README.md)"
			cat "${LAB_PUB}"
			echo ""
		} >> "${AK}"
	fi
	chmod 0600 "${AK}"
	# Raspberry Pi OS: user pi is typically UID/GID 1000
	chown -R 1000:1000 "${ROOTFS_DIR}/home/pi/.ssh"
fi


# Recorder

## Copy Recorder configuration files to lighttpd conf-available
install -v -m 0644 "${SHARED_FILES}/aryaos/99-aryaos-recorder.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-available/"

## Symlink Recorder configuration files to lighttpd conf-enabled
ln -sf /etc/lighttpd/conf-available/99-aryaos-recorder.conf "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/99-aryaos-recorder.conf"
## FIXME Deprecated hard-copy of 99-aryaos-recorder.conf
## install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-recorder.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"


# Cockpit behind HTTPS (lighttpd terminates TLS; cockpit-ws loopback HTTP only)

mkdir -p "${ROOTFS_DIR}/etc/cockpit"
install -v -m 0644 "${SHARED_FILES}/aryaos/cockpit.conf" "${ROOTFS_DIR}/etc/cockpit/cockpit.conf"

mkdir -p "${ROOTFS_DIR}/etc/systemd/system/cockpit.socket.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/cockpit.socket-listen.conf" "${ROOTFS_DIR}/etc/systemd/system/cockpit.socket.d/listen.conf"

install -v -m 0644 "${SHARED_FILES}/aryaos/95-aryaos-cockpit-https.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-available/"
ln -sf /etc/lighttpd/conf-available/95-aryaos-cockpit-https.conf "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/95-aryaos-cockpit-https.conf"

for m in openssl proxy redirect cgi deflate; do
	if [[ -f "${ROOTFS_DIR}/etc/lighttpd/conf-available/10-${m}.conf" ]]; then
		ln -sf "/etc/lighttpd/conf-available/10-${m}.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/10-${m}.conf"
	fi
done

shopt -s nullglob
setenv_found=0
for f in "${ROOTFS_DIR}/etc/lighttpd/conf-available/"*-setenv.conf; do
	setenv_found=1
	bn="$(basename "${f}")"
	ln -sf "/etc/lighttpd/conf-available/${bn}" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/${bn}"
done
shopt -u nullglob
if [[ "${setenv_found}" -eq 0 ]]; then
	install -v -m 0644 "${SHARED_FILES}/aryaos/94-aryaos-setenv-module.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-available/"
	ln -sf /etc/lighttpd/conf-available/94-aryaos-setenv-module.conf "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/94-aryaos-setenv-module.conf"
fi

install -d -m 0755 "${ROOTFS_DIR}/etc/lighttpd/ssl"
if [[ -r "${ROOTFS_DIR}/etc/ssl/certs/ssl-cert-snakeoil.pem" && -r "${ROOTFS_DIR}/etc/ssl/private/ssl-cert-snakeoil.key" ]]; then
	umask 077
	cat "${ROOTFS_DIR}/etc/ssl/certs/ssl-cert-snakeoil.pem" "${ROOTFS_DIR}/etc/ssl/private/ssl-cert-snakeoil.key" \
		> "${ROOTFS_DIR}/etc/lighttpd/ssl/snakeoil-combined.pem.tmp"
	mv -f "${ROOTFS_DIR}/etc/lighttpd/ssl/snakeoil-combined.pem.tmp" "${ROOTFS_DIR}/etc/lighttpd/ssl/snakeoil-combined.pem"
	chmod 0640 "${ROOTFS_DIR}/etc/lighttpd/ssl/snakeoil-combined.pem"
	# Use GID from the image's /etc/group: host-side chgrp ssl-cert often fails (host has no ssl-cert).
	if ssl_cert_gid="$(awk -F: '$1 == "ssl-cert" {print $3; exit}' "${ROOTFS_DIR}/etc/group")" && [[ -n "${ssl_cert_gid}" ]]; then
		chown "root:${ssl_cert_gid}" "${ROOTFS_DIR}/etc/lighttpd/ssl/snakeoil-combined.pem" || true
	fi
fi


## systemd: allow AF_NETLINK in lighttpd (portal CGI runs "ip" / iproute2 netlink)
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system/lighttpd.service.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/lighttpd.service.d/aryaos-netlink.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/lighttpd.service.d/aryaos-netlink.conf"

## systemd: gpsd control socket group-readable (portal CGI runs gpspipe as www-data)
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system/gpsd.socket.d"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/gpsd.socket.d/socket-group.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/gpsd.socket.d/socket-group.conf"


# WiFi

install -d -m 0755 "${ROOTFS_DIR}/etc/NetworkManager/system-connections"
install -v -m 0600 \
	"${SHARED_FILES}/aryaos/NetworkManager/system-connections/aryaos-antsdr.nmconnection" \
	"${ROOTFS_DIR}/etc/NetworkManager/system-connections/aryaos-antsdr.nmconnection"
install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-dispatcher" "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.conf" "${ROOTFS_DIR}/etc/"
install -v -m 755 "${SHARED_FILES}/aryaos/run_comitup.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 755 "${SHARED_FILES}/aryaos/comitup-callback.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.json" "${ROOTFS_DIR}/var/lib/comitup/"
install -v -m 755 "${SHARED_FILES}/aryaos/wifi-nuke.py" "${ROOTFS_DIR}/usr/local/sbin/"
## FIXME Deprecated replace old NetworkManager Python module. https://github.com/snstac/aryaos/issues/54 
install -v -m 644 "${SHARED_FILES}/aryaos/NetworkManager.py" "${ROOTFS_DIR}/usr/lib/python3/dist-packages/NetworkManager.py"

## Remove the string ;http://blank.org/ from the connect.html file.
sed --follow-symlinks -i -E -e "s/;http:\/\/blank.org\///" "${ROOTFS_DIR}/usr/share/comitup/web/templates/connect.html"

## Replace default comitup port 80 with 9080
sed --follow-symlinks -i -E -e "s/port=80/port=9080/" "${ROOTFS_DIR}/usr/share/comitup/web/comitupweb.py"
## TODO Add support for main branch of comitup, which uses a different syntax for port configuration.
## sed --follow-symlinks -i -E -e "s/SERVER_PORT = 80/SERVER_PORT = ${COMITUP_WEB_PORT}/" /usr/share/comitup/web/comitupweb.py


# lincot
install -v -m 755 "${SHARED_FILES}/aryaos/get_position.sh" "${ROOTFS_DIR}/usr/local/bin/"
