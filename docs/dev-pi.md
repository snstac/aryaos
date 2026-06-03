# Local development Pi (lab)

Use a dedicated Raspberry Pi on your LAN to try changes from this repository before full image builds or CI.

## Default lab target (team convention)

- **SSH:** `pi@aryaos-dev-pi` (via `~/.ssh/config`, see **`./scripts/setup-dev-ssh.sh`**) — resolves to **`172.17.2.158`**.
- **Password (fallback):** keep out of git. Use **gitignored** `scripts/.dev-pi-creds.local` or export `ARYAOS_DEV_PI_PASSWORD` when you cannot use the dev key below.

**New images:** user **`pi`** has **passwordless sudo** (see `shared_files/aryaos/aryaos.sudoers`) so agents and scripts can run remote fixes over SSH without an interactive password. This matches the lab SSH key profile — anyone with **`aryaos-dev-lab`** can become root.

**Existing Pi (already flashed):** apply once on the device (needs current `pi` password):

```bash
echo 'pi ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/aryaos-pi-nopasswd
sudo chmod 440 /etc/sudoers.d/aryaos-pi-nopasswd
sudo visudo -c
```

## Lab SSH key (passwordless, preferred)

The repo ships **`shared_files/aryaos/ssh/aryaos-dev-lab.pub`**; new AryaOS images append it to **`pi`**’s **`authorized_keys`**. The matching **private** key is **gitignored** at **`shared_files/aryaos/ssh/aryaos-dev-lab`** (generate once in the repo with `ssh-keygen`; see [shared_files/aryaos/ssh/README.md](../shared_files/aryaos/ssh/README.md)).

**One-time on your workstation** (from repo root, after the private key exists):

```bash
chmod 600 shared_files/aryaos/ssh/aryaos-dev-lab
./scripts/setup-dev-ssh.sh
```

That adds **`Host aryaos-dev-pi`** to `~/.ssh/config` pointing at **`172.17.2.158`** with **`IdentityFile`**.

**Existing Pi (already flashed before this key existed):** install the public key once (from the repo, with your lab `pi` password):

```bash
ssh-copy-id -i shared_files/aryaos/ssh/aryaos-dev-lab.pub pi@aryaos-dev-pi
```

(`~/.ssh/config` must already contain **`Host aryaos-dev-pi`** with **`HostName 172.17.2.158`** — run **`./scripts/setup-dev-ssh.sh`** first, or add that block by hand.)

(or append the `.pub` line manually to `/home/pi/.ssh/authorized_keys` on the Pi).

**Override key path (force `ssh -i` for sync scripts):** set **`ARYAOS_DEV_PI_SSH_KEY`** to a private key file. [scripts/sync-to-dev-pi.sh](../scripts/sync-to-dev-pi.sh) tries normal **`ssh` first** (so **`~/.ssh/config`** + **ssh-agent** match your interactive `ssh pi@aryaos-dev-pi`), then the repo **`aryaos-dev-lab`** file, then password. [scripts/sync-portal-review.sh](../scripts/sync-portal-review.sh) uses **`ARYAOS_DEV_PI_SSH_KEY`** only when set; otherwise plain **`ssh`/`scp`** (rely on config/agent).

## USB power (multiple SDRs)

If the Pi browns out USB devices under several dongles, run **`./scripts/enable-pi-usb-current.sh`** on the Pi from a synced repo (or after `scp` of that script plus `shared_files/aryaos/boot/firmware/aryaos-usb-power.fragment`). It appends **`max_usb_current=1`** (Pi 3–class) and **`usb_max_current_enable=1`** (Pi 5) to **`/boot/firmware/config.txt`**, then **reboot**. New AryaOS images apply the same fragment during **stage-aryaos** pi-gen.

## Mirror the whole repo tree to the Pi

From the repository root:

```bash
./scripts/sync-to-dev-pi.sh
```

Uses the dev private key when **`shared_files/aryaos/ssh/aryaos-dev-lab`** is readable; otherwise falls back to **`ARYAOS_DEV_PI_PASSWORD`** / **`scripts/.dev-pi-creds.local`**, then to your SSH agent.

This mirrors the working tree to **`~/aryaos-sync/`** on the Pi (default **`pi@aryaos-dev-pi`**; set **`ARYAOS_DEV_PI_HOST=172.17.2.158`** if you have no `Host aryaos-dev-pi` entry).

**Password-only auth:** install `sshpass`, then either:

```bash
cp scripts/dev-pi-creds.local.example scripts/.dev-pi-creds.local
# edit scripts/.dev-pi-creds.local — it is gitignored
./scripts/sync-to-dev-pi.sh
```

or one-shot:

```bash
ARYAOS_DEV_PI_PASSWORD='your_password' ./scripts/sync-to-dev-pi.sh
```

## Push portal / CGI / lighttpd to live paths on the Pi

After a tree sync (or from the repo), install portal pieces into `/var/www/html` and friends:

```bash
ARYAOS_SSH=aryaos-dev-pi ./scripts/sync-portal-review.sh
```

(`Host aryaos-dev-pi` in `~/.ssh/config` with `User pi` is enough; `pi@aryaos-dev-pi` also works.)

See [scripts/sync-portal-review.sh](../scripts/sync-portal-review.sh) and [portal.md](portal.md) (features, JSON schema, agent next steps).

## Integration tests

After flash or sync, run the reusable test suite against the lab Pi:

```bash
make test-dev-pi
# or
./scripts/aryaos-test/run.sh
```

See [testing-dev-pi.md](testing-dev-pi.md) for tiers, check matrix, and interpreting results.

## Apply Charontak / CoT / dhbridge config on a running Pi

`sync-to-dev-pi.sh` mirrors the repo to **`~/aryaos-sync/`** only. To install **`/etc`** defaults and bump pinned **charontak** / **lincot** `.debs` without reflashing:

```bash
ansible-playbook -i inventory.yml site.yml --limit aryaos-dev-pi \
  --tags charontak,lincot,dhbridge
```

(`inventory.yml` uses **`shared_files/aryaos/ssh/aryaos-dev-lab`** when present.) If **`get_url`** fails on the Pi (old Python/urllib), copy config manually:

```bash
ssh pi@aryaos-dev-pi 'sudo install -m 0644 ~/aryaos-sync/shared_files/aryaos/aryaos-config.txt /etc/aryaos/aryaos-config.txt
sudo install -m 0644 ~/aryaos-sync/shared_files/charontak/charontak.ini /etc/charontak.ini
sudo install -m 0644 ~/aryaos-sync/shared_files/dhbridge/dhbridge.ini /etc/dhbridge.ini
sudo systemctl restart charontak dhbridge lincot adsbcot'
```

Default feeder **`COT_URL`** is **`udp+wo://127.0.0.1:28087`**; Charontak listens on **`udp+ro://127.0.0.1:28087`**.

## Other one-off files

Use `scp` / `rsync` for scripts or configs not covered by the scripts above. Example: [scripts/readsb-use-rtl-serial.sh](../scripts/readsb-use-rtl-serial.sh) for readsb RTL serial changes.

## Optional SSH config (manual)

If you prefer not to use **`setup-dev-ssh.sh`**, add to **`~/.ssh/config`**:

```sshconfig
Host aryaos-dev-pi
  HostName 172.17.2.158
  User pi
  IdentityFile /path/to/aryaos-dev-lab
  IdentitiesOnly yes
```

## Full stack parity

For state that is normally applied by Ansible or pi-gen stages, run the appropriate playbook or rebuild the image when you need an exact match to production images.
