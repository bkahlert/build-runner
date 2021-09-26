#!/bin/sh
docker buildx create --name custom
docker buildx use custom
docker buildx build \
  --build-arg AUTHORIZED_KEYS="$(curl -LfsS https://github.com/bkahlert/bkahlert/raw/main/id_rsa.pub)" \
  --push \
  --platform linux/arm64 \
  --tag bkahlert/build-agent:dind \
  --progress plain \
  .
