#!/usr/bin/env bash
# Final cutover on the NEW VPS: TLS for all domains, HTTPS nginx, start Puma,
# restart Delayed Job if release exists, smoke checks.
#
# Prerequisites:
#   - bootstrap-vps.sh already ran
#   - restore-on-vps.sh imported DB + shared
#   - Capistrano first deploy succeeded (real /var/www/kiosk/current)
#   - DNS A records for all domains point to THIS VPS
#
# Usage:
#   sudo bash /opt/kiosk-migrate/finalize-server.sh
#   DOMAIN_PROFILE=trackerdev sudo bash finalize-server.sh
#   CERTBOT_EMAIL=ops@example.com sudo bash finalize-server.sh
#   sudo bash finalize-server.sh --skip-certbot   # only swap nginx if certs already exist

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
APP_ROOT="${APP_ROOT:-/var/www/kiosk}"
DEPLOY_USER="${DEPLOY_USER:-dev}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
SKIP_CERTBOT=0

if [[ -z "${DOMAIN_PROFILE:-}" && -f /etc/nginx/kiosk-domain-profile ]]; then
  DOMAIN_PROFILE="$(tr -d '[:space:]' </etc/nginx/kiosk-domain-profile)"
fi
DOMAIN_PROFILE="${DOMAIN_PROFILE:-production}"

case "${DOMAIN_PROFILE}" in
  production)
    DOMAINS_TEMPLATE="${TEMPLATE_DIR}/domains.txt"
    NGINX_SSL_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk.conf"
    PRIMARY_DOMAIN_DEFAULT="cateringsolutions.com.ar"
    ;;
  trackerdev)
    DOMAINS_TEMPLATE="${TEMPLATE_DIR}/domains.trackerdev.txt"
    NGINX_SSL_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk.trackerdev.conf"
    PRIMARY_DOMAIN_DEFAULT="cateringsolutions.trackerdev.com.ar"
    ;;
  *)
    echo "Unknown DOMAIN_PROFILE=${DOMAIN_PROFILE} (use production or trackerdev)" >&2
    exit 1
    ;;
esac

if [[ -z "${PRIMARY_DOMAIN:-}" && -f /etc/nginx/kiosk-primary-domain ]]; then
  PRIMARY_DOMAIN="$(tr -d '[:space:]' </etc/nginx/kiosk-primary-domain)"
fi
PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-${PRIMARY_DOMAIN_DEFAULT}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-certbot) SKIP_CERTBOT=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DOMAINS_FILE="${DOMAINS_FILE:-/etc/nginx/kiosk-domains.txt}"
if [[ ! -f "${DOMAINS_FILE}" && -f "${DOMAINS_TEMPLATE}" ]]; then
  DOMAINS_FILE="${DOMAINS_TEMPLATE}"
fi

mapfile -t DOMAINS < <(grep -vE '^\s*(#|$)' "${DOMAINS_FILE}")
if [[ "${#DOMAINS[@]}" -eq 0 ]]; then
  echo "No domains found in ${DOMAINS_FILE}" >&2
  exit 1
fi

mapfile -t APEX_DOMAINS < <(printf '%s\n' "${DOMAINS[@]}" | grep -vE '^www\.' || true)
if [[ "${#APEX_DOMAINS[@]}" -eq 0 ]]; then
  APEX_DOMAINS=("${DOMAINS[@]}")
fi

echo "==> Domain profile: ${DOMAIN_PROFILE}"
echo "==> Primary domain: ${PRIMARY_DOMAIN}"
echo "==> Domains: ${DOMAINS[*]}"

if [[ ! -d "${APP_ROOT}/current" ]] || [[ ! -f "${APP_ROOT}/current/config/puma.rb" ]]; then
  echo "ERROR: ${APP_ROOT}/current does not look like a Capistrano release." >&2
  echo "Run: bundle exec cap production deploy  (from your laptop) first." >&2
  exit 1
fi

