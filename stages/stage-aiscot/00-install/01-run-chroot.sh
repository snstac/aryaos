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


# AIS-catcher
id ais-catcher || adduser --system --gecos 'AIS-catcher Service User' ais-catcher

usermod -a -G plugdev ais-catcher
usermod -a -G dialout ais-catcher

chown node-red /etc/default/ais-catcher

dpkg -i /usr/src/AIS-catcher_0.58.1_arm64.deb

# Add the line EnvironmentFile=/etc/aryaos/aryaos-config.txt to /lib/systemd/system/aiscot.service if the line does not already exist
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service || sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service
