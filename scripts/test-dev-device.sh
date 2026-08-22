#!/usr/bin/env bash
# Sync (optional) and verify a discovered or explicitly targeted AryaOS device.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

if [[ "${ARYAOS_DEV_DEVICE_SYNC:-${ARYAOS_DEV_PI_SYNC:-0}}" == 1 ]]; then
	echo "==> sync-to-dev-device"
	./scripts/sync-to-dev-pi.sh
	echo "==> sync-portal-review"
	./scripts/sync-portal-review.sh
fi

exec ./scripts/aryaos-test/run.sh "$@"