if [[ "${SKIP_CERTBOT}" -eq 0 ]]; then
  echo "==> Issuing / renewing Let's Encrypt certificate (HTTP-01)"
  CERTBOT_ARGS=(certbot certonly --nginx --non-interactive --agree-tos --keep-until-expiring
    --cert-name "${PRIMARY_DOMAIN}")
  if [[ -n "${CERTBOT_EMAIL}" ]]; then
    CERTBOT_ARGS+=(--email "${CERTBOT_EMAIL}")
  else
    CERTBOT_ARGS+=(--register-unsafely-without-email)
  fi
  for d in "${DOMAINS[@]}"; do
    CERTBOT_ARGS+=(-d "${d}")
  done
  "${CERTBOT_ARGS[@]}"

  # Ensure dhparam exists (certbot nginx package usually provides this)
  if [[ ! -f /etc/letsencrypt/ssl-dhparams.pem ]]; then
    echo "==> Generating ssl-dhparams.pem"
    openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
  fi
  if [[ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]]; then
    echo "WARN: missing /etc/letsencrypt/options-ssl-nginx.conf — installing certbot nginx plugin files" >&2
    apt-get install -y --no-install-recommends python3-certbot-nginx || true
  fi
else
  echo "==> Skipping certbot (--skip-certbot)"
fi

if [[ ! -f "/etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem" ]]; then
  echo "ERROR: certificate not found at /etc/letsencrypt/live/${PRIMARY_DOMAIN}/" >&2
  exit 1
fi

echo "==> Enabling HTTPS nginx site (profile=${DOMAIN_PROFILE}; /cable + redirects)"
SSL_SRC="${NGINX_SSL_TEMPLATE}"
if [[ ! -f "${SSL_SRC}" ]]; then
  SSL_SRC="/etc/nginx/sites-available/kiosk-ssl.ready"
fi
if [[ ! -f "${SSL_SRC}" ]]; then
  echo "ERROR: missing SSL nginx template (${NGINX_SSL_TEMPLATE})" >&2
  exit 1
fi
install -m 0644 "${SSL_SRC}" /etc/nginx/sites-available/kiosk
ln -sfn /etc/nginx/sites-available/kiosk /etc/nginx/sites-enabled/kiosk
nginx -t
systemctl reload nginx

echo "==> Starting puma-kiosk"
systemctl daemon-reload
systemctl restart puma-kiosk
sleep 2
systemctl --no-pager --full status puma-kiosk || true

echo "==> Restarting Delayed Job pools"
sudo -iu "${DEPLOY_USER}" bash <<EOSU
set -euo pipefail
# shellcheck disable=SC1090
. "\$HOME/.asdf/asdf.sh"
cd ${APP_ROOT}/current
RAILS_ENV=production bundle exec bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue restart || true
RAILS_ENV=production bundle exec bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue restart || true
RAILS_ENV=production bundle exec bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue restart || true
EOSU

echo "==> Smoke checks"
redis-cli ping | grep -q PONG && echo "    OK redis" || echo "    FAIL redis"
mysql -e "USE kiosk; SELECT 1;" &>/dev/null && echo "    OK mariadb kiosk" || echo "    FAIL mariadb"
if [[ -S "${APP_ROOT}/shared/tmp/sockets/puma.sock" ]]; then
  echo "    OK puma.sock"
else
  echo "    FAIL puma.sock missing" >&2
fi

for d in "${APEX_DOMAINS[@]}"; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 "https://${d}/" || echo '000')"
  echo "    HTTPS ${d} -> HTTP ${code}"
done

systemctl enable certbot.timer 2>/dev/null || true

cat <<EOF

Finalize COMPLETE.

  HTTPS nginx active for:
    ${DOMAINS[*]}

  Services:
    systemctl status puma-kiosk nginx mariadb redis-server

  Logs:
    journalctl -u puma-kiosk -f
    tail -f ${APP_ROOT}/shared/log/production.log

If a domain still fails TLS, wait for DNS propagation and re-run:
  sudo bash ${SCRIPT_DIR}/finalize-server.sh
EOF
