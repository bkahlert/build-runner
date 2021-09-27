#!/usr/bin/env bats
# bashsupport disable=BP5007

setup() {
  load 'helpers/setup.sh' "${BUILD_TAG:?unspecified image to test}"
}

teardown() {
  docker rm --force "${BATS_TEST_NAME}" >/dev/null 2>&1 || true
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
  local -r -i port=$(( 1024 + RANDOM % 49151 ))

  cp_fixture test_id_rsa id_rsa

  run docker run -d --name "${BATS_TEST_NAME}" -p "$port":2022 "${BUILD_TAG}"

  # shellcheck disable=SC2154
  local -r ID="${output}"
  assert_within 30 "run docker logs ""${ID}"" && assert_line --partial 'dockerd is running'"

  run ssh \
    -i id_rsa \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -p "$port" \
    runner@host.docker.internal \
    "$@"
}

@test "should have SSHD correctly configured" {

  run docker run -i --name "${BATS_TEST_NAME}" \
    --entrypoint bash "${BUILD_TAG}" \
    -c 'cat /etc/ssh/sshd_config'

  assert_line 'Port 2022'
  assert_line 'ChallengeResponseAuthentication no'
  assert_line 'PasswordAuthentication no'
}

@test "should start docker daemon" {

  run docker run -d --name "${BATS_TEST_NAME}" "${BUILD_TAG}"
  assert_output --regexp '^\w{32,}$'

  # shellcheck disable=SC2154
  local -r ID="${output}"
  assert_container_status "${BATS_TEST_NAME}" 'running'
  assert_within 30 "run docker logs ""${ID}"" && assert_line --partial 'dockerd is running'"
  sleep 5
  assert_container_status "${BATS_TEST_NAME}" 'running'
}

@test "should refuse password auth" {

  run docker run -d --name "${BATS_TEST_NAME}" -p 42022:2022 "${BUILD_TAG}"

  # shellcheck disable=SC2154
  local -r ID="${output}"
  assert_within 30 "run docker logs ""${ID}"" && assert_line --partial 'dockerd is running'"

  run sshpass -p "runner" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -p 42022 \
    runner@host.docker.internal id
  assert_line --partial 'Permission denied (publickey)'
}

@test "should accept public key" {

  run_ssh id

  assert_output --regexp 'uid=.* gid=.* groups=.*'
}


@test "should provide Java" {

  run_ssh java --version

  assert_line --partial 'openjdk 11'
}


@test "should have JAVA_HOME set" {

  run_ssh "ls \$JAVA_HOME"

  assert_line --partial 'bin'
  assert_line --partial 'jre'
}


@test "should provide Docker" {

  run_ssh docker run --rm hello-world

  assert_line 'Hello from Docker!'
}
