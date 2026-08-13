#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu Server 24.04 LTS VPS for a COMPLETE Kiosk production stack:
# Capistrano layout, asdf Ruby/Node, MariaDB, Redis, nginx (all 3 domains), systemd,
# certbot (certs issued later by finalize-server.sh), firewall, timezone.
#
# Run as root on the new VPS:
#   sudo bash scripts/migrate/bootstrap-vps.sh
#   DOMAIN_PROFILE=trackerdev sudo bash scripts/migrate/bootstrap-vps.sh
#
# Domains (one app / one DB / multiple tiendas):
#   production (default): cateringsolutions.com.ar, tivoglio.com.ar, cotidianomarket.ar (+ www)
#   trackerdev: cateringsolutions.trackerdev.com.ar, tivoglio.trackerdev.com.ar (+ www)

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
APP_ROOT="${APP_ROOT:-/var/www/kiosk}"
DEPLOY_USER="${DEPLOY_USER:-dev}"
RUBY_VERSION="${RUBY_VERSION:-3.4.8}"
NODE_VERSION="${NODE_VERSION:-16.20.2}"
DB_NAME="${DB_NAME:-kiosk}"
TZ_AREA="${TZ_AREA:-America/Argentina/Buenos_Aires}"
DOMAIN_PROFILE="${DOMAIN_PROFILE:-production}"

case "${DOMAIN_PROFILE}" in
  production)
    DOMAINS_TEMPLATE="${TEMPLATE_DIR}/domains.txt"
    NGINX_HTTP_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk-http-only.conf"
    NGINX_SSL_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk.conf"
    PRIMARY_DOMAIN_DEFAULT="cateringsolutions.com.ar"
    DOMAIN_SUMMARY="cateringsolutions.com.ar, tivoglio.com.ar, cotidianomarket.ar (+ www)"
    ;;
  trackerdev)
    DOMAINS_TEMPLATE="${TEMPLATE_DIR}/domains.trackerdev.txt"
    NGINX_HTTP_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk-http-only.trackerdev.conf"
    NGINX_SSL_TEMPLATE="${TEMPLATE_DIR}/nginx-kiosk.trackerdev.conf"
    PRIMARY_DOMAIN_DEFAULT="cateringsolutions.trackerdev.com.ar"
    DOMAIN_SUMMARY="cateringsolutions.trackerdev.com.ar, tivoglio.trackerdev.com.ar (+ www)"
    ;;
  *)
    echo "Unknown DOMAIN_PROFILE=${DOMAIN_PROFILE} (use production or trackerdev)" >&2
    exit 1
    ;;
esac

for f in "${DOMAINS_TEMPLATE}" "${NGINX_HTTP_TEMPLATE}" "${NGINX_SSL_TEMPLATE}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Missing template: ${f}" >&2
    exit 1
  fi
done

if [[ ! -d "${TEMPLATE_DIR}" ]]; then
  echo "Missing templates at ${TEMPLATE_DIR}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Detecting OS"
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Warning: designed for Ubuntu 24.04; detected ID=${ID:-unknown}" >&2
fi
if [[ "${VERSION_ID:-}" != "24.04" ]]; then
  echo "Warning: recommended OS is Ubuntu 24.04 LTS; detected ${VERSION_ID:-unknown}" >&2
fi

echo "==> Timezone ${TZ_AREA}"
timedatectl set-timezone "${TZ_AREA}" || true

echo "==> Installing packages"
apt-get update -y

# Ubuntu's default-mysql-* metapackages pull Oracle MySQL 8.0 client,
# which conflicts with MariaDB (virtual-mysql-client / mysql-client-core-8.0).
# Purge them so a re-run after a failed mix still succeeds.
apt-get remove -y --purge \
  default-mysql-client \
  default-libmysqlclient-dev \
  mysql-client \
  mysql-client-8.0 \
  mysql-client-core-8.0 \
  mysql-server \
  mysql-server-8.0 \
  mysql-server-core-8.0 \
  libmysqlclient-dev \
  2>/dev/null || true
apt-get -y --purge autoremove || true

apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  ca-certificates \
  git \
  gnupg \
  libffi-dev \
  libgdbm-dev \
  libgmp-dev \
  libncurses5-dev \
  libreadline-dev \
  libssl-dev \
  libyaml-dev \
  zlib1g-dev \
  libmariadb-dev \
  libmariadb-dev-compat \
  mariadb-server \
  mariadb-client \
  redis-server \
  nginx \
  imagemagick \
  shared-mime-info \
  pkg-config \
  xz-utils \
  unzip \
  software-properties-common \
  sudo \
  ufw \
  certbot \
  python3-certbot-nginx \
  logrotate \
  cron

