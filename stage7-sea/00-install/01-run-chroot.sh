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

cd /usr/share/aiscatcher

rm -rf AIS-catcher
git clone https://github.com/jvde-github/AIS-catcher.git
cd AIS-catcher
git config --global --add safe.directory AIS-catcher
git fetch --all
git reset --hard origin/main

rm -rf build
mkdir -p build
cd build
cmake ..
make
cd ..

cp /usr/share/aiscatcher/AIS-catcher/build/AIS-catcher /usr/local/sbin/aiscatcher

cd /usr/share/aiscatcher
mkdir -p my-plugins
cp AIS-catcher/plugins/* my-plugins/

id aiscatcher || useradd --system aiscatcher
usermod -a -G plugdev aiscatcher
usermod -a -G dialout aiscatcher

chown aiscatcher:aiscatcher -R /usr/share/aiscatcher

systemctl disable hciuart

id aiscot || useradd --system aiscot

python3 -m pip install aiscot --break-system-packages

systemctl daemon-reload
systemctl disable aiscatcher
systemctl disable AISCOT
systemctl disable AryaSea
