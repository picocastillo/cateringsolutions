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

mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

mysql_import() {
  if [[ -n "${DB_PASSWORD:-}" ]]; then
    export MYSQL_PWD="${DB_PASSWORD}"
  fi
  if [[ "${IMPORT_SRC}" == *.gz ]]; then
    gunzip -c "${IMPORT_SRC}" | mysql -h "${DB_HOST}" -u "${DB_USER}" "${DB_NAME}"
  else
    mysql -h "${DB_HOST}" -u "${DB_USER}" "${DB_NAME}" < "${IMPORT_SRC}"
  fi
}

if ! mysql_import 2>/tmp/kiosk-mysql-import.err; then
  echo "TCP import failed; retrying via unix_socket mysql..." >&2
  cat /tmp/kiosk-mysql-import.err >&2 || true
  if [[ "${IMPORT_SRC}" == *.gz ]]; then
    gunzip -c "${IMPORT_SRC}" | mysql "${DB_NAME}"
  else
    mysql "${DB_NAME}" < "${IMPORT_SRC}"
  fi
fi

# Keep a copy of packed server configs for finalize / reference
if [[ -d "${PAYLOAD}/server" ]]; then
  install -d /opt/kiosk-migrate/imported-server
  cp -a "${PAYLOAD}/server/." /opt/kiosk-migrate/imported-server/
  echo "==> Server configs saved under /opt/kiosk-migrate/imported-server/"
fi

if [[ "${APPLY_SERVER}" -eq 1 && -d "${PAYLOAD}/server" ]]; then
  echo "==> Applying packed systemd unit (if present)"
  if [[ -f "${PAYLOAD}/server/puma-kiosk.service" ]]; then
    install -m 0644 "${PAYLOAD}/server/puma-kiosk.service" /etc/systemd/system/puma-kiosk.service
    systemctl daemon-reload
    systemctl enable puma-kiosk
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

TABLE_COUNT="$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';")"
echo "    tables in ${DB_NAME}: ${TABLE_COUNT}"
mysql -N -e "SELECT dominio FROM tiendas WHERE dominio IS NOT NULL AND dominio != ''" "${DB_NAME}" 2>/dev/null \
  | sed 's/^/    tienda dominio: /' || true

if redis-cli ping | grep -q PONG; then
  echo "    OK redis PING"
else
  echo "    FAIL redis" >&2
  missing=1
fi

cat <<EOF

Restore finished.

Next:
  1. Deploy key as ${DEPLOY_USER}; from laptop: point \`rosa\` here → bundle exec cap production deploy
  2. Point DNS for cateringsolutions.com.ar, tivoglio.com.ar, cotidianomarket.ar (+ www) here
  3. sudo bash /opt/kiosk-migrate/finalize-server.sh
  4. Delete the tarball when cutover is confirmed (do not commit secrets)
EOF

if [[ "${missing}" -ne 0 ]]; then
  echo "Restore completed with warnings." >&2
  exit 2
fi
