# syntax=docker/dockerfile:1
#
# Dockerfile for the Promotable engine's dummy Rails app (spec/dummy).
#
# The dummy app is booted from the repository root because spec/dummy/config/boot.rb
# points BUNDLE_GEMFILE at ../../../Gemfile. So the build context must be the repo
# root and WORKDIR is /rails.
#
# Build:   docker build -t promotable-dummy .
# Run:     docker run --rm -p 3000:3000 promotable-dummy
# Compose: docker compose up

ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}-slim AS base

# Rails app lives here inside the image.
WORKDIR /rails

# Default runtime env — override with `-e` or docker-compose environment.
ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="" \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1

# System packages needed to install gems (sqlite3/nokogiri ship precompiled
# native binaries, but keep the essentials for source-built fallbacks and for
# running the app: git for git-sourced gems, curl for healthchecks, tzdata
# for correct timezone data, and a compiler toolchain in case bundler can't
# resolve a precompiled variant).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        build-essential \
        git \
        curl \
        libyaml-dev \
        libffi-dev \
        libssl-dev \
        pkg-config \
        tzdata && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install bundler that matches Gemfile.lock (BUNDLED WITH 4.0.11).
ARG BUNDLER_VERSION=4.0.11
RUN gem install bundler --version "${BUNDLER_VERSION}"

# Install gems first so this layer is cached when only application code changes.
# The gemspec is referenced from the Gemfile via `gemspec`, so copy it too.
COPY Gemfile Gemfile.lock promotable.gemspec ./
COPY lib/promotable/version.rb lib/promotable/version.rb
RUN bundle install --jobs "$(nproc)" --retry 3

# Copy the rest of the source (respects .dockerignore).
COPY . .

# Ensure directories that Rails writes to at runtime exist and are writable.
RUN mkdir -p spec/dummy/tmp/pids \
             spec/dummy/tmp/cache \
             spec/dummy/tmp/sockets \
             spec/dummy/log \
             spec/dummy/storage

# Entrypoint prepares the DB and cleans up stale server PIDs before exec-ing CMD.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 4000

# Default command runs the dummy app on 0.0.0.0:4000 via the engine's bin/rails
# wrapper, which already points APP_PATH at spec/dummy/config/application.
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "4000"]
