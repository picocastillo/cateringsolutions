# Local development image for Kiosk (Rails 7.1 / Ruby 3.4.8)
FROM ruby:3.4.8-bookworm

ARG NODE_VERSION=16.20.2
ARG TARGETARCH

ENV APP_HOME=/app \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    RAILS_ENV=development \
    LANG=C.UTF-8

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    default-libmysqlclient-dev \
    default-mysql-client \
    git \
    imagemagick \
    libffi-dev \
    libyaml-dev \
    pkg-config \
    shared-mime-info \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# Node 16 + Yarn (matches .tool-versions)
RUN case "${TARGETARCH}" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      *) NODE_ARCH=x64 ;; \
    esac \
  && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1 \
  && npm install -g yarn@1.22.22 \
  && node -v && yarn -v

WORKDIR ${APP_HOME}

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile || yarn install

COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY . .

EXPOSE 3000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0", "-p", "3000"]
