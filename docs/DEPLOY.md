# Deploy (production)

How **Kiosk** is deployed and operated on the VPS.

## Server overview

| Item | Value |
|---|---|
| Host | `vps-1692609-x.dattaweb.com` (Capistrano role `rosa`) |
| App path | `/var/www/kiosk` |
| Deploy user | `dev` |
| Ruby | **3.4.8** via asdf (`/home/dev/.asdf/installs/ruby/3.4.8`) |
| Process manager | systemd unit **`puma-kiosk`** |
| Web | nginx → Puma Unix socket |
| DB | MariaDB (`kiosk`), local `127.0.0.1` |
| Cache | Redis `127.0.0.1:6379` (DB `0` in production) |
| Jobs | Delayed Job pools: `fast`, `slow`, `confirmacion` |
| PDF | Nailgun JVM on `localhost:2113` (Java 8) |
| Capistrano branch | `rosa` |
| Repo | `git@github.com:tanqueta/kiosk.git` |

Layout (Capistrano):

```text
/var/www/kiosk/
  current -> releases/<timestamp>
  releases/
  shared/
    config/database.yml
    config/master.key
    config/qz_tray/private-key.pem
    bundle/          # gems (deployment path)
    node_modules/    # yarn production install
    tmp/sockets/puma.sock
    tmp/pids/puma.pid
    log/
```

> Important: diagnose and operate as user **`dev`**, not `root`. Root sees the system Ruby (2.x) and is not the app runtime.

```bash
sudo -iu dev
# or: su - dev
ruby -v   # should be 3.4.8 via asdf
```

## Prerequisites on the server

Already expected on the box:

- asdf + Ruby 3.4.8 for `dev`
- Node + Yarn (for Capistrano `yarn:install`)
- MariaDB, Redis, nginx
- OpenJDK 8 (Nailgun / Flying Saucer)
- systemd unit `puma-kiosk`
- SSH deploy key for `git@github.com:tanqueta/kiosk.git`
- Shared secrets under `/var/www/kiosk/shared/config/`

### Shared `database.yml`

Lives only on the server (linked into each release):

```yaml
production:
  adapter: mysql2
  encoding: utf8mb4
  collation: utf8mb4_unicode_ci
  username: root
  host: 127.0.0.1
  pool: 15
  reconnect: true
  database: kiosk
  password: <server-secret>
```

Capistrano runs:

```text
ln -f shared/config/database.yml → release/config/database.yml
ln -f shared/config/qz_tray/private-key.pem → release/config/qz_tray/
```

## Deploy from your machine

Requires Capistrano configured locally (see `Capfile`, `config/deploy.rb`) and SSH access as `dev` to the host aliased as `rosa`.

```bash
# From a clean branch matching config/deploy.rb (currently master)
git checkout master
git pull
git push origin master

bundle exec cap production deploy
```

To run Capistrano **from Docker** (no Ruby on the Mac): [CAPISTRANO_DOCKER.md](./CAPISTRANO_DOCKER.md).

What the deploy does (high level):

1. Checkout code into a new `releases/<timestamp>`
2. `bundle install` into `shared/bundle` (deployment mode)
3. Link `database.yml` + QZ Tray private key
4. `yarn install --frozen-lockfile --production` in `shared`, symlink `node_modules`
5. `assets:precompile`
6. Migrations (`db:migrate`) as part of the Capistrano flow
7. Kill Nailgun so Puma respawns it with the new classpath
8. `sudo systemctl restart puma-kiosk`
9. Restart Delayed Job daemons (`fast` / `slow` / `confirmacion`)
10. Clear Rails cache
11. Cleanup old releases

### Delayed Job pools (from `config/deploy.rb`)

| Queue | Pool |
|---|---|
| `fast` | 3 |
| `slow` | 2 |
| `confirmacion` | 2 |

PIDs under `/tmp/fast_queue`, `/tmp/slow_queue`, `/tmp/confirmacion_queue`.

## systemd (Puma)

Unit: **`puma-kiosk`**

Relevant environment (matches current server unit):

```text
User=dev
WorkingDirectory=/var/www/kiosk/current
RAILS_ENV=production
PATH=.../home/dev/.asdf/installs/ruby/3.4.8/bin:...
WEB_CONCURRENCY=5
RAILS_MAX_THREADS=5
MALLOC_ARENA_MAX=2
ExecStart=bundle exec puma -C config/puma.rb
```

### Test-mode banner (`MODO_PRUEBA`)

Set `MODO_PRUEBA=true` on Puma to show a site-wide **MODO PRUEBA** bar (login + logged-in pages). Trackerdev bootstrap enables it automatically. On an existing unit:

```bash
sudo systemctl edit puma-kiosk
```

```ini
[Service]
Environment=MODO_PRUEBA=true
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart puma-kiosk
```

