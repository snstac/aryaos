#!/usr/bin/env bash
# 15-lifecycle.sh — non-destructive lifecycle helper and retained-backup checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

for helper in aryaos-config-backup aryaos-factory-reset aryaos-zeroize aryaos-support-bundle; do
	path="$(command -v "${helper}" 2>/dev/null || true)"
	if [[ -n "${path}" && -x "${path}" ]]; then
		ok "${helper} installed and executable"
	else
		fail "${helper} missing"
	fi
done

backup_list="$(sudo -n aryaos-config-backup list 2>/dev/null || true)"
if python3 -c 'import json,sys; assert isinstance(json.load(sys.stdin).get("backups"), list)' \
	<<<"${backup_list}" 2>/dev/null; then
	ok "backup inventory is valid JSON"
else
	fail "backup inventory is invalid"
fi

bad_backup_modes="$(sudo -n find /var/lib/aryaos/backups -maxdepth 1 -type f \
	-name 'aryaos-config_*.tar.gz' ! -perm 0600 -print 2>/dev/null || true)"
if [[ -z "${bad_backup_modes}" ]]; then
	ok "retained full backups are mode 0600"
else
	fail "retained backup permissions are unsafe: ${bad_backup_modes//$'\n'/ }"
fi

if [[ "$(sudo -n stat -c %a /var/lib/aryaos/backups 2>/dev/null || true)" == "700" ]]; then
	ok "backup directory is mode 0700"
else
	warn "backup directory is absent or not mode 0700 (created on first backup)"
fi

if grep -Fq '(token=)' /usr/local/sbin/aryaos-support-bundle 2>/dev/null \
	&& grep -Fq '(username=)' /usr/local/sbin/aryaos-support-bundle 2>/dev/null \
	&& ! grep -qE 'cp .*client\.key|tar .*aryaos/tls' /usr/local/sbin/aryaos-support-bundle 2>/dev/null; then
	ok "support bundle carries enrollment redaction and no direct TLS-key copy"
else
	fail "support bundle secret-redaction guard is missing"
fi

print_summary
