#!/bin/bash -e
# AryaOS 03-run.sh
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

# The main branch of comitup uses a different syntax.
# sed --follow-symlinks -i -E -e "s/SERVER_PORT = 80/SERVER_PORT = ${COMITUP_WEB_PORT}/" /usr/share/comitup/web/comitupweb.py
sed --follow-symlinks -i -E -e "s/port=80/port=${COMITUP_WEB_PORT}/" "${ROOTFS_DIR}/usr/share/comitup/web/comitupweb.py"

install -v -m 644   files/comitup.conf	        "${ROOTFS_DIR}/boot/"
install -v -m 755   files/run_comitup.sh	      "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 755   files/comitup-callback.sh	  "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644   files/comitup.service	      "${ROOTFS_DIR}/lib/systemd/system/"
