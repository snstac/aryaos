#!/bin/bash -e
# AryaOS Node-RED stage — fetch upstream linux installer + copy AryaOS config.
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

# Pinned release + checksum: "latest" broke when upstream v2.0.0 renamed the deb asset
# (update-nodejs-and-nodered-deb → install-update-nodered-deb). v1.1.2 is the last release
# with the script this stage and 01-run-chroot.sh expect. Bump tag and sha256 together.
NODE_RED_LINUX_INSTALLER_URL='https://github.com/node-red/linux-installers/releases/download/v1.1.2/update-nodejs-and-nodered-deb'
NODE_RED_LINUX_INSTALLER_SHA256='ccea2dc0c21046182fdac9101e1578793f83b00479e9688f283ced8ce2db5093'

# Same pattern as stage-aryaos: pi-gen does not always export SHARED_FILES into NN-run.sh.
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

mkdir -p "${ROOTFS_DIR}/usr/src"
curl -fsSL "${NODE_RED_LINUX_INSTALLER_URL}" -o "${ROOTFS_DIR}/usr/src/update-nodejs-and-nodered-deb"
echo "${NODE_RED_LINUX_INSTALLER_SHA256}  ${ROOTFS_DIR}/usr/src/update-nodejs-and-nodered-deb" | sha256sum -c -
chmod +x "${ROOTFS_DIR}/usr/src/update-nodejs-and-nodered-deb"

# Node-RED sudoers: consolidated in stage-aryaos (/etc/sudoers.d/aryaos). No node-red fragment.
mkdir -p "${ROOTFS_DIR}/home/node-red/.node-red"
install -v -m 644 "${SHARED_FILES}/node-red/settings.js" "${ROOTFS_DIR}/home/node-red/.node-red/settings.js"
install -v -m 644 "${SHARED_FILES}/node-red/package.json" "${ROOTFS_DIR}/home/node-red/.node-red/package.json"
install -v -m 644 "${SHARED_FILES}/node-red/package-lock.json" "${ROOTFS_DIR}/home/node-red/.node-red/package-lock.json"
install -v -m 644 "${SHARED_FILES}/node-red/aryaos_flows.json" "${ROOTFS_DIR}/home/node-red/.node-red/"
cat "${ROOTFS_DIR}/home/node-red/.node-red/aryaos_flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"

# Pin nodered.service to the node-red user + /home/node-red (the upstream unit runs
# as root out of /root/.node-red, whose stock settings.js has no adminAuth — that
# would expose an unauthenticated, root-privileged Node-RED admin API on :1880).
install -v -D -m 644 "${SHARED_FILES}/aryaos/systemd/nodered.service.d/aryaos.conf" \
	"${ROOTFS_DIR}/etc/systemd/system/nodered.service.d/aryaos.conf"
