# Docker (local)

Levantar **Kiosk** en local con Docker: MariaDB, Redis y (opcional) la app Rails.

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (o Docker Engine + Compose v2)
- Un dump SQL de la DB (recomendado) **o** schema vacío vía `db:prepare`

## Dónde poner el dump / la migración

**Carpeta de import:** `docker/db/`

```text
docker/db/00-create-databases.sql          # ya viene en el repo
docker/db/01-kiosk_development.sql.gz      # ← tu dump (lo agregás vos)
```

| Archivo | Rol |
|---|---|
| `docker/db/00-create-databases.sql` | Ya viene en el repo: crea `kiosk_development` y `kiosk_test` |
| `docker/db/01-*.sql` / `01-*.sql.gz` | **Tu dump** (no se commitea; está en `.gitignore`) |

MariaDB monta `./docker/db` en `/docker-entrypoint-initdb.d` y ejecuta esos scripts **solo la primera vez** que arranca con el volumen vacío (`mariadb_data`).

### Desde un SQL suelto

```bash
cp /ruta/a/tu-dump.sql docker/db/01-kiosk_development.sql
# o .sql.gz
```

### Desde el tarball de migración (`export-from-source.sh`)

El export de producción deja `payload/kiosk.sql.gz` dentro del `.tar.gz`. Usá el helper:

```bash
./scripts/migrate/prepare-local-dump.sh /ruta/a/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz
# escribe: docker/db/01-kiosk_development.sql.gz
# (reescribe USE `kiosk` → USE `kiosk_development`)
```

También acepta un `.sql` / `.sql.gz` directo.

Consejos:

- Prefijo `01-` para que corra **después** de `00-create-databases.sql`
- No subas dumps reales al git

### Si MariaDB ya estaba corriendo (volumen no vacío)

El init **no** se vuelve a ejecutar. Importá a mano:

```bash
# SQL
docker compose exec -T mariadb mysql -uroot -pmysqlroot kiosk_development < docker/db/01-kiosk_development.sql

# gzip
gunzip -c docker/db/01-kiosk_development.sql.gz \
  | docker compose exec -T mariadb mysql -uroot -pmysqlroot kiosk_development
```

Para forzar un init limpio (borra datos locales de MariaDB):

```bash
docker compose down
docker volume rm cateringsolutions_mariadb_data   # el nombre puede variar: docker volume ls | grep mariadb
# poné el dump en docker/db/ y volvé a levantar
docker compose up -d mariadb redis
```

## Solo infraestructura (Ruby en el host)

Igual que antes: DB + Redis (y Selenium para tests):

```bash
docker compose up -d mariadb redis
# opcional: docker compose up -d selenium
```

Credenciales por defecto:

| Servicio | Host (desde tu máquina) | Credenciales |
|---|---|---|
| MariaDB | `127.0.0.1:3306` | user `root` / pass `mysqlroot` |
| Redis | `127.0.0.1:6379` | sin password |
| App | `http://localhost:3000` | — |

`config/database.yml` ya usa esas variables (`DB_HOST`, `DB_PASSWORD`, etc.) con defaults locales.

## App completa en Docker

1. Poné el dump en `docker/db/` (ver arriba).
2. Arrancá con el profile `app`:

```bash
docker compose --profile app up -d --build
```

Eso levanta `mariadb`, `redis`, `web` (Rails en `:3000`) y `worker` (Delayed Job).

Sin dump y con schema vacío:

```bash
AUTO_PREPARE_DB=true docker compose --profile app up -d --build
```

Logs y consola:

```bash
docker compose logs -f web
docker compose --profile app exec web bundle exec rails c
docker compose --profile app exec web bundle exec rails db:migrate
```

Parar:

```bash
docker compose --profile app down
# conservar datos de DB: no borres el volume
```

## Estructura relevante

```text
Dockerfile                 # imagen Ruby 3.4.8 + Node 16 + Yarn
docker-compose.yml         # mariadb, redis, web, worker, deploy, selenium
docker/entrypoint.sh       # espera DB, arregla log/, bundle/yarn
docker/db/                 # ← ACÁ VA EL DUMP
  00-create-databases.sql
  01-kiosk_development.sql # lo agregás vos
  README.md
```

## Comandos útiles

```bash
# Rebuild de la app
docker compose --profile app build --no-cache web

# Shell en el contenedor
docker compose --profile app exec web bash

# Solo worker / web
docker compose --profile app up -d web
docker compose --profile app up -d worker
```

## Troubleshooting

| Problema | Qué hacer |
|---|---|
| Dump no se importó | El init solo corre con volumen vacío; importá a mano o borrá `mariadb_data` |
| `Access denied` / no conecta | `docker compose ps` y esperá el healthcheck de MariaDB |
| Puerto 3306 / 3000 ocupado | Pará el proceso local o cambiá el mapeo en `docker-compose.yml` |
| `log` apunta a `/var/www/...` | El entrypoint lo reemplaza por un directorio local |
| Gems desactualizadas | `docker compose --profile app exec web bundle install` |
| PDFs / Nailgun | En Docker no está Java 8; PDF con Flying Saucer puede fallar (igual que en setup mínimo local) |

## Deploy a producción (Capistrano)

El servicio `deploy` (profile `deploy`) corre Capistrano por SSH al VPS. No usa MariaDB/Redis ni el profile `app`.

Guía completa (español): [CAPISTRANO_DOCKER.md](./CAPISTRANO_DOCKER.md).

```bash
docker compose --profile deploy build deploy
docker compose --profile deploy run --rm --entrypoint ssh deploy -T rosa
docker compose --profile deploy run --rm deploy   # cap production deploy
```

## Relación con el setup híbrido

Para instalar Ruby en el host y solo usar Docker para MariaDB/Redis, seguí [LOCAL_SETUP.md](LOCAL_SETUP.md). Este documento cubre el camino **todo en Docker** o **solo DB/Redis**.
