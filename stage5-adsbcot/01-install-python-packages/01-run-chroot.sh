#!/bin/bash -e
#
# Copyright 2023 Sensors & Signals LLC
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

apt install python3-cryptography

# python3 -m pip install pytak
wget https://github.com/snstac/pytak/archive/refs/heads/multicast_fixes.zip
rm -rf pytak-multicast_fixes
unzip multicast_fixes.zip
cd pytak-multicast_fixes
python3 -m pip install .
cd ..

python3 -m pip install takproto
python3 -m pip install aircot

python3 -m pip install pyrtlsdr
# python3 -m pip install adsbcot[with_pymodes]
python3 -m pip install adsbcot

systemctl enable adsbcot
