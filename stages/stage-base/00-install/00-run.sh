#!/bin/bash -e
# 00-run.sh
#
# Establishes base configuration for AryaOS.
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

# SHARED_FILES should be set, if not, set it to ../shared_files
# SHARED_FILES=${SHARED_FILES:-../../shared_files}

# ZeroTier
echo "SHARED_FILES=${SHARED_FILES}"
echo $(pwd)
ls -al
ls -al ..
install -v -m 755 "${SHARED_FILES:-../../../shared_files}/base/install_zt.sh" "${ROOTFS_DIR}/usr/src/"
