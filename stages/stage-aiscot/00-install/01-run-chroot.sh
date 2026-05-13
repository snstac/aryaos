#!/bin/bash -e
# AryaOS 01-run-chroot.sh
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


# Ensure AIS-catcher service user exists and is in required groups
if ! id -u ais-catcher >/dev/null 2>&1; then
    adduser --system --gecos 'AIS-catcher Service User' ais-catcher
fi

usermod -aG plugdev,dialout ais-catcher

dpkg -i /usr/src/AIS-catcher_0.58.1_arm64.deb

COCKPIT_AISCOT_DEB_URL='https://github.com/snstac/cockpit-aiscot/releases/download/v1.1.0/cockpit-aiscot_1.1.0_all.deb'
curl -fsSL -o /usr/src/cockpit-aiscot_1.1.0_all.deb "${COCKPIT_AISCOT_DEB_URL}"
dpkg -i /usr/src/cockpit-aiscot_1.1.0_all.deb

# Ensure apt-listchanges stays off before export-image finalise (see stage-base note).
if dpkg -s apt-listchanges >/dev/null 2>&1; then
	echo 'apt-listchanges apt-listchanges/frontend select none' | debconf-set-selections
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow apt-listchanges || true
fi

# Add the line EnvironmentFile=/etc/aryaos/aryaos-config.txt to /lib/systemd/system/aiscot.service if the line does not already exist
# grep -qxF "EnvironmentFile=-/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service || sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=-/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service
