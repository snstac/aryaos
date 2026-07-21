#!/usr/bin/env bash
# Build the AryaOS overlay Debian package from shared_files.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_META="${REPO_ROOT}/packaging/aryaos-overlay"
SHARED="${REPO_ROOT}/shared_files"
VERSION="$(tr -d '[:space:]' < "${SHARED}/aryaos/aryaos-version")"
OUT_DIR="${ARYAOS_DEB_OUT_DIR:-${REPO_ROOT}/deploy/debs}"
BUILD_ROOT="$(mktemp -d)"
PKG_ROOT="${BUILD_ROOT}/aryaos-overlay"

cleanup() {
	rm -rf "${BUILD_ROOT}"
}
trap cleanup EXIT

install_file() {
	local mode="$1"
	local src="$2"
	local dest="$3"
	install -D -m "${mode}" "${src}" "${PKG_ROOT}${dest}"
}

install_tree() {
	local src="$1"
	local dest="$2"
	install -d -m 0755 "${PKG_ROOT}${dest}"
	rsync -a --delete "${src}/" "${PKG_ROOT}${dest}/"
	find "${PKG_ROOT}${dest}" -type d -exec chmod 0755 {} +
	find "${PKG_ROOT}${dest}" -type f -exec chmod 0644 {} +
}

mkdir -p "${PKG_ROOT}/DEBIAN" "${OUT_DIR}"
sed "s/@VERSION@/${VERSION}/" "${PKG_META}/control" > "${PKG_ROOT}/DEBIAN/control"
if [[ -s "${PKG_META}/conffiles" ]]; then
	install -m 0644 "${PKG_META}/conffiles" "${PKG_ROOT}/DEBIAN/conffiles"
fi
install -m 0755 "${PKG_META}/postinst" "${PKG_ROOT}/DEBIAN/postinst"
install -m 0755 "${PKG_META}/prerm" "${PKG_ROOT}/DEBIAN/prerm"

install_file 0644 "${SHARED}/aryaos/motd" "/usr/share/aryaos/defaults/motd"
install_file 0644 "${SHARED}/aryaos/issue" "/usr/share/aryaos/defaults/issue"
install_file 0644 "${SHARED}/aryaos/issue.net" "/usr/share/aryaos/defaults/issue.net"
install_file 0644 "${SHARED}/aryaos/aryaos-release" "/etc/aryaos-release"
install_file 0644 "${SHARED}/aryaos/aryaos-version" "/etc/aryaos-version"
install_file 0644 "${SHARED}/aryaos/README-aryaos.txt" "/README-aryaos.txt"
install_file 0440 "${SHARED}/aryaos/aryaos.sudoers" "/etc/sudoers.d/aryaos"
install_file 0644 "${SHARED}/aryaos/aryaos-config.txt" "/usr/share/aryaos/defaults/aryaos-config.txt"
install_file 0644 "${SHARED}/aryaos/gpsd.default" "/usr/share/aryaos/defaults/gpsd.default"
install_file 0644 "${SHARED}/charontak/charontak.ini" "/usr/share/aryaos/defaults/charontak.ini"

