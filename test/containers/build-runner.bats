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

  sshpass -p "ubuntu" ssh -p 42202 -o StrictHostKeyChecking=no ubuntu@host.docker.internal id
  refute_output --regexp 'uid=.* gid=.* groups=.*'
}

@test "should accept public key" {
  cp_fixture test_id_rsa id_rsa

  run docker run -d --name "${BATS_TEST_NAME}" -p 52022:2022 "${BUILD_TAG}"

  # shellcheck disable=SC2154
  local -r ID="${output}"
  assert_within 30 "run docker logs ""${ID}"" && assert_line --partial 'dockerd is running'"

  ssh -i id_rsa -p 52202 host.docker.internal id
  sleep 300
  assert_output --regexp 'uid=.* gid=.* groups=.*'
}
