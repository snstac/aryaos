#!/bin/bash -e
# Install CloudTAK standalone shim stack under /opt/cloudtak.
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
# "${SHARED_FILES}/cloudtak/..." becomes "/cloudtak/...".
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

install -d "${ROOTFS_DIR}/opt/cloudtak"
install -v -m 0644 "${SHARED_FILES}/cloudtak/docker-compose.yml" "${ROOTFS_DIR}/opt/cloudtak/"
install -v -m 0644 "${SHARED_FILES}/cloudtak/README.md" "${ROOTFS_DIR}/opt/cloudtak/"
install -v -m 0644 "${SHARED_FILES}/cloudtak/Dockerfile.web" "${ROOTFS_DIR}/opt/cloudtak/"
install -v -m 0644 "${SHARED_FILES}/cloudtak/nginx-cloudtak-web.conf" "${ROOTFS_DIR}/opt/cloudtak/"
rsync -va "${SHARED_FILES}/cloudtak/shim/" "${ROOTFS_DIR}/opt/cloudtak/shim/"

install -v -m 0644 "${SHARED_FILES}/cloudtak/cloudtak-shim.service" \
	"${ROOTFS_DIR}/etc/systemd/system/cloudtak-shim.service"
