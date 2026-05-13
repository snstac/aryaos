#!/usr/bin/env bash
# Run make build-docker with a timestamped log at repo root (stdout/stderr tee).
# Exit status matches make (pipefail).
#
# Optional: start apt caching first — `make apt-cacher-up`, then for example:
#   ARYAOS_APT_CACHE=1 make build-docker
# (see Makefile and docs/build.md).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="${ROOT}/build-$(date +%Y%m%d-%H%M%S).log"

cd "$ROOT"
echo "Logging to: $LOG" | tee "$LOG"
make build-docker 2>&1 | tee -a "$LOG"