# Java for Nailgun / Flying Saucer
if apt-cache show openjdk-8-jre-headless &>/dev/null; then
  apt-get install -y --no-install-recommends openjdk-8-jre-headless
elif apt-cache show openjdk-17-jre-headless &>/dev/null; then
  echo "Warning: openjdk-8 not available; installing openjdk-17 (verify PDF/Nailgun)" >&2
  apt-get install -y --no-install-recommends openjdk-17-jre-headless
else
  echo "Warning: no OpenJDK package found; install Java 8 manually for PDF generation" >&2
fi

echo "==> Creating deploy user '${DEPLOY_USER}'"
if ! id -u "${DEPLOY_USER}" &>/dev/null; then
  adduser --disabled-password --gecos "Kiosk deploy" "${DEPLOY_USER}"
fi
usermod -aG sudo "${DEPLOY_USER}"

install -d -m 0700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
if [[ -f /root/.ssh/authorized_keys ]] && [[ ! -s "/home/${DEPLOY_USER}/.ssh/authorized_keys" ]]; then
  cp /root/.ssh/authorized_keys "/home/${DEPLOY_USER}/.ssh/authorized_keys"
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh/authorized_keys"
  chmod 0600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
fi

echo "==> Installing sudoers for puma-kiosk"
install -m 0440 "${TEMPLATE_DIR}/sudoers-kiosk-puma" /etc/sudoers.d/kiosk-puma
if [[ "${DEPLOY_USER}" != "dev" ]]; then
  sed -i "s/^dev /${DEPLOY_USER} /" /etc/sudoers.d/kiosk-puma
fi
visudo -cf /etc/sudoers.d/kiosk-puma

echo "==> Creating Capistrano directory layout under ${APP_ROOT}"
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" \
  "${APP_ROOT}" \
  "${APP_ROOT}/releases" \
  "${APP_ROOT}/shared" \
  "${APP_ROOT}/shared/config" \
  "${APP_ROOT}/shared/config/qz_tray" \
  "${APP_ROOT}/shared/tmp/sockets" \
  "${APP_ROOT}/shared/tmp/pids" \
  "${APP_ROOT}/shared/log" \
  "${APP_ROOT}/shared/bundle" \
  "${APP_ROOT}/shared/node_modules" \
  "${APP_ROOT}/shared/storage" \
  "${APP_ROOT}/shared/public" \
  "${APP_ROOT}/repo"

# Placeholder public so nginx root exists before first Capistrano release
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${APP_ROOT}/current_placeholder/public"
ln -sfn "${APP_ROOT}/current_placeholder" "${APP_ROOT}/current"
echo '<!doctype html><title>Kiosk</title><h1>Deploy pending</h1>' \
  > "${APP_ROOT}/current_placeholder/public/index.html"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_ROOT}/current_placeholder"

echo "==> Configuring MariaDB (bind 127.0.0.1, create DB ${DB_NAME})"
systemctl enable --now mariadb
cat > /etc/mysql/mariadb.conf.d/99-kiosk-bind.cnf <<'EOF'
[mysqld]
bind-address = 127.0.0.1
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF
systemctl restart mariadb
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "==> Configuring Redis (localhost)"
systemctl enable --now redis-server
REDIS_CONF="/etc/redis/redis.conf"
if [[ -f "${REDIS_CONF}" ]]; then
  sed -i 's/^bind .*/bind 127.0.0.1 -::1/' "${REDIS_CONF}" || true
  if ! grep -qE '^bind ' "${REDIS_CONF}"; then
    echo 'bind 127.0.0.1 -::1' >> "${REDIS_CONF}"
  fi
  systemctl restart redis-server
fi
redis-cli ping | grep -q PONG

echo "==> Installing asdf + Ruby ${RUBY_VERSION} + Node ${NODE_VERSION} as ${DEPLOY_USER}"
sudo -iu "${DEPLOY_USER}" bash <<EOSU
set -euo pipefail
export RUBY_VERSION="${RUBY_VERSION}"
export NODE_VERSION="${NODE_VERSION}"

if [[ ! -d "\$HOME/.asdf" ]]; then
  git clone https://github.com/asdf-vm/asdf.git "\$HOME/.asdf" --branch v0.14.1
fi

grep -q 'asdf.sh' "\$HOME/.bashrc" 2>/dev/null || {
  echo '. "\$HOME/.asdf/asdf.sh"' >> "\$HOME/.bashrc"
  echo '. "\$HOME/.asdf/completions/asdf.bash"' >> "\$HOME/.bashrc"
}

