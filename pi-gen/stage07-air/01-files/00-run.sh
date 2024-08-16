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

install -v -m 600 "${SHARED_FILES}/air/blacklist-rtl-sdr.conf"	"${ROOTFS_DIR}/etc/modprobe.d/"
install -v -m 600 "${SHARED_FILES}/air/flightaware-apt-repository_1.2_all.deb"	"${ROOTFS_DIR}/usr/src/flightaware-apt-repository_1.2_all.deb"
