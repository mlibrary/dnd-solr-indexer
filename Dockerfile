FROM ruby:4.0@sha256:dd87233ce44e8362fed00a1fd590c01e3dd8f8eb0001ea4a2c8a071388e9185b AS base

ARG UNAME=app
ARG UID=1000
ARG GID=1000
ARG APP_HOME=/app

ENV BUNDLE_PATH /bundle
ENV RAILS_LOG_TO_STDOUT 1
ENV RAILS_SERVE_STATIC_FILES 1
ENV APP_HOME ${APP_HOME}

#Create the group for the user
#Create the User and assign /app as its home directory
RUN groupadd -g ${GID} -o ${UNAME} \
 && useradd -m -d ${APP_HOME} -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME} \
 && mkdir -p ${BUNDLE_PATH} ${APP_HOME} \
 && chown ${UID}:${GID} ${BUNDLE_PATH} ${APP_HOME}

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR $APP_HOME

USER $UNAME

FROM base AS development

CMD tail -f /dev/null

FROM base AS production

COPY --chown=${UID}:${GID} Gemfile Gemfile.lock ${APP_HOME}/
RUN bundle install

COPY --chown=${UID}:${GID} . .

CMD bundle exec bin/index
