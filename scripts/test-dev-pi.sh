#!/usr/bin/env bash
# Sync (optional) and verify AryaOS on the lab Pi (aryaos-dev-pi).
# Thin wrapper around scripts/aryaos-test/run.sh for backward compatibility.
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
cd "${REPO_ROOT}"

if [[ "${ARYAOS_DEV_PI_SYNC:-0}" == 1 ]]; then
	echo "==> sync-to-dev-pi"
	./scripts/sync-to-dev-pi.sh
	echo "==> sync-portal-review"
	ARYAOS_SSH="${ARYAOS_SSH:-pi@aryaos-dev-pi}" ./scripts/sync-portal-review.sh
fi

exec ./scripts/aryaos-test/run.sh "$@"
