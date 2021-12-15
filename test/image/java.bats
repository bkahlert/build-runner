#!/usr/bin/env bats
# bashsupport disable=BP5007

@test "should provide Java" {
  image "$BUILD_TAG" java --version
  assert_line --partial 'openjdk 11'
}

@test "should have JAVA_HOME set" {
  image "$BUILD_TAG" bash -l -c 'printenv'
  assert_line 'JAVA_HOME=/usr/lib/jvm/default-jvm/jre'
}
