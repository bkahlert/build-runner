FROM docker:20.10.11-alpine3.14

# build time only options
ARG APP_USER=runner
ARG APP_GROUP=$APP_USER
ARG SSH_PORT=2022

# build and run time options
ARG TZ=UTC
ARG PUID=1000
ARG PGID=1000
ARG AUTHORIZED_KEYS=''
ARG PASSWORD=''

RUN apk --no-cache --update add \
    bash \
    bash-completion \
    ca-certificates \
    curl \
    dumb-init \
    docker-cli \
    git \
    ncurses \
    openjdk11 \
    rsync \
    shadow \
    sshpass \
    supervisor

COPY --from=crazymax/yasu:1.17.0 / /
COPY rootfs /
RUN chmod +x \
    /usr/local/bin/entrypoint_user.sh \
    /usr/local/sbin/entrypoint.sh \
 && sed -Ei -e "s/([[:space:]]app_user=)[^[:space:]]*/\1$APP_USER/" \
            -e "s/([[:space:]]app_group=)[^[:space:]]*/\1$APP_GROUP/" \
             /usr/local/sbin/entrypoint.sh \
 && curl -LfsSo /usr/local/bin/logr.sh https://raw.githubusercontent.com/bkahlert/logr/master/logr.sh

ENV TZ="$TZ" \
    LANG="C.UTF-8" \
    PUID="$PUID" \
    PGID="$PGID" \
    AUTHORIZED_KEYS="$AUTHORIZED_KEYS" \
    PASSWORD="$PASSWORD" \
    JAVA_HOME="/usr/lib/jvm/default-jvm/j"re

RUN groupadd \
    --gid "$PGID" \
    "$APP_GROUP" \
 && useradd \
    --uid "$PUID" \
    --gid "$APP_GROUP" \
    --shell "/bin/bash" \
    --home-dir "/home/$APP_USER" \
    "$APP_USER" \
 && rm /etc/motd \
 && mkdir -p "/home/$APP_USER" \
 && echo "export JAVA_HOME=$JAVA_HOME" >> "/home/$APP_USER/.bashrc" \
 && echo "[ -f ~/.bashrc ] && . ~/.bashrc" >> "/home/$APP_USER/.bash_profile" \
 && chmod -R 0711 "/home/$APP_USER" \
 && chown -R "$APP_USER:$APP_GROUP" "/home/$APP_USER" \
 && apk update \
 && apk upgrade \
 && apk --no-cache --update add openssh-server \
 && ssh-keygen -A \
 && sed -Ei -e 's/#?[[:space:]]*Port .*$/Port '"$SSH_PORT"'/g' \
            -e 's/#?[[:space:]]*ChallengeResponseAuthentication .*$/ChallengeResponseAuthentication no/g' \
            -e 's/#?[[:space:]]*PasswordAuthentication .*$/PasswordAuthentication no/g' \
            /etc/ssh/sshd_config

EXPOSE "$SSH_PORT"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/sbin/entrypoint.sh"]

HEALTHCHECK --interval=5s --timeout=5s --start-period=10s \
  CMD netstat -lp | grep -E "$SSH_PORT.*LISTEN.*sshd" || exit 1
