# VPS migration — complete Capistrano lift-and-shift

Move **Kiosk** to a new VPS with the full production stack: Ruby/asdf, MariaDB, Redis, nginx (HTTPS + all domains), systemd Puma, Delayed Job, Nailgun, Let’s Encrypt.

## Recommended OS

**Ubuntu Server 24.04 LTS** (x86_64), 2+ vCPU / 4–8 GB RAM / 40+ GB SSD.

## One app, one DB, multiple domains

Same Rails app and MariaDB database `kiosk`. Tiendas are rows with a `dominio`; nginx serves the hostnames for the chosen profile.

### Production (`DOMAIN_PROFILE=production`, default)

| Domain | Role |
|---|---|
| `cateringsolutions.com.ar` (+ `www`) | Primary (cert name + mailer host) |
| `tivoglio.com.ar` (+ `www`) | Tienda |
| `cotidianomarket.ar` (+ `www`) | Tienda |

### Staging trackerdev (`DOMAIN_PROFILE=trackerdev`)

Replica of Catering Solutions + Ti Voglio on the new VPS (no Cotidiano):

| Domain | Maps to `tiendas.dominio` |
|---|---|
| `cateringsolutions.trackerdev.com.ar` (+ `www`) | `cateringsolutions.com.ar` |
| `tivoglio.trackerdev.com.ar` (+ `www`) | `tivoglio.com.ar` |

Host → tienda mapping is in `config/tienda_host_aliases.yml` (`Tiendas::HostResolver`). Keep production `dominio` values in the DB so logos/assets keep working.

```bash
DOMAIN_PROFILE=trackerdev sudo bash scripts/migrate/bootstrap-vps.sh
# … export / restore / deploy …
DOMAIN_PROFILE=trackerdev sudo bash /opt/kiosk-migrate/finalize-server.sh
```

DNS: point the four trackerdev names at the VPS before finalize.

## Scripts

| Script | Where | Role |
|---|---|---|
| [`bootstrap-vps.sh`](./bootstrap-vps.sh) | New VPS (root) | Full stack install + HTTP nginx for all domains |
| [`export-from-source.sh`](./export-from-source.sh) | Current production | Dump DB + shared secrets + nginx/systemd snapshot |
| [`restore-on-vps.sh`](./restore-on-vps.sh) | New VPS | Import tarball (optional `--apply-server-configs`) |
| [`finalize-server.sh`](./finalize-server.sh) | New VPS (root) | Certbot for all domains, HTTPS nginx, start Puma + DJ, smoke checks |

Templates: [`templates/`](./templates/) (HTTP + HTTPS nginx for production and `*.trackerdev`, domains lists, puma unit, sudoers).

## End-to-end runbook

### 1. New VPS — bootstrap

```bash
# Ubuntu 24.04, SSH as root; copy scripts/migrate or clone repo
sudo bash scripts/migrate/bootstrap-vps.sh
# scripts also copied to /opt/kiosk-migrate/
```

### 2. Old server — export

```bash
sudo -iu dev
bash /path/to/scripts/migrate/export-from-source.sh
# final cutover later: ... --maintenance
```

```bash
scp /tmp/kiosk-migrate-*.tar.gz /tmp/kiosk-migrate-*.tar.gz.sha256 root@NEW_IP:/tmp/
```

### 3. New VPS — restore

```bash
sudo bash /opt/kiosk-migrate/restore-on-vps.sh /tmp/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz --apply-server-configs
```

### 4. Deploy key + Capistrano

As `dev` on the new VPS: create SSH key, add GitHub deploy key, `ssh -T git@github.com`.

On your laptop, point SSH host `rosa` at the new IP:

```bash
bundle exec cap production deploy
```

### 5. DNS

Point **A** records for all six names (apex + www × 3) to the new VPS **before** finalize.

### 6. Finalize (TLS + services)

```bash
CERTBOT_EMAIL=you@example.com sudo bash /opt/kiosk-migrate/finalize-server.sh
```

This issues one Let’s Encrypt cert (primary name `cateringsolutions.com.ar` with SANs), installs the production HTTPS nginx site (matching `/cable`, gzip, www→apex, HTTP→HTTPS), starts `puma-kiosk`, restarts Delayed Job pools, and smoke-checks HTTPS on the three apex domains.

### 7. Final data cutover (optional second pass)

On old server: `export-from-source.sh --maintenance` → scp → `restore-on-vps.sh` → `systemctl restart puma-kiosk` → flip any remaining DNS TTL.

### 8. Cleanup

Delete migration tarballs; never commit dumps or `shared/config` secrets.

## Verify

```bash
sudo systemctl status puma-kiosk nginx mariadb redis-server
curl -I https://cateringsolutions.com.ar/
curl -I https://tivoglio.com.ar/
curl -I https://cotidianomarket.ar/
redis-cli ping
sudo -iu dev
cd /var/www/kiosk/current && RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue status
```

## Local Docker (Mac) — import the dump

To run the app on your Mac with Docker and load a production/migration dump:

```bash
# From a migration tarball OR a .sql / .sql.gz:
./scripts/migrate/prepare-local-dump.sh /path/to/kiosk-migrate-*.tar.gz
# → docker/db/01-kiosk_development.sql.gz

docker compose --profile app up -d --build
# http://localhost:3000
```

Details: [docs/DOCKER.md](../../docs/DOCKER.md).

## Related

- [docs/DEPLOY.md](../../docs/DEPLOY.md)
- Capistrano: `config/deploy.rb`
