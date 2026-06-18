#!/bin/bash
# Start dhbridge with a Bluetooth broadcast name tied to the AryaOS hostname.

set -euo pipefail

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
export DHBRIDGE_BT_NAME="${HOSTNAME_SHORT}"

exec /usr/bin/dhbridge "$@"
