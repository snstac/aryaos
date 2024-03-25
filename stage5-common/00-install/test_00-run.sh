#!/bin/bash -e
# AryaOS test_00-run.sh
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


function gen_aos_service_sudoers() {
    SERVICES=${1:-"$AOS_SERVICES"}
    for srv in ${SERVICES}; do
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl disable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl enable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl start ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl stop ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl restart ${srv}"
    done
}

SUDO_SERVICES="a b c d ${AOS_SERVICES}"
gen_aos_service_sudoers #"${SUDO_SERVICES}" 