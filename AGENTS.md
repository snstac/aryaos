# Agent instructions: AryaOS image build

Short procedural notes for automated assistants running or watching pi-gen builds in this repo. Human-oriented detail lives in [docs/build.md](docs/build.md).

## Prerequisites

- **Docker** daemon running (`docker ps` works).
- **Disk**: pi-gen `work/` and deploy output can consume hundreds of gigabytes; leave ample free space.
- **Working directory**: repository root (where `Makefile` and `config.docker` live).
- **Optional**: `NUM_CORES` exported before build to tune parallelism inside the container (defaults to `nproc` via the Makefile).

## Prefer `make build-docker` (agents)

Use this for unattended builds: it avoids interactive host **sudo** used by `make build`.

### Optional apt cache (faster rebuilds)

1. **`make apt-cacher-up`** — starts **`apt-cacher-ng`** ([`docker-compose.apt-cacher.yml`](docker-compose.apt-cacher.yml)); cache persists in Docker volume **`aryaos_apt_cacher_cache`**.
2. **`ARYAOS_APT_CACHE=1 make build-docker`** — passes **`APT_PROXY`** into pi-gen (same mechanism as upstream **`APT_PROXY`** / stage0 `51cache`). **`make apt-cacher-ping`** checks the cache from the host on **`127.0.0.1:${ARYAOS_APT_CACHER_PORT:-3142}`**.

- **Config**: [config.docker](config.docker) — repo bind-mounted read-only at **`/aryaos`**, matching the Makefile’s `PIGEN_DOCKER_OPTS`.
- **Caches / output** (gitignored): **`.aryaos-pigen-work/`** → `/pi-gen/work`, **`.aryaos-pigen-deploy/`** → `/pi-gen/deploy`.
- **Upstream tree**: First build ensures **`./pi-gen`** exists (Makefile `pi-gen` target clones when needed); later builds reuse the directory.

Do **not** default to **`make build`** / **`./build.sh`** unless the user asks: those invoke **`sudo`** and may block on a password.

### Logged build (recommended for monitoring after the fact)

From repo root:

```bash
./scripts/agent-build-docker.sh
```

This runs `make build-docker`, mirrors stdout/stderr to **`build-YYYYMMDD-HHMMSS.log`** at the repo root, and exits with the same status as `make`. Prefer this when you need to re-read output with editor tools after the command finishes.

## Faster iteration

After a full base image exists, **`make skip`** adds `SKIP` markers for pi-gen `stage0`–`stage2`; **`make unskip`** removes them. Use only when the user wants shorter loops while editing AryaOS stages.

## Monitoring checklist

1. **Terminal**: `make build-docker` / `agent-build-docker.sh` runs for a long time; use a terminal session with enough timeout or run in the background and poll.
2. **Docker**: **`docker ps`**; **`docker logs`** on pi-gen containers (e.g. **`pigen_work`**, **`pigen_work_cont`** — see **`make build-docker-clean`**).
3. **Disk progress**: Activity under **`.aryaos-pigen-work/`**; finished artifacts under **`.aryaos-pigen-deploy/`** (e.g. `*.img`, archives). The Docker script may also unpack under **`pi-gen/deploy/`** (see docs).
4. **Logs**: Tail the timestamped **`build-*.log`** if using the wrapper.

## Failure signals

- Non-zero exit from **`make`** / **`agent-build-docker.sh`**.
- Docker container exited with error (**`docker ps -a`**, **`docker logs`**).
- Last lines of the **`build-*.log`** (errors from apt, debootstrap, stage scripts).

## Cleanup / retry

- **`make build-docker-clean`**: removes **`pigen_work`** / **`pigen_work_cont`** containers and deletes **`.aryaos-pigen-work`** and **`.aryaos-pigen-deploy`** (large). Use before a clean rebuild when appropriate.

## CI (optional)

GitHub Actions: [`.github/workflows/pi-gen.yml`](.github/workflows/pi-gen.yml). PRs run Ansible syntax checks on GitHub-hosted runners. **Full image builds run only on self-hosted Linux runners** (`runs-on: [self-hosted, Linux]`): register one under **Repo → Settings → Actions → Runners**. **x86_64 runners** must allow **`sudo modprobe binfmt_misc`** (often NOPASSWD) and **`docker run --privileged`** so the workflow can install **`tonistiigi/binfmt`** arm64 handlers before **`pi-gen-action`**; **aarch64** hosts skip that step. On each successful **`main`** build (or **`workflow_dispatch`**), the workflow pushes an auto-generated **`v<UTC-datetime>-<sha>`** tag and publishes a **Release** with the image plus an Actions artifact. Monitor with **`gh run list`**, **`gh run watch <run-id>`**, or the Actions UI — separate from local Docker builds.

## Lightweight validation (no full image)

For playbook/config checks without pi-gen: **`make ansible-syntax`** (see [docs/build.md](docs/build.md)).
