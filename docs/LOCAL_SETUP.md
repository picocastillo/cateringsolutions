# Local setup

Guide to run **Kiosk** on your machine for development.

## Stack

| Component | Version / notes |
|---|---|
| Ruby | **3.4.8** (see `.tool-versions` / `Gemfile`) |
| Node | **16.20.2** (Yarn for JS deps) |
| Rails | 7.1 |
| DB | MariaDB **10.11** (`mysql2`) |
| Cache | Redis (DB `1` in development) |
| Jobs | Delayed Job |
| PDF | Java 8 + Nailgun (Flying Saucer) — optional for most UI work |

## Prerequisites

- Docker Desktop (MariaDB + Redis)
- [asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/) for Ruby/Node
- Yarn (`npm install -g yarn`)
- Optional: OpenJDK 8 if you need PDF generation

## 1. Clone and select runtimes

```bash
git clone git@github.com:tanqueta/kiosk.git
cd kiosk

# with asdf
asdf install

# or with mise
mise install
```

Confirm:

```bash
ruby -v    # ruby 3.4.8
node -v    # v16.20.2 (or compatible)
yarn -v
```

## 2. Fix local dirs

The repo may ship `log` as a symlink to the production path `/var/www/kiosk/shared/log`. Replace it locally:

```bash
rm -f log
mkdir -p log tmp
touch log/.keep tmp/.keep
```

## 3. Start MariaDB and Redis

```bash
docker compose up -d mariadb redis
```

Defaults from `docker-compose.yml`:

- MariaDB: `127.0.0.1:3306`, user `root`, password `mysqlroot`
- Redis: `127.0.0.1:6379`

Health check:

```bash
mysql -u root -pmysqlroot -h 127.0.0.1 -e "SELECT 1"
redis-cli ping   # PONG
```

## 4. Configure `config/database.yml`

The committed `config/database.yml` already includes `development` / `test` with defaults for Docker MariaDB (`root` / `mysqlroot` @ `127.0.0.1`). Override with env vars if needed: `DB_HOST`, `DB_PASSWORD`, `DB_NAME`, etc.

Production credentials stay on the server (`shared/config/database.yml`); do not commit real production secrets.

To import a real dump via Docker init scripts, see [DOCKER.md](DOCKER.md) (`docker/db/`).

## 5. Install dependencies

```bash
gem install bundler
bundle install
yarn install
```

Optional env file (mainly for Dockerized Selenium tests):

```bash
cp .env.example .env
# For host-run Rails against Docker Redis, prefer:
# REDIS_HOST=localhost
```

## 6. Create and load the database

```bash
bundle exec rails db:create
bundle exec rails db:schema:load
# or: bundle exec rails db:migrate
```

`db/seeds.rb` is empty. For real data, put a dump in `docker/db/01-kiosk_development.sql` (see [DOCKER.md](DOCKER.md)) or import manually — never commit dumps.

## 7. Run the app

```bash
bundle exec rails s
# http://localhost:3000
```

Console:

```bash
bundle exec rails c
```

### Background jobs (optional)

Development uses Delayed Job. If you need async work:

```bash
bundle exec bin/delayed_job start
# stop:
bundle exec bin/delayed_job stop
```

Or run a single worker in the foreground while debugging.

### Redis

Rails uses Redis as cache store. Without Redis, the app may log cache errors; keep the container up during development.

## 8. Tests

Unit / system suites use parallel workers and Docker (see `PARALLEL_TESTING.md` and `.github/skills/parallel-testing.md`).

```bash
# Quick single file
bundle exec rspec spec/path/to/file_spec.rb

# Parallel suite (requires docker-compose.parallel.yml services)
./bin/ptest unit
./bin/ptest system
./bin/ptest all
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Wrong Ruby (e.g. 2.6 system) | Install asdf/mise and `asdf install` / `mise install` in the project root |
| `log` permission / missing path | Recreate local `log/` (step 2) |
| Can't connect to MySQL | `docker compose ps` — ensure `mariadb` is Up; password `mysqlroot` |
| Assets / JS missing | `yarn install` then restart `rails s` |
| PDF / Nailgun errors | Install Java 8; only needed for comprobante PDFs |
| Stale test assets | `RAILS_ENV=test bundle exec rails assets:clobber` |

## Useful commands

```bash
bundle exec rails db:migrate
bundle exec rails db:schema:dump
bundle exec rubocop
bundle exec rspec
```
