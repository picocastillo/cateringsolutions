#!/usr/bin/env bash
# Restore kiosk-migrate-*.tar.gz onto the new VPS: DB, shared secrets, uploads,
# and optional server configs (nginx snapshot, systemd unit, crontab).
#
# Usage:
#   sudo ./restore-on-vps.sh /tmp/kiosk-migrate-YYYYMMDD-HHMMSS.tar.gz
#   sudo ./restore-on-vps.sh /tmp/kiosk-migrate-....tar.gz --apply-server-configs

set -euo pipefail

TARBALL=""
APPLY_SERVER=0

usage() {
  echo "Usage: $0 /path/to/kiosk-migrate-*.tar.gz [--apply-server-configs]" >&2
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply-server-configs) APPLY_SERVER=1; shift ;;
    -h|--help) usage 0 ;;
    *)
      if [[ -z "${TARBALL}" ]]; then
        TARBALL="$1"
        shift
      else
        echo "Unexpected arg: $1" >&2
        usage 1
      fi
      ;;
  esac
done

if [[ -z "${TARBALL}" || ! -f "${TARBALL}" ]]; then
  usage 1
fi

APP_ROOT="${APP_ROOT:-/var/www/kiosk}"
SHARED_PATH="${SHARED_PATH:-${APP_ROOT}/shared}"
DB_NAME="${DB_NAME:-kiosk}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_USER="${DB_USER:-root}"
DEPLOY_USER="${DEPLOY_USER:-dev}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-running with sudo..."
  extra=()
  [[ "${APPLY_SERVER}" -eq 1 ]] && extra+=(--apply-server-configs)
  exec sudo --preserve-env=APP_ROOT,SHARED_PATH,DB_NAME,DB_HOST,DB_USER,DB_PASSWORD,DEPLOY_USER,DOMAIN_PROFILE \
    "$0" "${TARBALL}" "${extra[@]}"
fi

CHECKSUM_FILE="${TARBALL}.sha256"
WORK_DIR="$(mktemp -d /tmp/kiosk-restore.XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

echo "==> Verifying checksum (if present)"
if [[ -f "${CHECKSUM_FILE}" ]]; then
  (
    cd "$(dirname "${TARBALL}")"
    sha256sum -c "$(basename "${CHECKSUM_FILE}")"
  )
else
  echo "    no ${CHECKSUM_FILE}; skipping"
fi

echo "==> Extracting ${TARBALL}"
tar -C "${WORK_DIR}" -xzf "${TARBALL}"
PAYLOAD="${WORK_DIR}/payload"
if [[ ! -d "${PAYLOAD}" ]]; then
  echo "Invalid archive: missing payload/" >&2
  exit 1
fi

if [[ -f "${PAYLOAD}/MANIFEST.txt" ]]; then
  echo "==> MANIFEST (head)"
  head -n 25 "${PAYLOAD}/MANIFEST.txt" || true
fi

echo "==> Restoring shared config into ${SHARED_PATH}"
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" \
  "${SHARED_PATH}/config" \
  "${SHARED_PATH}/config/qz_tray" \
  "${SHARED_PATH}/tmp/sockets" \
  "${SHARED_PATH}/tmp/pids" \
  "${SHARED_PATH}/log" \
  "${SHARED_PATH}/storage" \
  "${SHARED_PATH}/public"

if [[ -d "${PAYLOAD}/shared/config" ]]; then
  cp -a "${PAYLOAD}/shared/config/." "${SHARED_PATH}/config/"
fi

restore_optional() {
  local name="$1"
  local dest="$2"
  local src="${PAYLOAD}/optional/${name}"
  if [[ -e "${src}" ]]; then
    echo "    restoring optional ${name} -> ${dest}"
    mkdir -p "$(dirname "${dest}")"
    rm -rf "${dest}"
    cp -a "${src}" "${dest}"
  fi
}

restore_optional "shared_storage" "${SHARED_PATH}/storage"
restore_optional "shared_public" "${SHARED_PATH}/public"
restore_optional "shared_system" "${SHARED_PATH}/system"
restore_optional "current_storage" "${SHARED_PATH}/storage"
restore_optional "current_system" "${SHARED_PATH}/public/system"

stop_app_for_import() {
  echo "==> Stopping Puma and Delayed Job (needed for DROP DATABASE)"
  systemctl stop puma-kiosk || true
  sudo -iu "${DEPLOY_USER}" bash <<EOSU || true
set +e
# shellcheck disable=SC1090
. "\$HOME/.asdf/asdf.sh" 2>/dev/null
cd ${APP_ROOT}/current 2>/dev/null || exit 0
RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue stop
RAILS_ENV=production bundle exec bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue stop
RAILS_ENV=production bundle exec bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue stop
EOSU
  pkill -u "${DEPLOY_USER}" -f delayed_job || true
  sleep 1
}

