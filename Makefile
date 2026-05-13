# AryaOS Makefile
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

# pi-gen is intentionally not phony: the clone recipe runs only when ./pi-gen is missing.
.PHONY: help sync mkdocs aryaaio ansible-syntax check build build-docker \
	build-docker-clean apt-cacher-up apt-cacher-down apt-cacher-logs apt-cacher-ping \
	clean distclean clean-logs pi-gen-pull skip unskip \
	copyback skip3 skip4 skip5 debauto imxtak

# Optional apt HTTP cache for Docker builds: start `apt-cacher-up`, then:
#   ARYAOS_APT_CACHE=1 make build-docker
# Proxy URL must match where the pi-gen container reaches the cache. Default uses
# Docker's host-gateway alias so the inner build container hits a cache published on the host.
ARYAOS_APT_CACHE ?= 0
ARYAOS_APT_CACHER_PORT ?= 3142
ARYAOS_APT_PROXY_URL ?= http://host.docker.internal:$(ARYAOS_APT_CACHER_PORT)

ifeq ($(ARYAOS_APT_CACHE),1)
PIGEN_APT_CACHE_FLAGS = --add-host=host.docker.internal:host-gateway -e APT_PROXY=$(ARYAOS_APT_PROXY_URL)
else
PIGEN_APT_CACHE_FLAGS =
endif

help:
	@echo "Common targets:"
	@echo "  build / build-docker    Pi-gen image (native needs sudo; Docker uses .aryaos-pigen-*)"
	@echo "  apt-cacher-up/down      apt-cacher-ng (docker compose); cache persists in Docker volume"
	@echo "  apt-cacher-ping         Curl cache UI on http://127.0.0.1:<ARYAOS_APT_CACHER_PORT>"
	@echo "  ARYAOS_APT_CACHE=1      Prefix for build-docker to use APT_PROXY (after apt-cacher-up)"
	@echo "  build-docker-clean      Remove pigen_* containers and .aryaos-pigen-work|deploy only"
	@echo "  clean                   build-docker-clean + pi-gen/work|deploy + deploy/ + build-*.log"
	@echo "  clean-logs              Remove repo-root build-*.log only"
	@echo "  distclean               clean + remove pi-gen/ (run make pi-gen again)"
	@echo "  pi-gen / pi-gen-pull    Clone or update upstream pi-gen (arm64)"
	@echo "  skip / unskip           Touch or remove SKIP for stage0-2 (faster rebuild loop)"
	@echo "  ansible-syntax          ansible-playbook --syntax-check"
	@echo "  mkdocs                  Docs dev server (pip install -r docs/requirements.txt)"
	@echo "  Also: check, debauto, imxtak, aryaaio, sync, copyback — see Makefile"

sync:
	rsync -va ../aryaos 172.17.2.20:~/work/SNS/

mkdocs:
	pip install -r docs/requirements.txt
	mkdocs serve

aryaaio:
	ansible-playbook -i inventory.yml -e '@secret' site.yml -l aryaaio

ansible-syntax:
	ansible-galaxy collection install -r requirements.yml
	ansible-playbook -i localhost, -c local site.yml --syntax-check

check:
	ansible-playbook -i inventory.yml -e '@secret' site.yml -l aryaaio --check


build: pi-gen
	sudo $(CURDIR)/build.sh

# Docker pi-gen: repo at /aryaos:ro; work/deploy in .aryaos-pigen-* at repo root (gitignored) so
# retries reuse stages; use build-docker-clean to wipe cache. NUM_CORES defaults to nproc.
build-docker: pi-gen
	mkdir -p $(CURDIR)/.aryaos-pigen-work $(CURDIR)/.aryaos-pigen-deploy
	cd pi-gen && \
	export GIT_HASH=$$(git -C $(CURDIR) rev-parse HEAD) && \
	export NUM_CORES=$${NUM_CORES:-$$(nproc)} && \
	PIGEN_DOCKER_OPTS="-v $(CURDIR):/aryaos:ro -v $(CURDIR)/.aryaos-pigen-work:/pi-gen/work -v $(CURDIR)/.aryaos-pigen-deploy:/pi-gen/deploy -e NUM_CORES=$$NUM_CORES $(PIGEN_APT_CACHE_FLAGS)" \
	./build-docker.sh -c "$(CURDIR)/config.docker"

apt-cacher-up:
	ARYAOS_APT_CACHER_PORT=$(ARYAOS_APT_CACHER_PORT) docker compose -f "$(CURDIR)/docker-compose.apt-cacher.yml" up -d

apt-cacher-down:
	ARYAOS_APT_CACHER_PORT=$(ARYAOS_APT_CACHER_PORT) docker compose -f "$(CURDIR)/docker-compose.apt-cacher.yml" down

apt-cacher-logs:
	ARYAOS_APT_CACHER_PORT=$(ARYAOS_APT_CACHER_PORT) docker compose -f "$(CURDIR)/docker-compose.apt-cacher.yml" logs -f --tail=100

apt-cacher-ping:
	@curl -sf --max-time 3 -o /dev/null "http://127.0.0.1:$(ARYAOS_APT_CACHER_PORT)/acng-report.html" || \
		( echo "apt-cacher-ng not reachable on http://127.0.0.1:$(ARYAOS_APT_CACHER_PORT)/ (run make apt-cacher-up)" >&2; exit 1 )

# Remove cached pi-gen work/deploy (large) and stray pi-gen docker containers.
build-docker-clean:
	docker rm -f pigen_work pigen_work_cont 2>/dev/null || true
	rm -rf $(CURDIR)/.aryaos-pigen-work $(CURDIR)/.aryaos-pigen-deploy

# Full local artifact wipe: Docker caches, native pi-gen work/deploy, top-level deploy/, agent logs.
clean: build-docker-clean
	rm -rf $(CURDIR)/pi-gen/work $(CURDIR)/pi-gen/deploy
	rm -rf $(CURDIR)/deploy
	rm -f $(CURDIR)/build-*.log

distclean: clean
	rm -rf $(CURDIR)/pi-gen

clean-logs:
	rm -f $(CURDIR)/build-*.log

pi-gen-pull:
	git -C $(CURDIR)/pi-gen pull origin arm64

pi-gen:
	git clone --branch arm64 https://github.com/RPI-Distro/pi-gen.git
	touch ./pi-gen/stage2/SKIP_IMAGES ./pi-gen/stage2/SKIP_NOOBS

skip:
	touch pi-gen/stage0/SKIP
	touch pi-gen/stage1/SKIP
	touch pi-gen/stage2/SKIP

unskip:
	rm -f */SKIP
	rm -f pi-gen/*/SKIP

copyback:
	scp gba@beast.local:~/work/SNS/aryaos/pi-gen/deploy/image*.zip .

skip3:
	touch stage3*/SKIP

skip4:
	touch stage4*/SKIP

skip5:
	touch stage5*/SKIP

debauto:
	ansible-playbook -i inventory.yml -e '@secret' site.yml -l debauto

imxtak:
	ansible-playbook -i inventory.yml -e '@secret' site.yml -l imxtak
