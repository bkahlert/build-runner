FROM docker:20.10.8-alpine3.14

ARG TZ=''
ARG PUID=1000
ARG PGID=1000
ARG AUTHORIZED_KEYS=''
ARG PASSWORD=runner

ARG DUMB_INIT_VERSION=1.2.5

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

COPY --from=crazymax/yasu:latest / /
COPY rootfs /
RUN chmod +x \
    /usr/local/bin/entrypoint_user.sh \
    /usr/local/sbin/entrypoint.sh \
    /usr/local/sbin/runtime_keygen.sh \
 && curl -LfsSo /usr/local/bin/logr.sh https://raw.githubusercontent.com/bkahlert/logr/master/logr.sh

ENV TZ=$TZ \
    PUID=$PUID \
    PGID=$PGID \
    AUTHORIZED_KEYS=$AUTHORIZED_KEYS \
    PASSWORD=${AUTHORIZED_KEYS:+$PASSWORD} \
    JAVA_HOME=/usr/lib/jvm/default-jvm/jre
RUN groupadd \
    --gid $PGID \
    runner \
 && useradd \
    --uid $PUID \
    --gid runner \
    --shell /bin/bash \
    --home-dir /home/runner \
    runner \
 && rm /etc/motd \
 && mkdir -p /home/runner \
 && echo "export JAVA_HOME=$JAVA_HOME" >> /home/runner/.bashrc \
 && echo "[ -f ~/.bashrc ] && . ~/.bashrc" >> /home/runner/.bash_profile \
 && chmod -R 0711 /home/runner \
 && chown -R runner:runner /home/runner \
 && apk update \
 && apk upgrade \
 && apk --no-cache --update add openssh-server \
 && sed -Ei -e 's/#?[[:space:]]*Port .*$/Port 2022/g' /etc/ssh/sshd_config \
 && sed -Ei -e 's/#?[[:space:]]*ChallengeResponseAuthentication .*$/ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config \
 && sed -Ei -e 's/#?[[:space:]]*PasswordAuthentication .*$/PasswordAuthentication no/g' /etc/ssh/sshd_config

EXPOSE 2022

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/sbin/entrypoint.sh"]
