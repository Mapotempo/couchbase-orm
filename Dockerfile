
ARG RUBY_VERSION

FROM ruby:${RUBY_VERSION}

ARG BUNDLE_VERSION
ARG BUNDLE_WITHOUT
ENV LANG C.UTF-8

WORKDIR /srv/app

RUN CODENAME=$(. /etc/os-release; echo ${VERSION_CODENAME}) \
    && echo "deb http://archive.debian.org/debian ${CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list \
    && apt-get -q update > /dev/null \
    && apt-get install -y apt-transport-https curl git jq build-essential libssl-dev \
    && apt-get install -yt ${CODENAME}-backports cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler --version ${BUNDLE_VERSION}

COPY Gemfile couchbase-orm.gemspec .git /srv/app/
COPY lib/couchbase-orm/version.rb /srv/app/lib/couchbase-orm/

RUN bundle config set path 'vendor/bundle' \
    && bundle config set without ${BUNDLE_WITHOUT}

COPY . /srv/app/