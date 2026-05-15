# Lab development SSH key (`aryaos-dev-lab`)

- **`aryaos-dev-lab.pub`** — committed; installed into **`pi`**’s **`authorized_keys`** on new AryaOS images (see `stages/stage-aryaos/00-install/00-run.sh`).
- **`aryaos-dev-lab`** — **private** key; **gitignored**. Generate with:

  ```bash
  ssh-keygen -t ed25519 -f shared_files/aryaos/ssh/aryaos-dev-lab -N "" -C "aryaos-lab-dev"
  ```

  Keep the private key only on trusted workstations (or a team secrets store). Anyone with the private key can log in as **`pi`** on any host that trusts this public key.

## Local use

From the repo root:

```bash
./scripts/setup-dev-ssh.sh
```

Then **`ssh aryaos-dev-pi`** (see [docs/dev-pi.md](../../../docs/dev-pi.md)).

## Rotation

1. Generate a new pair (command above), replace **`aryaos-dev-lab.pub`** in git, rebuild/flash or **`ssh-copy-id`** to existing Pis.
2. Remove the old public line from **`~/.ssh/authorized_keys`** on old systems.
