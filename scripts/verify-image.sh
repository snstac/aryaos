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

require_path() {
	if [[ -e "${MNT}$1" ]]; then ok "$1"; else fail "$1 missing"; fi
}
forbid_path() {
	if [[ ! -e "${MNT}$1" ]]; then ok "$1 absent"; else fail "$1 present (must not ship)"; fi
}
require_unit() {
	local u="$1" d
	for d in etc/systemd/system lib/systemd/system usr/lib/systemd/system; do
		if [[ -f "${MNT}/${d}/${u}" ]]; then ok "unit ${u} (${d})"; return; fi
	done
	fail "unit ${u} not found in any systemd unit dir"
}
require_pkg() {
	if awk -v pkg="$1" 'BEGIN{RS=""} $0 ~ "Package: "pkg"\n" && /Status: install ok installed/ {found=1} END{exit !found}' \
		"${MNT}/var/lib/dpkg/status" 2>/dev/null; then
		ok "package $1 installed"
	else
		fail "package $1 not installed"
	fi
}

echo "== AryaOS image content checks: ${IMG##*/} (lab=${LAB_EXPECTED}) =="

# Core identity and config (stage-aryaos)
require_path /etc/aryaos-release
require_path /etc/aryaos-version
require_path /etc/aryaos/aryaos-config.txt
require_path /etc/sudoers.d/aryaos
require_path /usr/local/sbin/aryaos-firstboot.sh
require_path /etc/systemd/system/aryaos-firstboot.service

# Portal (stage-aryaos)
require_path /var/www/html/index.html
require_path /usr/lib/cgi-bin/aryaos-portal-status
require_path /etc/lighttpd/conf-enabled/95-aryaos-cockpit-https.conf

# GNSS (stage-aryaos)
require_path /etc/default/gpsd

# Sensor / CoT stack
require_pkg dhbridge
require_unit adsbcot.service
require_unit aiscot.service
require_unit dronecot.service
require_unit lincot.service
require_unit charontak.service
require_unit readsb.service

# Node-RED (stage-node-red)
require_path /home/node-red/.node-red/flows.json

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
