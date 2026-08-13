#!/usr/bin/env bash
set -euo pipefail

cd /app

# Repo may ship `log` as a symlink to the production path; fix for containers.
if [ -L log ] || [ ! -d log ]; then
  rm -f log
  mkdir -p log
fi
mkdir -p tmp/pids tmp/cache tmp/sockets storage
touch log/.keep tmp/.keep storage/.keep

DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USERNAME:-root}"
DB_PASS="${DB_PASSWORD:-mysqlroot}"

echo "==> Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
until mysqladmin ping -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" --silent; do
  sleep 2
done
echo "==> MariaDB is up"

if [ "${BUNDLE_INSTALL_ON_START:-true}" = "true" ]; then
  echo "==> Checking gems..."
  bundle check || bundle install
fi

if [ "${YARN_INSTALL_ON_START:-true}" = "true" ]; then
  echo "==> Checking JS deps..."
  yarn install --frozen-lockfile || yarn install
fi

# Optional: create empty schema if DB has no tables and no dump was imported.
if [ "${AUTO_PREPARE_DB:-false}" = "true" ]; then
  echo "==> Preparing database (db:prepare)..."
  bundle exec rails db:prepare
fi

rm -f tmp/pids/server.pid

exec "$@"
