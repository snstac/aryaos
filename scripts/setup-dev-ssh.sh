#!/usr/bin/env bash
# Deprecated compatibility entry point. Dynamic discovery no longer writes
# ~/.ssh/config; this now opens the discovered device directly.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "warning: setup-dev-ssh.sh is deprecated; using dynamic device discovery" >&2
exec "${REPO_ROOT}/scripts/aryaos-dev-device" ssh "$@"