Remove the drop-in (or set `MODO_PRUEBA=false`) and restart to hide it. Delayed Job does not need this variable.

Puma binds to:

```text
unix:///var/www/kiosk/shared/tmp/sockets/puma.sock
```

### Service commands

```bash
sudo systemctl status puma-kiosk
sudo systemctl restart puma-kiosk
sudo systemctl stop puma-kiosk
sudo journalctl -u puma-kiosk -f
```

## Manual operations on the server

Always as `dev`, with asdf on `PATH`:

```bash
sudo -iu dev
cd /var/www/kiosk/current
```

### Rails console / runner

```bash
RAILS_ENV=production bundle exec rails c
RAILS_ENV=production bundle exec rails runner 'puts Rails.version'
```

### Delayed Job without a full deploy

```bash
# Capistrano (from laptop)
bundle exec cap production daemons:restart
bundle exec cap production daemons:status

# Or on the server (same commands as deploy.rb)
cd /var/www/kiosk/current
RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue restart
# ... repeat for slow / confirmacion
```

### Nailgun

Started by Puma on boot. Deploy kills it before restart so the new release classpath is used.

```bash
# Force kill if PDF generation is stuck
pkill -f '[c]om.martiansoftware.nailgun.NGServer' || true
sudo systemctl restart puma-kiosk
```

### Redis / MariaDB checks

```bash
redis-cli ping
redis-cli INFO keyspace
mysql -u root -p -h 127.0.0.1 -e "SHOW DATABASES LIKE 'kiosk';"
```

### Logs

```bash
tail -f /var/www/kiosk/shared/log/production.log
tail -f /var/www/kiosk/shared/log/puma.stdout.log
tail -f /var/www/kiosk/shared/log/puma.stderr.log
sudo journalctl -u puma-kiosk -n 100 --no-pager
```

## Rollback

Capistrano keeps previous releases under `/var/www/kiosk/releases/`.

```bash
# From laptop (preferred if you have the Capistrano rollback task wired)
bundle exec cap production deploy:rollback

# Emergency on server: point current at a previous release, then restart
# (only if you know what you are doing)
ls /var/www/kiosk/releases
# ln -sfn /var/www/kiosk/releases/<previous> /var/www/kiosk/current
# sudo systemctl restart puma-kiosk
# then restart delayed_job pools
```

If the rollback includes schema changes, you must reverse migrations carefully — prefer fixing forward when possible.

## Migrating to a new VPS

For a **complete** Capistrano lift-and-shift (DB + shared secrets + nginx for all production domains + TLS + Puma), use [scripts/migrate/README.md](../scripts/migrate/README.md).

Production hostnames served by one app / one DB `kiosk`:

- `cateringsolutions.com.ar` (+ `www`)
- `tivoglio.com.ar` (+ `www`)
- `cotidianomarket.ar` (+ `www`)

Recommended OS: **Ubuntu Server 24.04 LTS** (x86_64).

## First-time / infra checklist

Use when provisioning a new box or verifying after an OS rebuild:

- [ ] User `dev` with asdf Ruby 3.4.8
- [ ] `/var/www/kiosk/{releases,shared}` owned by `dev`
- [ ] `shared/config/database.yml`, `master.key`, `qz_tray/private-key.pem`
- [ ] MariaDB database `kiosk` + grants
- [ ] Redis listening on `127.0.0.1:6379`
- [ ] nginx upstream to `unix:/var/www/kiosk/shared/tmp/sockets/puma.sock`
- [ ] `puma-kiosk.service` installed and enabled
- [ ] `dev` can `sudo systemctl restart puma-kiosk` (passwordless or deploy-safe)
- [ ] Java 8 available for Nailgun
- [ ] SSH deploy key to GitHub repo
- [ ] Capistrano host alias `rosa` points at this VPS

## Troubleshooting

| Symptom | What to check |
|---|---|
| Deploy fails on bundle | asdf Ruby on `dev`, `shared/bundle`, network to rubygems |
| 502 from nginx | `puma.sock` exists; `systemctl status puma-kiosk` |
| Wrong Ruby during SSH as root | Switch to `dev`; root’s `/usr/bin/ruby` is not used by the app |
| Jobs not running | `ps aux \| grep delayed_job`; Capistrano `daemons:status` |
| PDF broken after deploy | Nailgun process; restart Puma so it respawns Nailgun |
| Cache stale | `RAILS_ENV=production bundle exec rails runner 'Rails.cache.clear'` |

## Related

- Capistrano config: `config/deploy.rb`, `Capfile`
- Puma: `config/puma.rb`
- Local development: [LOCAL_SETUP.md](./LOCAL_SETUP.md)
- VPS migration scripts: [scripts/migrate/README.md](../scripts/migrate/README.md)
