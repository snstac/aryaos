#!/bin/bash -e
# 00-run.sh Configures pi image for AIS-catcher install, including serial settings.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

install -v -m 644 "${SHARED_FILES}/aiscot/AIS-catcher_0.58.1_arm64.deb" "${ROOTFS_DIR}/usr/src/"
install -v -m 644 "${SHARED_FILES}/aiscot/ais-catcher.default.conf" "${ROOTFS_DIR}/etc/default/ais-catcher"
install -v -m 644 "${SHARED_FILES}/aiscot/ais-catcher.service"	"${ROOTFS_DIR}/lib/systemd/system/"