# shellcheck disable=SC1090
. "\$HOME/.asdf/asdf.sh"

asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git 2>/dev/null || true
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git 2>/dev/null || true

asdf install ruby "\$RUBY_VERSION"
asdf global ruby "\$RUBY_VERSION"

asdf install nodejs "\$NODE_VERSION"
asdf global nodejs "\$NODE_VERSION"

gem install bundler --no-document
npm install -g yarn@1.22.22

ruby -v
node -v
yarn -v
EOSU

echo "==> Installing systemd unit puma-kiosk"
install -m 0644 "${TEMPLATE_DIR}/puma-kiosk.service" /etc/systemd/system/puma-kiosk.service
if [[ "${DEPLOY_USER}" != "dev" ]]; then
  sed -i "s|/home/dev|/home/${DEPLOY_USER}|g; s|User=dev|User=${DEPLOY_USER}|; s|Group=dev|Group=${DEPLOY_USER}|" \
    /etc/systemd/system/puma-kiosk.service
fi
systemctl daemon-reload
systemctl enable puma-kiosk
echo "    puma-kiosk enabled (start after first real Capistrano deploy)"

echo "==> Installing nginx (HTTP-only; profile=${DOMAIN_PROFILE}; TLS via finalize-server.sh)"
install -d -m 0755 /var/www/letsencrypt
install -m 0644 "${NGINX_HTTP_TEMPLATE}" /etc/nginx/sites-available/kiosk
install -m 0644 "${NGINX_SSL_TEMPLATE}" /etc/nginx/sites-available/kiosk-ssl.ready
install -m 0644 "${DOMAINS_TEMPLATE}" /etc/nginx/kiosk-domains.txt
printf '%s\n' "${DOMAIN_PROFILE}" > /etc/nginx/kiosk-domain-profile
printf '%s\n' "${PRIMARY_DOMAIN_DEFAULT}" > /etc/nginx/kiosk-primary-domain
rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/kiosk /etc/nginx/sites-enabled/kiosk
# Tune worker_processes toward production (8 cores common); leave if already set
if ! grep -qE '^\s*worker_processes' /etc/nginx/nginx.conf; then
  sed -i 's/^worker_processes.*/worker_processes auto;/' /etc/nginx/nginx.conf || true
fi
nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo "==> Firewall (OpenSSH + HTTP/HTTPS)"
ufw allow OpenSSH || true
ufw allow 'Nginx Full' || true
ufw --force enable || true

# Copy migrate scripts into a stable path for later steps
install -d /opt/kiosk-migrate
cp -a "${SCRIPT_DIR}/." /opt/kiosk-migrate/
chmod +x /opt/kiosk-migrate/*.sh 2>/dev/null || true

cat <<EOF

Bootstrap COMPLETE on $(hostname).

Installed:
  - user ${DEPLOY_USER} + asdf Ruby ${RUBY_VERSION} / Node ${NODE_VERSION} / Yarn
  - Capistrano dirs under ${APP_ROOT}
  - MariaDB DB \`${DB_NAME}\`, Redis localhost
  - DOMAIN_PROFILE=${DOMAIN_PROFILE}
  - nginx HTTP for: ${DOMAIN_SUMMARY}
  - systemd puma-kiosk (enabled, not started yet)
  - certbot (ready; run finalize-server.sh after DNS + deploy)
  - scripts copied to /opt/kiosk-migrate/

Next:
  1. GitHub deploy key as ${DEPLOY_USER}:
       sudo -iu ${DEPLOY_USER}
       ssh-keygen -t ed25519 -C "kiosk-deploy@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
       # add ~/.ssh/id_ed25519.pub as deploy key; then: ssh -T git@github.com

  2. Restore migration tarball:
       sudo bash /opt/kiosk-migrate/restore-on-vps.sh /tmp/kiosk-migrate-*.tar.gz
       # trackerdev: restore will not overwrite /etc/nginx/kiosk-domains.txt

  3. Laptop: point SSH host \`rosa\` at this VPS IP, then:
       bundle exec cap production deploy
       # Capistrano replaces ${APP_ROOT}/current with a real release

  4. Point DNS A records for profile domains to this VPS, then:
       DOMAIN_PROFILE=${DOMAIN_PROFILE} sudo bash /opt/kiosk-migrate/finalize-server.sh
       # issues Let's Encrypt, enables HTTPS nginx, starts puma-kiosk, smoke-checks

Recommended OS: Ubuntu Server 24.04 LTS (x86_64), 2+ vCPU / 4–8 GB RAM / 40+ GB SSD.
EOF
