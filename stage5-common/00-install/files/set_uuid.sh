#!/bin/bash -e
# AryaOS set_uuid.sh
#
# Set the system's UUID.
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

set -a
ARYAOS_CONF="/boot/aryaos-config.txt"

if [[ -f ${ARYAOS_CONF} ]]; then
  . ${ARYAOS_CONF}
else 
  echo "${ARYAOS_CONF} doesn't exist, initializing."
  echo 'NODE_ID=""' >> ${ARYAOS_CONF}
fi

if ! grep -qs -e 'NODE_ID' ${ARYAOS_CONF}; then
  echo "Adding empty NODE_ID to ${ARYAOS_CONF}"
  echo 'NODE_ID=""' >> ${ARYAOS_CONF}
fi

if [ -z "$NODE_ID" ]; then
  NEW_NODE_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()).upper())")
  echo "NODE_ID not set"
  sed --follow-symlinks -i -E -e "s/NODE_ID.*/NODE_ID=$NEW_NODE_ID/" ${ARYAOS_CONF}
  echo "NODE_ID is now set to: $NEW_NODE_ID"
else
  exit 64
fi