install_file 0755 "${SHARED}/aryaos/aryaos-import-tak-dp" "/usr/local/sbin/aryaos-import-tak-dp"
install_file 0755 "${SHARED}/aryaos/aryaos-tak-dp-importd" "/usr/local/sbin/aryaos-tak-dp-importd"
# Authenticated Cockpit backend for TAK data-package/enrollment import (replaces
# the retired unauthenticated portal CGI aryaos-tak-dp-upload).
install_file 0755 "${SHARED}/aryaos/aryaos-tak-dp-import" "/usr/local/sbin/aryaos-tak-dp-import"
install_file 0755 "${SHARED}/aryaos/patch-cockpit-aryaos-dp" "/usr/local/sbin/patch-cockpit-aryaos-dp"
install_file 0755 "${SHARED}/aryaos/aryaos-device-suffix.sh" "/usr/local/sbin/aryaos-device-suffix.sh"
install_file 0755 "${SHARED}/aryaos/aryaos-firstboot.sh" "/usr/local/sbin/aryaos-firstboot.sh"
install_file 0755 "${SHARED}/aryaos/aryaos-gps-time-sync" "/usr/local/sbin/aryaos-gps-time-sync"
install_file 0755 "${SHARED}/aryaos/aryaos-lincot-remarks" "/usr/local/sbin/aryaos-lincot-remarks"
install_file 0755 "${SHARED}/aryaos/aryaos-cot-detail" "/usr/local/sbin/aryaos-cot-detail"
install_file 0755 "${SHARED}/aryaos/aryaos-neighbord" "/usr/local/sbin/aryaos-neighbord"
install_file 0755 "${SHARED}/aryaos/get_throttled.sh" "/usr/local/sbin/get_throttled.sh"
install_file 0755 "${SHARED}/aryaos/aryaos-update" "/usr/local/sbin/aryaos-update"
install_file 0755 "${SHARED}/aryaos/aryaos-support-bundle" "/usr/local/sbin/aryaos-support-bundle"
install_file 0755 "${SHARED}/aryaos/aryaos-set-nodered-password" "/usr/local/sbin/aryaos-set-nodered-password"
install_file 0755 "${SHARED}/aryaos/aryaos-sdr" "/usr/local/sbin/aryaos-sdr"
install_file 0755 "${SHARED}/aryaos/aryaos-role" "/usr/local/sbin/aryaos-role"
install_file 0755 "${SHARED}/aryaos/aryaos-config-backup" "/usr/local/sbin/aryaos-config-backup"
install_file 0755 "${SHARED}/aryaos/aryaos-factory-reset" "/usr/local/sbin/aryaos-factory-reset"
install_file 0755 "${SHARED}/aryaos/aryaos-zeroize" "/usr/local/sbin/aryaos-zeroize"
install_file 0755 "${SHARED}/aryaos/aryaos-radio" "/usr/local/sbin/aryaos-radio"
install_file 0755 "${SHARED}/aryaos/run_comitup.sh" "/usr/local/sbin/run_comitup.sh"
install_file 0755 "${SHARED}/aryaos/comitup-callback.sh" "/usr/local/sbin/comitup-callback.sh"
install_file 0755 "${SHARED}/aryaos/wifi-nuke.py" "/usr/local/sbin/wifi-nuke.py"
install_file 0755 "${SHARED}/aryaos/get_position.sh" "/usr/local/bin/get_position.sh"

install_file 0644 "${SHARED}/aryaos/aryaos-firstboot.service" "/etc/systemd/system/aryaos-firstboot.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-gps-time-sync.service" "/etc/systemd/system/aryaos-gps-time-sync.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-tak-dp-importd.service" "/etc/systemd/system/aryaos-tak-dp-importd.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-neighbord.service" "/etc/systemd/system/aryaos-neighbord.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-update.service" "/etc/systemd/system/aryaos-update.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-factory-reset.service" "/etc/systemd/system/aryaos-factory-reset.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-zeroize.service" "/etc/systemd/system/aryaos-zeroize.service"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-radio-silence.service" "/etc/systemd/system/aryaos-radio-silence.service"
# EMCON gate: keep the radio users from starting (and un-blocking the radios)
# while /etc/aryaos/emcon exists.
install_file 0644 "${SHARED}/aryaos/systemd/comitup.service.d/emcon.conf" "/etc/systemd/system/comitup.service.d/emcon.conf"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-bt-pan.service.d/emcon.conf" "/etc/systemd/system/aryaos-bt-pan.service.d/emcon.conf"
install_file 0644 "${SHARED}/aryaos/systemd/aryaos-bt-ready.service.d/emcon.conf" "/etc/systemd/system/aryaos-bt-ready.service.d/emcon.conf"
# Pin nodered.service to the node-red user (upstream unit runs as root out of
# /root/.node-red with no adminAuth = unauthenticated root-privileged admin API).
install_file 0644 "${SHARED}/aryaos/systemd/nodered.service.d/aryaos.conf" "/etc/systemd/system/nodered.service.d/aryaos.conf"
install_file 0644 "${SHARED}/aryaos/zram-generator.conf" "/etc/systemd/zram-generator.conf"
install_file 0644 "${SHARED}/aryaos/systemd/gpsd.socket.d/socket-group.conf" "/etc/systemd/system/gpsd.socket.d/socket-group.conf"
install_file 0644 "${SHARED}/aryaos/systemd/lighttpd.service.d/aryaos-netlink.conf" "/etc/systemd/system/lighttpd.service.d/aryaos-netlink.conf"