# Align MariaDB so Rails (host 127.0.0.1 + password from database.yml) and
# `sudo mysql` (unix_socket as OS root) both work. Never print the password.
provision_mysql_app_user() {
  local yml="${SHARED_PATH}/config/database.yml"
  if [[ ! -f "${yml}" ]]; then
    echo "    WARN no ${yml}; skipped MariaDB user alignment" >&2
    return 0
  fi
  echo "==> Aligning MariaDB root@127.0.0.1 with database.yml (keeping unix_socket on localhost)"
  python3 - "${yml}" <<'PY' | mysql --protocol=socket
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
block = None
chunks = re.split(r'(?m)^(production):', text)
if len(chunks) >= 3:
    rest = chunks[2]
    nxt = re.search(r'(?m)^[^\s#]', rest)
    block = rest[: nxt.start()] if nxt else rest
if not block:
    sys.stderr.write("WARN: no production password in database.yml\n")
    sys.exit(0)
m = re.search(r'(?m)^\s*password:\s*(.+?)\s*$', block)
if not m:
    sys.stderr.write("WARN: production.password missing\n")
    sys.exit(0)
pw = m.group(1).strip().strip("'").strip('"')
esc = pw.replace("\\", "\\\\").replace("'", "\\'")
print(
    "ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password "
    f"USING PASSWORD('{esc}');\n"
    f"CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '{esc}';\n"
    f"ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '{esc}';\n"
    "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;\n"
    "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;\n"
    "FLUSH PRIVILEGES;"
)
PY
}

echo "==> Importing database '${DB_NAME}'"
DUMP_GZ="${PAYLOAD}/kiosk.sql.gz"
DUMP_SQL="${PAYLOAD}/kiosk.sql"
if [[ -f "${DUMP_GZ}" ]]; then
  IMPORT_SRC="${DUMP_GZ}"
elif [[ -f "${DUMP_SQL}" ]]; then
  IMPORT_SRC="${DUMP_SQL}"
else
  echo "No kiosk.sql.gz / kiosk.sql in archive" >&2
  exit 1
fi

# Ubuntu/MariaDB: TCP to 127.0.0.1 without a password authenticates as
# root@localhost (reverse DNS) and fails with ERROR 1698. Root via unix_socket
# works. Prefer socket; only use TCP when DB_PASSWORD is set.
pipe_dump() {
  if [[ "${IMPORT_SRC}" == *.gz ]]; then
    gunzip -c "${IMPORT_SRC}"
  else
    cat "${IMPORT_SRC}"
  fi
}

mysql_import_socket() {
  echo "    importing via unix_socket (several minutes for a full dump; do not Ctrl-C)..."
  pipe_dump | mysql --protocol=socket --max-allowed-packet=1G "${DB_NAME}"
}

mysql_import_tcp() {
  if [[ -n "${DB_PASSWORD:-}" ]]; then
    export MYSQL_PWD="${DB_PASSWORD}"
  fi
  echo "    importing via TCP ${DB_HOST} as ${DB_USER}..."
  pipe_dump | mysql -h "${DB_HOST}" -u "${DB_USER}" --max-allowed-packet=1G "${DB_NAME}"
}

stop_app_for_import
mysql --protocol=socket -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if mysql --protocol=socket -e "SELECT 1" >/dev/null 2>&1; then
  mysql_import_socket
elif [[ -n "${DB_PASSWORD:-}" ]] && mysql_import_tcp; then
  :
else
  echo "unix_socket import unavailable; retrying TCP (set DB_PASSWORD if this fails)..." >&2
  mysql_import_tcp
fi

provision_mysql_app_user

# Keep a copy of packed server configs for finalize / reference
if [[ -d "${PAYLOAD}/server" ]]; then
  install -d /opt/kiosk-migrate/imported-server
  cp -a "${PAYLOAD}/server/." /opt/kiosk-migrate/imported-server/
  echo "==> Server configs saved under /opt/kiosk-migrate/imported-server/"
fi

