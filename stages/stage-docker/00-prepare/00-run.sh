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

install -m 0755 -d "${ROOTFS_DIR}/etc/apt/keyrings"
install -v -m 644 files/docker.asc "${ROOTFS_DIR}/etc/apt/keyrings/docker.asc"

chmod a+r "${ROOTFS_DIR}/etc/apt/keyrings/docker.asc"

install -v -m 644 files/docker.list "${ROOTFS_DIR}/etc/apt/sources.list.d/docker.list"