# Offline documentation: ship the rendered MkDocs site in the portal so the
# device serves it at https://<host>/docs/ with no internet. CI pre-builds it
# into the html tree; for local host builds, render it here if mkdocs is
# available. Never fatal — a build host without mkdocs just omits /docs.
DOCS_OUT="${SHARED}/aryaos/html/docs"
if [[ ! -f "${DOCS_OUT}/index.html" ]] && command -v mkdocs >/dev/null 2>&1; then
	( cd "${REPO_ROOT}" && mkdocs build --site-dir "${DOCS_OUT}" ) \
		|| echo "note: mkdocs build failed; portal /docs will be absent" >&2
fi

install_tree "${SHARED}/aryaos/html" "/var/www/html"
install_file 0755 "${SHARED}/aryaos/cgi-bin/aryaos-portal-status" "/usr/lib/cgi-bin/aryaos-portal-status"
# NOTE: aryaos-tak-dp-upload CGI intentionally NOT installed — the mutating TAK
# import moved to the authenticated Cockpit backend aryaos-tak-dp-import.
install_file 0755 "${SHARED}/aryaos/cgi-bin/aryaos-neighbors" "/usr/lib/cgi-bin/aryaos-neighbors"

install_file 0644 "${SHARED}/aryaos/cockpit.conf" "/etc/cockpit/cockpit.conf"
install_file 0644 "${SHARED}/aryaos/cockpit.socket-listen.conf" "/etc/systemd/system/cockpit.socket.d/listen.conf"
install_file 0644 "${SHARED}/aryaos/cockpit/branding.css" "/usr/share/aryaos/cockpit/branding.css"
install_file 0644 "${SHARED}/aryaos/94-aryaos-setenv-module.conf" "/etc/lighttpd/conf-available/94-aryaos-setenv-module.conf"
install_file 0644 "${SHARED}/aryaos/95-aryaos-cockpit-https.conf" "/etc/lighttpd/conf-available/95-aryaos-cockpit-https.conf"
install_file 0644 "${SHARED}/aryaos/96-aryaos-cloudtak-proxy.conf" "/etc/lighttpd/conf-available/96-aryaos-cloudtak-proxy.conf"
install_file 0644 "${SHARED}/aryaos/99-aryaos-recorder.conf" "/etc/lighttpd/conf-available/99-aryaos-recorder.conf"

install_file 0600 "${SHARED}/aryaos/NetworkManager/system-connections/aryaos-antsdr.nmconnection" "/etc/NetworkManager/system-connections/aryaos-antsdr.nmconnection"

install_file 0644 "${SHARED}/aryaos/sshd/50-aryaos.conf" "/etc/ssh/sshd_config.d/50-aryaos.conf"
install_file 0644 "${SHARED}/aryaos/sysctl/90-aryaos-hardening.conf" "/etc/sysctl.d/90-aryaos-hardening.conf"
install_file 0644 "${SHARED}/aryaos/fail2ban/aryaos.local" "/etc/fail2ban/jail.d/aryaos.local"
install_file 0644 "${SHARED}/aryaos/apt/20auto-upgrades" "/etc/apt/apt.conf.d/20auto-upgrades"
install_file 0644 "${SHARED}/aryaos/apt/52unattended-upgrades-aryaos" "/etc/apt/apt.conf.d/52unattended-upgrades-aryaos"
for svc_xml in "${SHARED}/aryaos/firewalld/services/"*.xml; do
	install_file 0644 "${svc_xml}" "/etc/firewalld/services/$(basename "${svc_xml}")"
done
for zone_xml in "${SHARED}/aryaos/firewalld/zones/"*.xml; do
	install_file 0644 "${zone_xml}" "/etc/firewalld/zones/$(basename "${zone_xml}")"
done
install_file 0755 "${SHARED}/aryaos/99-aryaos-dispatcher" "/etc/NetworkManager/dispatcher.d/99-aryaos-dispatcher"


DEB_PATH="${OUT_DIR}/aryaos-overlay_${VERSION}_all.deb"
dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_PATH}"
printf '%s\n' "${DEB_PATH}"
