# Local development Pi (lab)

Use a dedicated Raspberry Pi on your LAN to try changes from this repository before full image builds or CI.

## Default lab target (team convention)

- **SSH:** `pi@172.17.2.158`
- **Authentication:** Prefer **SSH public keys** (`ssh-copy-id pi@172.17.2.158`). Do **not** commit passwords, private keys, or credential files to the repo.

## Push portal / CGI / lighttpd snippet from the repo

From the repository root:

```bash
ARYAOS_SSH=pi@172.17.2.158 ./scripts/sync-portal-review.sh
```

The script rsyncs `shared_files/aryaos/html/`, installs the portal status CGI, updates `95-aryaos-cockpit-https.conf`, and related pieces (see [scripts/sync-portal-review.sh](../scripts/sync-portal-review.sh)).

## Other one-off files

Use `scp` / `rsync` for scripts or configs not covered by `sync-portal-review.sh`, then run them on the Pi with `sudo` as needed. Example: [scripts/readsb-use-rtl-serial.sh](../scripts/readsb-use-rtl-serial.sh) for readsb RTL serial changes.

## Optional SSH config (workstation only)

In `~/.ssh/config` (local machine, not tracked in git):

```sshconfig
Host aryaos-dev-pi
  HostName 172.17.2.158
  User pi
```

Then: `ARYAOS_SSH=pi@aryaos-dev-pi ./scripts/sync-portal-review.sh`.

## Full stack parity

For state that is normally applied by Ansible or pi-gen stages, run the appropriate playbook or rebuild the image when you need an exact match to production images.
