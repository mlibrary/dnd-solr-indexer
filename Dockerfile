FROM ruby:3.4 AS base

ARG UNAME=app
ARG UID=1000
ARG GID=1000
ARG APP_HOME=/app

ENV BUNDLE_PATH /bundle
ENV RAILS_LOG_TO_STDOUT 1
ENV RAILS_SERVE_STATIC_FILES 1
ENV APP_HOME ${APP_HOME}


#Create the group for the user
RUN groupadd -g ${GID} -o ${UNAME}

#Create the User and assign /app as its home directory
RUN useradd -m -d ${APP_HOME} -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME}

RUN mkdir -p ${BUNDLE_PATH} ${APP_HOME} && chown ${UID}:${GID} ${BUNDLE_PATH} ${APP_HOME}
WORKDIR $APP_HOME
USER $UNAME

FROM base AS development

CMD tail -f /dev/null

FROM base AS production

COPY --chown=${UID}:${GID} Gemfile Gemfile.lock ${APP_HOME}/
RUN bundle install

COPY --chown=${UID}:${GID} . .

CMD bundle exec bin/index
