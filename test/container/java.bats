#!/usr/bin/env bats
# bashsupport disable=BP5007

setup() {
  load 'helpers/setup.sh' "$BUILD_TAG?unspecified image to test}"
}

teardown() {
  docker rm --force "$BATS_TEST_NAME" >/dev/null 2>&1 || true
}

@test "should provide Java" {
  run docker run --name "$BATS_TEST_NAME" "$BUILD_TAG" java --version
  assert_line --partial 'openjdk 11'
}

@test "should have JAVA_HOME set" {
  run docker run --name "$BATS_TEST_NAME" "$BUILD_TAG" bash -l -c 'printenv'
  assert_line 'JAVA_HOME=/usr/lib/jvm/default-jvm/jre'
}
