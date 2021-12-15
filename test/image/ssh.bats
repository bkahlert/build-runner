#!/usr/bin/env bats
# bashsupport disable=BP5007

@test "should have build time configured ssh daemon" {
  image "$BUILD_TAG" bash -c 'cat /etc/ssh/sshd_config'
  assert_line 'Port 2022'
  assert_line 'ChallengeResponseAuthentication no'
  assert_line 'PasswordAuthentication no'
}

@test "should refuse password authentication by default" {
  local output container
  image --env DEBUG=1 -d "$BUILD_TAG"
  container=$output
  assert_within 10s -- assert_container_log "$container" --partial "services started"

  run sshpass -p "runner" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id

  assert_line --partial 'Permission denied (public''key)'
}

@test "should accept public key if specified" {
  local output container
  copy_fixture test_id_rsa.pub test_id_rsa.pub
  copy_fixture test_id_rsa test_id_rsa && chmod 0600 test_id_rsa
  image --env DEBUG=1 --env AUTHORIZED_KEYS="$(cat test_id_rsa.pub)" -d "$BUILD_TAG"
  container=$output
  assert_within 10s -- assert_container_log "$container" --partial "sshd is running"

  run ssh \
    -i test_id_rsa \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id

  assert_output --regexp "uid=.* gid=.* groups=.*"
}

@test "should enable password if specified" {
  local output container
  image --env DEBUG=1 --env AUTHORIZED_KEYS="" --env PASSWORD="password1234" -d "$BUILD_TAG"
  container=$output
  assert_within 10s -- assert_container_log "$container" --partial "services started"
  run docker exec "$container" cat /etc/ssh/sshd_config

  assert_line "ChallengeResponseAuthentication yes"
  assert_line "PasswordAuthentication yes"
}

@test "should accept password if enabled" {
  local output container
  image --env DEBUG=1 --env AUTHORIZED_KEYS="" --env PASSWORD="password1234" -d "$BUILD_TAG"
  container=$output
  assert_within 10s -- assert_container_log "$container" --partial "services started"

  run sshpass -p "password1234" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id
  assert_line --partial "USER=runner"
}

@test "should refuse public key if password is enabled" {
  local output container
  image --env DEBUG=1 --env AUTHORIZED_KEYS="" --env PASSWORD="password1234" -d "$BUILD_TAG"
  container=$output
  assert_within 10s -- assert_container_log "$container" --partial "services started"

  copy_fixture test_id_rsa test_id_rsa && chmod 0600 test_id_rsa

  run ssh \
    -i test_id_rsa \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o BatchMode=yes \
    -p 2022 \
    "runner@$(container_ip "$container")" \
    id
  assert_line --partial "Permission denied"
}
