#!/bin/bash -e
# 00-run.sh
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

# pi-gen often does not export SHARED_FILES into NN-run.sh; without it,
# "${SHARED_FILES}/dronecot/..." becomes "/dronecot/...".
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

rsync -va "${SHARED_FILES}/dronecot/docker-uas-broker" "${ROOTFS_DIR}/usr/src/"
rsync -va "${SHARED_FILES}/dronecot/docker-uas-sensor" "${ROOTFS_DIR}/usr/src/"

# Script to reset wlan interfaces when restarting dronecot
# FIXME: Add to DroneCOT deb package installer.
install -v -m 755 "${SHARED_FILES}/dronecot/reset_wlan.sh" "${ROOTFS_DIR}/usr/local/sbin/"
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/dronecot.service.d"
install -v -m 0644 "${SHARED_FILES}/dronecot/execprestart.conf" "${ROOTFS_DIR}/etc/systemd/system/dronecot.service.d"

# Inherit site-wide config (COT_URL, PYTAK_TLS_*) from /etc/aryaos; the unit's own
# EnvironmentFile=/etc/default/dronecot loads later, so per-service values override.
if [[ -f "${ROOTFS_DIR}/lib/systemd/system/dronecot.service" ]]; then
	grep -qF "EnvironmentFile=-/etc/aryaos/aryaos-config.txt" "${ROOTFS_DIR}/lib/systemd/system/dronecot.service" || \
		sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=-/etc/aryaos/aryaos-config.txt" "${ROOTFS_DIR}/lib/systemd/system/dronecot.service"
fi
