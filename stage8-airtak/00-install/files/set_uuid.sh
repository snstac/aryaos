#!/bin/bash -e
# Set the system's UUID.
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

set -a
AIRTAK_CONF="/boot/airtak-config.txt"

if [[ -f ${AIRTAK_CONF} ]]; then
  . ${AIRTAK_CONF}
else 
  echo "${AIRTAK_CONF} doesn't exist, initializing."
  echo 'NODE_ID=""' >> ${AIRTAK_CONF}
fi

if ! grep -qs -e 'NODE_ID' ${AIRTAK_CONF}; then
  echo "Adding empty NODE_ID to ${AIRTAK_CONF}"
  echo 'NODE_ID=""' >> ${AIRTAK_CONF}
fi

if [ -z "$NODE_ID" ]; then
  NEW_NODE_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()).upper())")
  echo "NODE_ID not set"
  sed --follow-symlinks -i -E -e "s/NODE_ID.*/NODE_ID=$NEW_NODE_ID/" ${AIRTAK_CONF}
  echo "NODE_ID is now set to: $NEW_NODE_ID"
else
  exit 64
fi