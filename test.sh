#!/usr/bin/env bash
# Tests for AryaOS Ansible Playbook, using Docker.
#
# This script will create:
#   1. A temporary SSH key;
#   2. A temporary directory;
#   3. A temporary inventory file; and
#   4. A temporary Docker container.
# The container will be built from the Dockerfile in the same directory as this script.
# The container will be started, and the Ansible playbook will be run against it.
# The container will be stopped and removed, and the temporary directory will be removed.
#
# This script is intended to be run from the root of the repository.
#
# Usage:
#   ./test.sh
#
# Requirements:
#   - Docker
#   - Ansible
#
# Environment variables:
#   - USER: The user to use for the SSH connection. Default: root
#
# Exit codes:
#   - 0: Success
#   - 1: Failure
#
# Apache License 2.0
#
# SPDX-License-Identifier: Apache-2.0
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

set -euo pipefail

TAG="aryaos-ansible-docker-test"
identifier="${RANDOM}"
NAME="${TAG}-${identifier}"
base_dir="$(dirname "$(readlink -f "$0")")"

function cleanup() {
    container_id=$(docker inspect --format="{{.Id}}" "${NAME}" ||:)
    if [[ -n "${container_id}" ]]; then
        echo "Cleaning up container ${NAME}"
        sleep 120
        docker rm --force "${container_id}"
    fi
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        echo "Cleaning up tepdir ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

function setup_tempdir() {
    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}".XXXXXXXX)
    export TEMP_DIR
}

function create_temporary_ssh_id() {
    ssh-keygen -b 2048 -t rsa -C "${NAME}" -f "${TEMP_DIR}/id_rsa" -N ""
    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function start_container() {
    docker build --tag "${TAG}" \
        --file "${base_dir}/Dockerfile" \
        "${TEMP_DIR}"
        # --build-arg USER \
    docker run -d -P -p 2200:22 --name "${NAME}" "${TAG}"
    # CONTAINER_ADDR=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${NAME}")
    CONTAINER_ADDR="127.0.0.1"
    export CONTAINER_ADDR
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"

    cat > "${TEMP_INVENTORY_FILE}" << EOL
[target_group]
${CONTAINER_ADDR}:22
[target_group:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export TEMP_INVENTORY_FILE
}

function run_ansible_playbook() {
    ANSIBLE_CONFIG="${base_dir}/ansible.cfg"
    ansible-playbook -e "ansible_port=2200" -i "${TEMP_INVENTORY_FILE}" -vvv "${base_dir}/site.yml"
}

function copy_shared_files() {
    cp -r "${base_dir}/shared_files" "${TEMP_DIR}"
}


echo "TAG: ${TAG}"
echo "NAME: ${NAME}"
echo "base_dir: ${base_dir}"

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
create_temporary_ssh_id
start_container
setup_test_inventory
copy_shared_files
run_ansible_playbook
