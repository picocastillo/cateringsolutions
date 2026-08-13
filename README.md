# Kiosk

Multi-tenant billing, inventory, and order management for catering / restaurants (Rails 7.1).

## Documentation

| Guide | Description |
|---|---|
| [docs/DOCKER.md](docs/DOCKER.md) | Docker local (app + MariaDB/Redis; dónde poner el dump de la DB) |
| [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md) | Run the app on your machine (Docker MariaDB/Redis, Ruby 3.4.8) |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Production deploy & ops on the VPS (Capistrano, Puma, Delayed Job) |
| [PARALLEL_TESTING.md](PARALLEL_TESTING.md) | Parallel RSpec / Selenium grid |
| [docs/QUALITY_TOOLS.md](docs/QUALITY_TOOLS.md) | RuboCop, coverage, quality rake tasks |
| [docs/RSPEC_QUICK_REFERENCE.md](docs/RSPEC_QUICK_REFERENCE.md) | Spec helpers and patterns |

## Quick start (local)

**Todo en Docker** (dump en `docker/db/` — ver [docs/DOCKER.md](docs/DOCKER.md)):

```bash
# Poné el dump en: docker/db/01-kiosk_development.sql
docker compose --profile app up -d --build
# http://localhost:3000
```

**Híbrido** (Ruby en el host, DB/Redis en Docker — [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md)):

```bash
docker compose up -d mariadb redis
bundle install && yarn install
bundle exec rails db:create db:schema:load
bundle exec rails s
```

## Deploy new versions (Capistrano from your Mac)

Deploys ship the **`rosa`** branch to production via Capistrano SSH host **`rosa`** (user `dev`). Details: [docs/DEPLOY.md](docs/DEPLOY.md).

### One-time local setup

1. SSH config so `rosa` resolves to the VPS (example `~/.ssh/config`):

```text
Host rosa
  HostName vps-1692609-x.dattaweb.com
  User dev
  IdentityFile ~/.ssh/id_ed25519
```

2. Confirm access and gems:

```bash
ssh rosa 'ruby -v'   # 3.4.8 via asdf on the server
bundle install       # Capistrano lives in the Gemfile
```

### Ship a release

```bash
# 1. Commit and push the code you want live (must be on branch rosa)
git checkout rosa
git pull
# ... your commits ...
git push origin rosa

# 2. Deploy from this machine
bundle exec cap production deploy
```

Capistrano will: checkout `rosa` on the server → `bundle` + `yarn` → assets → migrations → restart `puma-kiosk` → restart Delayed Job pools → cleanup old releases.

### Useful Capistrano commands

```bash
bundle exec cap production deploy              # full deploy
bundle exec cap production deploy:rollback     # previous release
bundle exec cap production daemons:restart     # Delayed Job only
bundle exec cap production daemons:status
```

## Stack

- **Ruby** 3.4.8 · **Rails** 7.1 · **MariaDB** 10.11 · **Redis** · **Puma** · **Delayed Job**
- AFIP-compliant invoicing, Paperclip uploads, Flying Saucer PDFs (Nailgun)

## Common commands

```bash
bundle exec rails s
bundle exec rails c
bundle exec rails db:migrate
bundle exec rails db:schema:dump
bundle exec rspec
./bin/ptest unit
bundle exec rubocop
```
