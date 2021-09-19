FROM ubuntu:20.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
            ca-certificates \
            openssh-client \
            wget \
            curl \
            iptables \
            supervisor \
 && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL='stable' \
    DOCKER_VERSION='18.06.3-ce' \
    DOCKER_COMPOSE_VERSION='1.29.2' \
    DEBUG=false

# Docker
RUN set -eux; \
  \
  arch="$(uname -m)"; \
  case "$arch" in \
    # amd64
    x86_64) dockerArch='x86_64' ;; \
    # arm32v6
    armhf) dockerArch='armel' ;; \
    # arm32v7
    armv7|armv7l) dockerArch='armhf' ;; \
    # arm64v8
    aarch64) dockerArch='aarch64' ;; \
    # ppc64le
    ppc64le) dockerArch='ppc64le' ;; \
    # s390x
    s390x) dockerArch='s390x' ;; \
    *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
  esac; \
  \
  if ! curl -LfsSo docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
    echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
    exit 1; \
  fi; \
  \
  tar --extract \
      --file docker.tgz \
      --strip-components 1 \
      --directory /usr/local/bin/ \
  ; \
  rm docker.tgz; \
  \
  dockerd --version; \
  docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker


# Docker Compose
RUN set -eux; \
  \
  arch="$(uname -m)"; \
  case "$arch" in \
    x86_64) curl -LfsSo /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
         && chmod +x /usr/local/bin/docker-compose ;; \
    armhf|armv7|armv7l|aarch64) apt-get update \
                      && DEBIAN_FRONTEND=noninteractive \
                         apt-get install -y \
                                 build-essential \
                                 libssl-dev \
                                 libffi-dev \
                                 python3-dev \
                                 python3-pip \
                      && rm -rf /var/lib/apt/list/*  \
                      && python3 -m pip install -IU docker-compose ;; \
    ppc64le) dockerArch='ppc64le' ;; \
    s390x) dockerArch='s390x' ;; \
    *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
  esac; \
  \
  if [ "$(which docker-compose)" ]; then \
    docker-compose --version; \
  fi


# Java
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8' \
    JAVA_VERSION='jdk-11.0.11+9'

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            tzdata \
            curl \
            ca-certificates \
            fontconfig \
            locales \
 && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
 && locale-gen en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         ESUM='4966b0df9406b7041e14316e04c9579806832fafa02c5d3bd1842163b7f2353a'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.11_9.tar.gz'; \
         ;; \
       armhf|armv7l) \
         ESUM='2d7aba0b9ea287145ad437d4b3035fc84f7508e78c6fec99be4ff59fe1b6fc0d'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_arm_linux_hotspot_11.0.11_9.tar.gz'; \
         ;; \
       ppc64el|ppc64le) \
         ESUM='945b114bd0a617d742653ac1ae89d35384bf89389046a44681109cf8e4f4af91'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_ppc64le_linux_hotspot_11.0.11_9.tar.gz'; \
         ;; \
       s390x) \
         ESUM='5d81979d27d9d8b3ed5bca1a91fc899cbbfb3d907f445ee7329628105e92f52c'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_s390x_linux_hotspot_11.0.11_9.tar.gz'; \
         ;; \
       amd64|x86_64) \
         ESUM='e99b98f851541202ab64401594901e583b764e368814320eba442095251e78cb'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.11_9.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
    echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/java/openjdk; \
    cd /opt/java/openjdk; \
    tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
    rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"


# SSH
ARG AUTHORIZED_KEYS=''
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            openssh-server \
            sudo \
            rsync \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/#\{0,1\}Port.*$/Port 2022/' /etc/ssh/sshd_config \
 && chmod 775 /var/run \
 && mkdir /var/run/sshd \
 && rm -f /var/run/nologin \
 && useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 ubuntu \
 && if [ -z "${AUTHORIZED_KEYS}" ]; then \
      sed -i \
          -e 's/#\{0,1\}ChallengeResponseAuthentication.*$/ChallengeResponseAuthentication no/' \
          -e 's/#\{0,1\}PasswordAuthentication.*$/PasswordAuthentication no/' \
          /etc/ssh/sshd_config; \
    else \
      echo 'ubuntu:ubuntu' | chpasswd; \
    fi

RUN mkdir -p /home/ubuntu/.ssh \
 && chmod 0700 /home/ubuntu/.ssh \
 && chown ubuntu /home/ubuntu/.ssh \
 && echo "$AUTHORIZED_KEYS" > /home/ubuntu/.ssh/authorized_keys \
 && chmod 600 /home/ubuntu/.ssh/authorized_keys \
 && chown ubuntu /home/ubuntu/.ssh/authorized_keys

RUN echo "export JAVA_HOME=$JAVA_HOME" >> /home/ubuntu/.profile \
 && echo "export PATH=$PATH" >> /home/ubuntu/.profile

EXPOSE 2022

ENTRYPOINT ["startup.sh"]
CMD ["/usr/sbin/sshd","-D"]
