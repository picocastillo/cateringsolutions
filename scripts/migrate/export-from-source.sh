#!/usr/bin/env bash
# Export production DB + Capistrano shared secrets/files + server configs
# (nginx, systemd) from the current host. Run as `dev` (sudo used as needed).
#
# Usage:
#   ./export-from-source.sh
#   ./export-from-source.sh --maintenance   # stop Puma + Delayed Job (final cutover)
#
# Env: APP_ROOT, SHARED_PATH, DB_NAME, DB_HOST, DB_USER, DB_PASSWORD, OUT_DIR

set -euo pipefail

APP_ROOT="${APP_ROOT:-/var/www/kiosk}"
SHARED_PATH="${SHARED_PATH:-${APP_ROOT}/shared}"
CURRENT_PATH="${CURRENT_PATH:-${APP_ROOT}/current}"
DB_NAME="${DB_NAME:-kiosk}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_USER="${DB_USER:-root}"
OUT_BASE="${OUT_DIR:-/tmp}"
MAINTENANCE=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --maintenance) MAINTENANCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="${OUT_BASE}/kiosk-migrate-${TIMESTAMP}"
PACK_DIR="${WORK_DIR}/payload"
TARBALL="${OUT_BASE}/kiosk-migrate-${TIMESTAMP}.tar.gz"

mkdir -p "${PACK_DIR}/shared" "${PACK_DIR}/optional" "${PACK_DIR}/server"

echo "==> Export work dir: ${WORK_DIR}"

