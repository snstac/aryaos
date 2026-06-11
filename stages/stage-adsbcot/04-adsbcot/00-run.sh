#!/bin/bash -e
# AryaOS 00-run.sh
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

# pi-gen often does not export SHARED_FILES into NN-run.sh (see stage-aryaos / stage-node-red).
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

# common
install -v -m 755 "${SHARED_FILES}/adsbcot/89-skyaware.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"
install -v -m 644 "${SHARED_FILES}/adsbcot/osmocom-rtl-sdr.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"
install -v -m 600 "${SHARED_FILES}/adsbcot/blacklist-rtl-sdr.conf"	"${ROOTFS_DIR}/etc/modprobe.d/"
install -v -m 755 "${SHARED_FILES}/adsbcot/tar1090-install.sh" "${ROOTFS_DIR}/usr/src/"

# dump1090-fa
install -v -m 644 "${SHARED_FILES}/adsbcot/dump1090-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system/dump1090-fa.service.d"
install -v -m 0644 "${SHARED_FILES}/adsbcot/systemd/dump1090-fa.service.d/aryaos-conflicts.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/dump1090-fa.service.d/aryaos-conflicts.conf"
install -v -m 644 "${SHARED_FILES}/adsbcot/dump978-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"

install -d -m 0755 "${ROOTFS_DIR}/usr/local/libexec/aryaos"
install -v -m 0755 "${SHARED_FILES}/adsbcot/apply-dump978-serial.sh" "${ROOTFS_DIR}/usr/local/libexec/aryaos/apply-dump978-serial.sh"
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system/dump978-fa.service.d"
install -v -m 0644 "${SHARED_FILES}/adsbcot/systemd/dump978-fa.service.d/aryaos-uat-serial.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/dump978-fa.service.d/aryaos-uat-serial.conf"
install -v -m 0644 "${SHARED_FILES}/adsbcot/99-aryaos-dump978-uat-rtlsdr.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"


# readsb
# Kept for chroot: dpkg overwrites /lib/systemd/system/readsb.service with the stock unit.
install -v -m 644 "${SHARED_FILES}/adsbcot/readsb.service" "${ROOTFS_DIR}/usr/src/readsb.service.aryaos"
install -v -m 755 "${SHARED_FILES}/adsbcot/run_readsb.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "${SHARED_FILES}/adsbcot/readsb.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system/readsb.service.d"
install -v -m 0644 "${SHARED_FILES}/adsbcot/systemd/readsb.service.d/aryaos-conflicts.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/readsb.service.d/aryaos-conflicts.conf"
install -v -m 755 "${SHARED_FILES}/adsbcot/readsb-set-location.sh" "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 "${SHARED_FILES}/adsbcot/readsb-gain.sh" "${ROOTFS_DIR}/usr/local/bin/"

# cockpit-adsbcot installs from the snstac apt repo in 01-run-chroot.sh
# (repo configured by stage-pytak, which runs earlier in STAGE_LIST).
