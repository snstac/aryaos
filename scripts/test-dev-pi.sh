#!/usr/bin/env bash
# Deprecated compatibility alias for test-dev-device.sh.
#
# Usage (repo root):
#   ./scripts/test-dev-pi.sh              # verify only
#   ARYAOS_DEV_PI_SYNC=1 ./scripts/test-dev-pi.sh   # rsync + portal review, then verify
#   make test-dev-pi
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "warning: test-dev-pi.sh is deprecated; use test-dev-device.sh" >&2
exec "${REPO_ROOT}/scripts/test-dev-device.sh" "$@"
