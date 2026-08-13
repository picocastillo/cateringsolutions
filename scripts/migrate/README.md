# VPS migration — complete Capistrano lift-and-shift

Move **Kiosk** to a new VPS: Ruby/asdf, MariaDB, Redis, nginx (HTTPS), systemd Puma, Delayed Job, Nailgun, Let’s Encrypt.

**Recommended OS:** Ubuntu Server 24.04 LTS (x86_64), 2+ vCPU / 4–8 GB RAM / 40+ GB SSD.

Capistrano deploys the app. These scripts do **not** issue TLS. Until `finalize-server.sh` runs, Rails `force_ssl` redirects HTTP → HTTPS and the browser fails because port 443 is closed. That is expected.

## Do not

- Re-run `bootstrap-vps.sh` after a successful Capistrano deploy (it used to reset `current` to a placeholder).
- Pass `--apply-server-configs` on trackerdev (packed nginx/puma come from old CentOS production).
- Ctrl-C during export dump or restore import (the dump is hundreds of MB; a cut import leaves tables missing).
- Skip `finalize-server.sh` and expect `https://…` to work.
- Point Capistrano `rosa` at the old production IP while deploying to the new VPS.

## One app, one DB, multiple domains

Same Rails app and MariaDB database `kiosk`. Tiendas keep production `dominio` values. Staging hosts are mapped in `config/tienda_host_aliases.yml`.

### Production (`DOMAIN_PROFILE=production`, default)

| Domain | Role |
|---|---|
| `cateringsolutions.com.ar` (+ `www`) | Primary (cert name) |
| `tivoglio.com.ar` (+ `www`) | Tienda |
| `cotidianomarket.ar` (+ `www`) | Tienda |

### Staging trackerdev (`DOMAIN_PROFILE=trackerdev`)

| Domain | Maps to `tiendas.dominio` |
|---|---|
| `cateringsolutions.trackerdev.com.ar` (+ `www`) | `cateringsolutions.com.ar` |
| `tivoglio.trackerdev.com.ar` (+ `www`) | `tivoglio.com.ar` |

Canonical URL after finalize: **https://cateringsolutions.trackerdev.com.ar/** (`www` redirects to apex).

Bootstrap sets `MODO_PRUEBA=true` on `puma-kiosk` so the site shows a **MODO PRUEBA** bar. On a VPS that was already bootstrapped:

```bash
sudo systemctl edit puma-kiosk
# [Service]
# Environment=MODO_PRUEBA=true
sudo systemctl daemon-reload
sudo systemctl restart puma-kiosk
```

## Scripts

| Script | Where | Role |
|---|---|---|
| [`bootstrap-vps.sh`](./bootstrap-vps.sh) | New VPS (root) | Stack + HTTP nginx. Run **once**. |
| [`export-from-source.sh`](./export-from-source.sh) | Current production as `dev` | DB dump + `shared/config` + uploads |
| [`restore-on-vps.sh`](./restore-on-vps.sh) | New VPS | Import tarball (unix_socket; no `--apply-server-configs` on trackerdev) |
| [`finalize-server.sh`](./finalize-server.sh) | New VPS (root) | Let’s Encrypt, HTTPS nginx, start Puma + DJ |

---

## Trackerdev runbook (do this in order)

Replace `NEW_VPS_IP` with the new box (example: `149.50.153.150`). Old production in the previous lift was `dev@66.97.42.153` port `5181`.

### 0. Mac — SSH config

`~/.ssh/config`:

```text
Host rosa
  HostName NEW_VPS_IP
  User dev
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes

Host kiosk-old
  HostName 66.97.42.153
  Port 5181
  User dev
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Your laptop key must be in **both**:

- `root` and later `dev` `authorized_keys` on the new VPS
- `dev` `authorized_keys` on the old server

Check:

```bash
ssh kiosk-old 'whoami && hostname'
# After bootstrap (step 2), `dev` exists:
ssh rosa 'whoami && hostname'
```

Until bootstrap finishes, SSH to the new VPS as root:

```text
Host rosa-root
  HostName NEW_VPS_IP
  User root
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

### 1. Copy migrate scripts onto the new VPS (as root)

From the Mac, in this repo (scripts already include the unix_socket import fix):

```bash
scp -r scripts/migrate rosa-root:/tmp/kiosk-migrate-src
ssh rosa-root
```

### 2. Bootstrap **once** (new VPS, root)

```bash
DOMAIN_PROFILE=trackerdev sudo bash /tmp/kiosk-migrate-src/bootstrap-vps.sh
```

Creates user `dev` (sudo, asdf Ruby 3.4.8, Node, Yarn), copies scripts to `/opt/kiosk-migrate/`, HTTP nginx for the four trackerdev names, empty DB `kiosk`. Puma is enabled but not serving a real release yet.

Confirm:

```bash
sudo -iu dev -- bash -lc 'whoami && ruby -v'
# ruby 3.4.8
```

