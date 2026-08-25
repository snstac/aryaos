# Agent instructions: AryaOS image build

> **Current state & open tasks:** see [docs/agent-handoff.md](docs/agent-handoff.md) (2026-06-23).


Short procedural notes for automated assistants running or watching pi-gen builds in this repo. Human-oriented detail lives in [docs/build.md](docs/build.md).

## Technical writing

Use the pragmatic Simple English rules in
[`docs/reference/writing-style.md`](docs/reference/writing-style.md) for active
technical documentation and AryaOS-owned operator text.

- Classify text as procedural or descriptive before you write it.
- Use no more than 20 words in a procedural sentence.
- Use no more than 25 words in a descriptive sentence.
- Use active voice and simple tenses.
- Put one instruction in each sentence.
- Put a condition before its command.
- Use `can`, `will`, and `must`. Do not use ambiguous modal verbs.
- Preserve code, commands, identifiers, paths, product names, and quoted errors.
- Preserve technical facts and machine-readable interfaces.
- Run `python3 -m unittest scripts.test_docs_style -v` after text changes.

## Prerequisites

- **Docker** daemon running (`docker ps` works).
- **Disk**: pi-gen `work/` and deploy output can consume hundreds of gigabytes. Leave ample free space.
- **Working directory**: repository root (where `Makefile` and `config.docker` live).
- **Optional**: `NUM_CORES` exported before build to tune parallelism inside the container (defaults to `nproc` via the Makefile).

## Prefer `make build-docker` (agents)

Use this for unattended builds: it avoids interactive host **sudo** used by `make build`.

### Optional apt cache (faster rebuilds)

1. **`make apt-cacher-up`** - starts **`apt-cacher-ng`** ([`docker-compose.apt-cacher.yml`](docker-compose.apt-cacher.yml)). Cache persists in Docker volume **`aryaos_apt_cacher_cache`**.
2. **`ARYAOS_APT_CACHE=1 make build-docker`** - passes **`APT_PROXY`** into pi-gen (same mechanism as upstream **`APT_PROXY`** / stage0 `51cache`). **`make apt-cacher-ping`** checks the cache from the host on **`127.0.0.1:${ARYAOS_APT_CACHER_PORT:-3142}`**.

- **Config**: [config.docker](config.docker) - repo bind-mounted read-only at **`/aryaos`**, matching the Makefile's `PIGEN_DOCKER_OPTS`.
- **Caches / output** (gitignored): **`.aryaos-pigen-work/`** -> `/pi-gen/work`, **`.aryaos-pigen-deploy/`** -> `/pi-gen/deploy`.
- **Upstream tree**: First build ensures **`./pi-gen`** exists (Makefile `pi-gen` target clones when needed). Later builds reuse the directory.

Do **not** default to **`make build`** / **`./build.sh`** unless the user asks: those invoke **`sudo`** and can block on a password.

### Logged build (recommended for monitoring after the fact)

From repo root:

```bash
./scripts/agent-build-docker.sh
```

This runs `make build-docker` and mirrors output to **`build-YYYYMMDD-HHMMSS.log`** at the repo root.
It exits with the same status as `make`. Use the log to review output after the command finishes.

## Faster iteration

After a full base image exists, **`make skip`** adds `SKIP` markers for pi-gen `stage0`-`stage2`. **`make unskip`** removes them. Use only when the user wants shorter loops while editing AryaOS stages.

## Monitoring checklist

1. **Terminal**: `make build-docker` / `agent-build-docker.sh` runs for a long time. Use a terminal session with enough timeout or run in the background and poll.
2. **Docker**: **`docker ps`**. **`docker logs`** on pi-gen containers (e.g. **`pigen_work`**, **`pigen_work_cont`** - see **`make build-docker-clean`**).
3. **Disk progress**: Activity under **`.aryaos-pigen-work/`**. Finished artifacts under **`.aryaos-pigen-deploy/`** (e.g. `*.img`, archives). The Docker script can also unpack under **`pi-gen/deploy/`** (see docs).
4. **Logs**: Tail the timestamped **`build-*.log`** if using the wrapper.

## Failure signals

- Non-zero exit from **`make`** / **`agent-build-docker.sh`**.
- Docker container exited with error (**`docker ps -a`**, **`docker logs`**).
- Last lines of the **`build-*.log`** (errors from apt, debootstrap, stage scripts).

## Cleanup / retry

- **`make build-docker-clean`**: removes **`pigen_work`** / **`pigen_work_cont`** containers and deletes **`.aryaos-pigen-work`** and **`.aryaos-pigen-deploy`** (large). Use before a clean rebuild when appropriate.

## CI (optional)

GitHub Actions uses [`.github/workflows/pi-gen.yml`](.github/workflows/pi-gen.yml). Pull requests run Ansible syntax checks on **`ubuntu-latest`**.
Full image builds use the native aarch64 **`ubuntu-24.04-arm`** runner and **`usimd/pi-gen-action@v1`**.
A cleanup step frees disk space before pi-gen. Each successful **`main`** build or manual workflow creates a version tag and release.
The release contains the image, and the workflow stores an Actions artifact. Monitor it with `gh` or the Actions UI.

## Lightweight validation (no full image)

For playbook/config checks without pi-gen: **`make ansible-syntax`** (see [docs/build.md](docs/build.md)).

## Local lab device (portal / quick tests)

Use LINCOT-based discovery: **`./scripts/aryaos-dev-device list`**, then
**`./scripts/sync-to-dev-pi.sh`** or **`./scripts/sync-portal-review.sh`**. Set
**`ARYAOS_DEV_DEVICE=<hostname-or-uid>`** when multiple devices are visible, or
**`ARYAOS_SSH=pi@<address>`** when multicast is unavailable. Prefer the lab SSH
key documented in [`docs/dev-pi.md`](docs/dev-pi.md). Never commit credentials.

After portal sync or a new flash, run **`make test-dev-device`** or
**`./scripts/aryaos-test/run.sh`** - see [docs/testing-dev-pi.md](docs/testing-dev-pi.md).

## HTTPS landing portal

Static UI + **`/cgi-bin/aryaos-portal-status`** JSON (TAK gateways, GNSS, host, RF). Source: [`shared_files/aryaos/html/`](../shared_files/aryaos/html/), [`shared_files/aryaos/cgi-bin/aryaos-portal-status`](../shared_files/aryaos/cgi-bin/aryaos-portal-status).

- **Deploy to lab device:** `./scripts/sync-portal-review.sh`
- **Detail + agent handoff / next steps:** [docs/portal.md](docs/portal.md)