if [[ "${APPLY_SERVER}" -eq 1 && -d "${PAYLOAD}/server" ]]; then
  echo "==> Applying packed server extras (not the old production puma unit)"
  if [[ -f "${PAYLOAD}/server/puma-kiosk.service" ]]; then
    echo "    skip packed puma-kiosk.service (keep Ubuntu/asdf unit from bootstrap)"
  fi
  if [[ -f "${PAYLOAD}/server/crontab.dev" ]]; then
    echo "==> Installing crontab for ${DEPLOY_USER}"
    sudo -u "${DEPLOY_USER}" crontab "${PAYLOAD}/server/crontab.dev" || true
  fi
  if [[ -f "${PAYLOAD}/server/domains.txt" ]]; then
    DOMAIN_PROFILE_FILE="/etc/nginx/kiosk-domain-profile"
    DOMAIN_PROFILE_CURRENT=""
    if [[ -f "${DOMAIN_PROFILE_FILE}" ]]; then
      DOMAIN_PROFILE_CURRENT="$(tr -d '[:space:]' <"${DOMAIN_PROFILE_FILE}")"
    fi
    if [[ "${DOMAIN_PROFILE_CURRENT}" == "trackerdev" || "${DOMAIN_PROFILE:-}" == "trackerdev" ]]; then
      echo "    keeping trackerdev /etc/nginx/kiosk-domains.txt (not overwriting from production export)"
    else
      install -m 0644 "${PAYLOAD}/server/domains.txt" /etc/nginx/kiosk-domains.txt
    fi
  fi
  echo "    Note: nginx SSL site is applied by finalize-server.sh (not the raw CentOS-style nginx.conf)."
fi

echo "==> Fixing ownership to ${DEPLOY_USER}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_ROOT}"

echo "==> Sanity checks"
missing=0
for f in \
  "${SHARED_PATH}/config/database.yml" \
  "${SHARED_PATH}/config/qz_tray/private-key.pem"
do
  if [[ -f "${f}" ]]; then
    echo "    OK ${f}"
  else
    echo "    MISSING ${f}" >&2
    missing=1
  fi
done

if [[ -f "${SHARED_PATH}/config/master.key" ]]; then
  echo "    OK ${SHARED_PATH}/config/master.key"
else
  echo "    WARN missing master.key" >&2
fi

TABLE_COUNT="$(mysql --protocol=socket -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';")"
echo "    tables in ${DB_NAME}: ${TABLE_COUNT}"
if [[ "${TABLE_COUNT}" -lt 70 ]]; then
  echo "ERROR: expected ~77 tables, got ${TABLE_COUNT}. Import looks incomplete (Ctrl-C?)." >&2
  exit 1
fi
if ! mysql --protocol=socket -N -e "SHOW TABLES FROM ${DB_NAME} LIKE 'tiendas';" | grep -q tiendas; then
  echo "ERROR: table ${DB_NAME}.tiendas is missing" >&2
  exit 1
fi
if ! mysql --protocol=socket -N -e "SHOW TABLES FROM ${DB_NAME} LIKE 'schema_migrations';" | grep -q schema_migrations; then
  echo "ERROR: table ${DB_NAME}.schema_migrations is missing" >&2
  exit 1
fi
mysql --protocol=socket -N -e "SELECT dominio FROM tiendas WHERE dominio IS NOT NULL AND dominio != ''" "${DB_NAME}" 2>/dev/null \
  | sed 's/^/    tienda dominio: /' || true

if redis-cli ping | grep -q PONG; then
  echo "    OK redis PING"
else
  echo "    FAIL redis" >&2
  missing=1
fi

RESTORE_PROFILE=""
if [[ -f /etc/nginx/kiosk-domain-profile ]]; then
  RESTORE_PROFILE="$(tr -d '[:space:]' </etc/nginx/kiosk-domain-profile)"
fi
RESTORE_PROFILE="${DOMAIN_PROFILE:-${RESTORE_PROFILE:-production}}"

cat <<EOF

Restore finished.

Next:
  1. As ${DEPLOY_USER}: GitHub deploy key + ssh -T git@github.com
  2. Laptop: SSH host \`rosa\` → this VPS, then Capistrano deploy
       docker compose --profile deploy run --rm deploy
  3. DNS A records for profile ${RESTORE_PROFILE}, then:
       DOMAIN_PROFILE=${RESTORE_PROFILE} sudo bash /opt/kiosk-migrate/finalize-server.sh
  4. If this VPS already had a release, start Puma again:
       sudo systemctl start puma-kiosk
  5. Delete the tarball when cutover is confirmed (do not commit secrets)

Do NOT re-run bootstrap-vps.sh after a successful Capistrano deploy (it used to reset current).
Do NOT pass --apply-server-configs on trackerdev (old nginx/puma unit is CentOS production).
EOF

if [[ "${missing}" -ne 0 ]]; then
  echo "Restore completed with warnings." >&2
  exit 2
fi
