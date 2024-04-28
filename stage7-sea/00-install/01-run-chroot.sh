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
dpkg -i /home/pi/AIS-catcher_0.58.0_arm64.deb
id aiscatcher || useradd --system aiscatcher
usermod -a -G plugdev aiscatcher
usermod -a -G dialout aiscatcher
chown aiscatcher:aiscatcher -R /usr/share/aiscatcher


# FIXME: Lost child
systemctl disable hciuart


# AISCOT
id aiscot || useradd --system aiscot
python3 -m pip install --break-system-packages aiscot


# Disable everything
systemctl disable aiscatcher
systemctl disable AISCOT
systemctl disable AryaSea
