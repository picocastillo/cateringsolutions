#!/usr/bin/env bash
# Put a DB dump into docker/db/ for local MariaDB auto-import.
#
# Usage:
#   ./scripts/migrate/prepare-local-dump.sh /path/to/kiosk.sql
#   ./scripts/migrate/prepare-local-dump.sh /path/to/kiosk.sql.gz
#   ./scripts/migrate/prepare-local-dump.sh /path/to/kiosk-migrate-*.tar.gz
#
# Result:
#   docker/db/01-kiosk_development.sql.gz

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST_DIR="${ROOT}/docker/db"
DEST="${DEST_DIR}/01-kiosk_development.sql.gz"
SRC="${1:-}"

if [[ -z "${SRC}" || ! -f "${SRC}" ]]; then
  cat <<EOF >&2
Usage: $0 <dump.sql|dump.sql.gz|kiosk-migrate-*.tar.gz>

Place the prepared dump at:
  docker/db/01-kiosk_development.sql.gz

Then (first boot / empty volume):
  docker compose --profile app up -d --build
EOF
  exit 1
fi

mkdir -p "${DEST_DIR}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

case "${SRC}" in
  *.tar.gz|*.tgz)
    echo "==> Extracting SQL from migration tarball"
    tar -xzf "${SRC}" -C "${TMP}"
    FOUND="$(find "${TMP}" -type f \( -name 'kiosk.sql.gz' -o -name 'kiosk.sql' \) | head -n1 || true)"
    if [[ -z "${FOUND}" ]]; then
      echo "No kiosk.sql / kiosk.sql.gz inside tarball" >&2
      exit 1
    fi
    SRC="${FOUND}"
    ;;
esac

case "${SRC}" in
  *.sql.gz)
    cp -f "${SRC}" "${DEST}"
    ;;
  *.sql)
    gzip -c "${SRC}" > "${DEST}"
    ;;
  *)
    echo "Unsupported file: ${SRC}" >&2
    exit 1
    ;;
esac

# Ensure dump targets the local DB name used by docker-compose.
# Production export uses DB `kiosk`; local Docker uses `kiosk_development`.
gunzip -c "${DEST}" \
  | sed -E \
    -e '1i USE `kiosk_development`;' \
    -e 's/^USE [`'\''"]?kiosk[`'\''"]?;/USE `kiosk_development`;/I' \
    -e 's/^CREATE DATABASE[^;]*;/-- rewritten for local Docker: CREATE DATABASE skipped/' \
  | gzip -c > "${TMP}/rewritten.sql.gz"
mv -f "${TMP}/rewritten.sql.gz" "${DEST}"

echo "==> Ready: ${DEST}"
echo
echo "Next (import runs only on empty MariaDB volume):"
echo "  docker compose down"
echo "  docker volume rm cateringsolutions_mariadb_data 2>/dev/null || true"
echo "  docker compose --profile app up -d --build"
echo
echo "App: http://localhost:3000"
