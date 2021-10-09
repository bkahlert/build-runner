#!/usr/bin/env bats
# bashsupport disable=BP5007

setup() {
  load 'helpers/setup.sh' "$BUILD_TAG?unspecified image to test}"
}

teardown() {
  docker rm --force "$BATS_TEST_NAME" >/dev/null 2>&1 || true
}

@test "should provide Docker client" {
  run docker run --name "$BATS_TEST_NAME" "$BUILD_TAG" docker --version
  assert_line --partial 'Docker version'
  assert_line --partial 'build'
}

@test "should pass-through socket" {
  local docker_args=('-e' PUID="$(id -u)" -e PGID="$(id -g)" '-v' '/var/run/docker.sock:/var/run/docker.sock')
  run docker run --name "$BATS_TEST_NAME" "${docker_args[@]}" "$BUILD_TAG" docker run --rm hello-world
  assert_line 'Hello from Docker!'
}