Your Mac pubkey should already be in `/home/dev/.ssh/authorized_keys` (copied from root). Then `ssh rosa` works.

### 3. GitHub deploy key (new VPS, as `dev`)

Capistrano clones `git@github.com:picocastillo/cateringsolutions.git` **on the VPS**, not from your Mac working copy.

```bash
sudo -iu dev
ssh-keygen -t ed25519 -C "kiosk-deploy@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Add that public key as a **deploy key** (read-only) on GitHub → repo Settings → Deploy keys.

```bash
ssh -T git@github.com
# Hi picocastillo/cateringsolutions! You've successfully authenticated...
```

### 4. Export from old production (as `dev`)

Copy the **updated** `export-from-source.sh` if the old box still has the previous script:

```bash
scp scripts/migrate/export-from-source.sh kiosk-old:/tmp/export-from-source.sh
ssh kiosk-old
bash /tmp/export-from-source.sh
```

Wait until it prints `Export complete` and a path under `/tmp/kiosk-migrate-*.tar.gz`. Do not Ctrl-C. It must report table `tiendas` inside the dump.

```bash
scp kiosk-old:/tmp/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz \
    kiosk-old:/tmp/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz.sha256 \
    rosa-root:/tmp/
```

### 5. Restore on the new VPS (root)

**Without** `--apply-server-configs`:

```bash
sudo bash /opt/kiosk-migrate/restore-on-vps.sh /tmp/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz
```

Wait for `tables in kiosk:` **≥ 70** and lines `tienda dominio: …`. Do not Ctrl-C. The script drops DB `kiosk`, imports via unix_socket, and aligns `root@127.0.0.1` with `database.yml` so Rails can connect.

If you still have the old `/opt/kiosk-migrate/restore-on-vps.sh`, copy the repo version first:

```bash
scp scripts/migrate/restore-on-vps.sh rosa-root:/opt/kiosk-migrate/restore-on-vps.sh
```

### 6. Push + Capistrano deploy (Mac)

The VPS clones **GitHub `master`**, not local uncommitted files. Push first:

```bash
git push origin master
```

`~/.ssh/config` `Host rosa` must be the **new** VPS.

```bash
ssh rosa 'whoami && hostname'
# whoami → dev

docker compose --profile deploy build deploy   # first time / after Gemfile change
docker compose --profile deploy run --rm --entrypoint ssh deploy -T rosa
docker compose --profile deploy run --rm deploy
```

After deploy:

```bash
ssh rosa 'readlink -f /var/www/kiosk/current; test -f /var/www/kiosk/current/config/puma.rb && echo puma.rb_ok'
# must NOT be .../current_placeholder
```

### 7. DNS (before finalize)

A records, all to `NEW_VPS_IP`:

- `cateringsolutions.trackerdev.com.ar`
- `www.cateringsolutions.trackerdev.com.ar`
- `tivoglio.trackerdev.com.ar`
- `www.tivoglio.trackerdev.com.ar`

```bash
dig +short cateringsolutions.trackerdev.com.ar A
```

### 8. Finalize (TLS + Puma) — new VPS, root

```bash
DOMAIN_PROFILE=trackerdev CERTBOT_EMAIL=you@example.com sudo bash /opt/kiosk-migrate/finalize-server.sh
```

This issues the Let’s Encrypt cert, switches nginx to HTTPS (port 443), starts `puma-kiosk`, restarts Delayed Job.

Open **https://cateringsolutions.trackerdev.com.ar/** (not `www`).

### 9. Verify

```bash
sudo systemctl status puma-kiosk nginx mariadb redis-server
curl -I https://cateringsolutions.trackerdev.com.ar/
curl -I https://tivoglio.trackerdev.com.ar/
redis-cli ping
sudo mysql --protocol=socket -e "SHOW TABLES FROM kiosk LIKE 'tiendas';"
sudo -iu dev
cd /var/www/kiosk/current && RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue status
```

---

## If this VPS is already bootstrapped

Do **not** bootstrap again. From step 4 (export) onward. Keep `current` pointing at a real release. Copy the updated restore script to `/opt/kiosk-migrate/` before importing again.

Restore stops Puma while it drops/reloads the DB; start it after (or run finalize / `systemctl start puma-kiosk`).

## Production cutover

Same flow with `DOMAIN_PROFILE=production` (default), six A records, and finalize without the trackerdev env. Optional frozen dump: `export-from-source.sh --maintenance`.

## Local Docker dump

```bash
./scripts/migrate/prepare-local-dump.sh /path/to/kiosk-migrate-*.tar.gz
docker compose --profile app up -d --build
```

See [docs/DOCKER.md](../../docs/DOCKER.md). Capistrano from Docker: [docs/CAPISTRANO_DOCKER.md](../../docs/CAPISTRANO_DOCKER.md).

## Related

- [docs/DEPLOY.md](../../docs/DEPLOY.md)
- Capistrano: `config/deploy.rb` (`set :domain, 'rosa'`, repo `picocastillo/cateringsolutions`, branch `master`)
