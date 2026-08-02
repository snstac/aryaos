#!/usr/bin/env bash
# 10-storage.sh — install-media and boot-root integrity checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
if [[ -z "${ROOT_SOURCE}" ]]; then
	fail "cannot resolve root filesystem device"
else
	root_state="$(sudo -n tune2fs -l "${ROOT_SOURCE}" 2>/dev/null | sed -n 's/^Filesystem state:[[:space:]]*//p')"
	if [[ -z "${root_state}" ]]; then
		fail "cannot read root filesystem state from ${ROOT_SOURCE}"
	elif [[ "${root_state,,}" == *error* ]]; then
		fail "root filesystem state is '${root_state}'"
	else
		ok "root filesystem state is ${root_state}"
	fi
fi

kernel_fs_errors="$(sudo -n journalctl -k -b --no-pager -o cat 2>/dev/null \
	| grep -Ei 'EXT[234]-fs (error|warning)|I/O error|Buffer I/O error|mmc.*(error|timeout)' || true)"
if [[ -n "${kernel_fs_errors}" ]]; then
	fail "kernel reported filesystem or install-media errors this boot"
else
	ok "no kernel filesystem/install-media errors this boot"
fi

CMDLINE=/boot/firmware/cmdline.txt
if [[ -f "${CMDLINE}" && -n "${ROOT_SOURCE}" ]]; then
	# `wc -l` reports zero for a valid single line without a trailing newline.
	cmdline_lines="$(awk 'END { print NR }' "${CMDLINE}")"
	root_partuuid="$(lsblk -n -o PARTUUID "${ROOT_SOURCE}" | tr -d '[:space:]')"
	if [[ "${cmdline_lines}" != "1" ]]; then
		fail "boot cmdline has ${cmdline_lines} lines (want exactly one)"
	elif [[ -z "${root_partuuid}" ]]; then
		fail "root partition has no PARTUUID"
	elif grep -qw "root=PARTUUID=${root_partuuid}" "${CMDLINE}"; then
		ok "boot cmdline names the installed root PARTUUID"
	else
		fail "boot cmdline root does not match ${ROOT_SOURCE}"
	fi
else
	skip "Raspberry Pi boot cmdline not present"
fi

print_summary
