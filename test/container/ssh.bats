#!/usr/bin/env bats
# bashsupport disable=BP5007

setup() {
  load 'helpers/setup.sh' "$BUILD_TAG?unspecified image to test}"
}

teardown() {
  docker rm --force "$BATS_TEST_NAME" >/dev/null 2>&1 || true
  if [ -e data ] && ! rm -rf data; then
    echo "Failed to delete data. Try the following command to resolve this issue:"
    echo "docker run --rm -v '$PWD:/work' ubuntu bash -c 'chmod -R +w /work/data; rm -rf /work/data'"
    exit 1
  fi
  if [ -e disk.img ] && ! rm -f disk.img; then
    echo "Failed to delete data. Try the following command to resolve this issue:"
    echo "docker run --rm -v '$PWD:/work' ubuntu bash -c 'chmod -R +w /work/disk.img; rm -rf /work/disk.img'"
    exit 1
  fi
}

run_ssh() {
  cp_fixture test_id_rsa test_id_rsa && chmod 0600 test_id_rsa
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial '✔ waiting for sshd'

  run ssh \
    -i test_id_rsa \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    "$@"
}


@test "should have ssh daemon correctly configured" {
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial 'running as service'
  run docker exec "$container" cat /etc/ssh/sshd_config

  assert_line 'Port 2022'
  assert_line 'ChallengeResponseAuthentication no'
  assert_line 'PasswordAuthentication no'
}

@test "should refuse password auth" {
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial 'running as service'

  run sshpass -p "runner" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id
  assert_line --partial 'Permission denied (public''key)'
}

@test "should accept public key" {
  run_ssh id
  assert_output --regexp 'uid=.* gid=.* groups=.*'
}

@test "should enable password if specified" {
  local password_args=('-e' 'AUTHORIZED_KEYS=' '-e' 'PASSWORD=password1234')
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "${password_args[@]}" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial 'running as service'
  run docker exec "$container" cat /etc/ssh/sshd_config

  assert_line 'ChallengeResponseAuthentication yes'
  assert_line 'PasswordAuthentication yes'
}

@test "should accept password if enabled" {
  local password_args=('-e' 'AUTHORIZED_KEYS=' '-e' 'PASSWORD=password1234')
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "${password_args[@]}" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial 'running as service'

  run sshpass -p "password1234" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id
  assert_line --partial 'USER=runner'
}

@test "should refuse public key if password is enabled" {
  local password_args=('-e' 'AUTHORIZED_KEYS=' '-e' 'PASSWORD=password1234')
  local container && container=$(docker run -d --name "$BATS_TEST_NAME" "${password_args[@]}" "$BUILD_TAG")
  assert_within 10s -- assert_container_log "$container" --partial 'running as service'

  cp_fixture test_id_rsa test_id_rsa && chmod 0600 test_id_rsa

  ssh \
    -i test_id_rsa \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o BatchMode=yes \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id
  assert_line --partial 'Permission denied'
}
