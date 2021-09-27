FROM docker:20.10.8-alpine3.14

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000

RUN apk --no-cache --update add \
    bash \
    ca-certificates \
    curl \
    git \
    openjdk11 \
    shadow \
    sshpass

ENV JAVA_HOME=/usr/lib/jvm/default-jvm/jre

ARG AUTHORIZED_KEYS=''
RUN groupadd \
    --gid $PGID \
    runner \
 && useradd \
    --uid $PUID \
    --gid runner \
    --shell /bin/bash \
    --home-dir /home/runner \
    runner \
 && mkdir -p /home/runner/.ssh \
 && chmod 0700 /home/runner/.ssh \
 && echo "$AUTHORIZED_KEYS" > /home/runner/.ssh/authorized_keys \
 && echo "export JAVA_HOME=$JAVA_HOME" >> /home/runner/.profile \
 && chown -R runner:runner /home/runner \
 && apk --no-cache --update add openssh-server rsync \
 && ssh-keygen -A \
 && sed -Ei -e 's/#?[[:space:]]*Port .*$/Port 2022/g' /etc/ssh/sshd_config \
 && sed -Ei -e 's/#?[[:space:]]*ChallengeResponseAuthentication .*$/ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config \
 && sed -Ei -e 's/#?[[:space:]]*PasswordAuthentication .*$/PasswordAuthentication no/g' /etc/ssh/sshd_config \
 && if [ -z "${AUTHORIZED_KEYS}" ]; then \
      sed -Ei -e 's/#?[[:space:]]*ChallengeResponseAuthentication .*$/ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config && \
      sed -Ei -e 's/#?[[:space:]]*PasswordAuthentication .*$/PasswordAuthentication no/g' /etc/ssh/sshd_config; \
    else \
      echo 'runner:runner' | chpasswd; \
    fi

EXPOSE 2022

ENTRYPOINT ["dockerd-entrypoint.sh"]
CMD ["/usr/sbin/sshd","-D","-e"]