stop_app_if_requested() {
  if [[ "${MAINTENANCE}" -ne 1 ]]; then
    echo "==> Skipping app stop (pass --maintenance for a frozen cutover dump)"
    return 0
  fi

  echo "==> Maintenance mode: stopping Delayed Job pools and puma-kiosk"
  if [[ -d "${CURRENT_PATH}" ]]; then
    (
      # shellcheck disable=SC1090
      [[ -f "${HOME}/.asdf/asdf.sh" ]] && . "${HOME}/.asdf/asdf.sh"
      cd "${CURRENT_PATH}"
      RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue stop || true
      RAILS_ENV=production bundle exec bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue stop || true
      RAILS_ENV=production bundle exec bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue stop || true
    )
  fi
  sudo systemctl stop puma-kiosk || true
  rm -f /tmp/fast_queue/*.pid /tmp/slow_queue/*.pid /tmp/confirmacion_queue/*.pid 2>/dev/null || true
}

copy_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -e "${src}" ]]; then
    mkdir -p "$(dirname "${dest}")"
    if [[ -r "${src}" ]]; then
      cp -a "${src}" "${dest}"
    else
      sudo cp -a "${src}" "${dest}"
      sudo chown -R "$(whoami):$(whoami)" "${dest}" 2>/dev/null || true
    fi
    echo "    packed: ${src}"
  else
    echo "    missing (skip): ${src}"
  fi
}

dump_database() {
  echo "==> Dumping MariaDB database '${DB_NAME}'"
  local dump_file="${PACK_DIR}/kiosk.sql"
  local mysql_args=(-h "${DB_HOST}" -u "${DB_USER}")

  if [[ -n "${DB_PASSWORD:-}" ]]; then
    export MYSQL_PWD="${DB_PASSWORD}"
  fi

  local dump_cmd=(mysqldump
    --single-transaction
    --routines
    --triggers
    --events
    --default-character-set=utf8mb4
    "${mysql_args[@]}"
    "${DB_NAME}"
  )

  if [[ -n "${MYSQLDUMP_OPTS:-}" ]]; then
    # shellcheck disable=SC2206
    dump_cmd+=(${MYSQLDUMP_OPTS})
  fi

  if ! "${dump_cmd[@]}" > "${dump_file}" 2>/tmp/kiosk-mysqldump.err; then
    echo "mysqldump failed; retrying via sudo mysqldump..." >&2
    cat /tmp/kiosk-mysqldump.err >&2 || true
    if sudo mysqldump \
      --single-transaction --routines --triggers --events \
      --default-character-set=utf8mb4 \
      "${DB_NAME}" > "${dump_file}"; then
      echo "    dumped via sudo mysqldump"
    else
      exit 1
    fi
  fi

  gzip -9 "${dump_file}"
  echo "    wrote ${PACK_DIR}/kiosk.sql.gz"
}

pack_shared() {
  echo "==> Packing shared secrets and uploads"
  copy_if_exists "${SHARED_PATH}/config/database.yml" "${PACK_DIR}/shared/config/database.yml"
  copy_if_exists "${SHARED_PATH}/config/master.key" "${PACK_DIR}/shared/config/master.key"
  copy_if_exists "${SHARED_PATH}/config/qz_tray" "${PACK_DIR}/shared/config/qz_tray"

  local optional_paths=(
    "${SHARED_PATH}/storage"
    "${SHARED_PATH}/public"
    "${APP_ROOT}/current/storage"
    "${APP_ROOT}/current/public/system"
    "${SHARED_PATH}/system"
  )
  for p in "${optional_paths[@]}"; do
    if [[ -e "${p}" ]]; then
      local base parent dest_name
      base="$(basename "${p}")"
      parent="$(basename "$(dirname "${p}")")"
      dest_name="${parent}_${base}"
      cp -a "${p}" "${PACK_DIR}/optional/${dest_name}"
      echo "    packed optional: ${p} -> optional/${dest_name}"
    fi
  done
}

pack_server_configs() {
  echo "==> Packing server configs (nginx, systemd, crontab)"
  copy_if_exists /etc/nginx/nginx.conf "${PACK_DIR}/server/nginx.conf"
  # Also pack sites if Ubuntu-style layout exists on source
  if [[ -d /etc/nginx/sites-available ]]; then
    sudo mkdir -p "${PACK_DIR}/server/sites-available"
    sudo cp -a /etc/nginx/sites-available/. "${PACK_DIR}/server/sites-available/" 2>/dev/null || true
    sudo chown -R "$(whoami):$(whoami)" "${PACK_DIR}/server/sites-available" 2>/dev/null || true
  fi
  copy_if_exists /etc/systemd/system/puma-kiosk.service "${PACK_DIR}/server/puma-kiosk.service"
  # Deploy user crontab (whenever)
  if crontab -l &>/dev/null; then
    crontab -l > "${PACK_DIR}/server/crontab.dev" || true
    echo "    packed: crontab for $(whoami)"
  fi
  # Domain list from DB when possible
  {
    echo "cateringsolutions.com.ar"
    echo "www.cateringsolutions.com.ar"
    echo "tivoglio.com.ar"
    echo "www.tivoglio.com.ar"
    echo "cotidianomarket.ar"
    echo "www.cotidianomarket.ar"
  } > "${PACK_DIR}/server/domains.txt"

  if command -v mysql &>/dev/null; then
    local db_domains
    db_domains="$(
      if [[ -n "${DB_PASSWORD:-}" ]]; then export MYSQL_PWD="${DB_PASSWORD}"; fi
      mysql -N -h "${DB_HOST}" -u "${DB_USER}" "${DB_NAME}" \
        -e "SELECT dominio FROM tiendas WHERE dominio IS NOT NULL AND dominio != ''" 2>/dev/null \
      || sudo mysql -N "${DB_NAME}" \
        -e "SELECT dominio FROM tiendas WHERE dominio IS NOT NULL AND dominio != ''" 2>/dev/null \
      || true
    )"
    if [[ -n "${db_domains}" ]]; then
      echo "${db_domains}" >> "${PACK_DIR}/server/domains.from_db.txt"
      echo "    packed tienda dominios from DB"
    fi
  fi
}

write_manifest() {
  echo "==> Writing MANIFEST.txt"
  local manifest="${PACK_DIR}/MANIFEST.txt"
  {
    echo "kiosk migration export"
    echo "timestamp: ${TIMESTAMP}"
    echo "hostname: $(hostname -f 2>/dev/null || hostname)"
    echo "app_root: ${APP_ROOT}"
    echo "shared_path: ${SHARED_PATH}"
    echo "db_name: ${DB_NAME}"
    echo "maintenance: ${MAINTENANCE}"
    echo "domains: cateringsolutions.com.ar tivoglio.com.ar cotidianomarket.ar (+ www)"
    echo "ruby: $( ( . "${HOME}/.asdf/asdf.sh" 2>/dev/null; ruby -v ) 2>/dev/null || echo 'n/a')"
    echo "node: $( ( . "${HOME}/.asdf/asdf.sh" 2>/dev/null; node -v ) 2>/dev/null || echo 'n/a')"
    echo "user: $(whoami)"
    echo
    echo "files:"
    (cd "${PACK_DIR}" && find . -type f | sort)
    echo
    echo "checksums (sha256):"
    (cd "${PACK_DIR}" && find . -type f ! -name MANIFEST.txt -print0 | sort -z | xargs -0 sha256sum)
  } > "${manifest}"
}

create_tarball() {
  echo "==> Creating tarball ${TARBALL}"
  tar -C "${WORK_DIR}" -czf "${TARBALL}" payload
  sha256sum "${TARBALL}" | tee "${TARBALL}.sha256"
}

print_next_steps() {
  cat <<EOF

Export complete.

  Tarball:  ${TARBALL}
  Checksum: ${TARBALL}.sha256

Copy to the new VPS:

  scp ${TARBALL} ${TARBALL}.sha256 root@NEW_VPS_IP:/tmp/

On the new VPS:

  sudo bash scripts/migrate/restore-on-vps.sh /tmp/$(basename "${TARBALL}")
  # after cap deploy + DNS pointed:
  sudo bash scripts/migrate/finalize-server.sh

Do NOT commit the tarball or secrets to git.
EOF
}

stop_app_if_requested
dump_database
pack_shared
pack_server_configs
write_manifest
create_tarball
print_next_steps
