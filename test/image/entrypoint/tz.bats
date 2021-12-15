#!/usr/bin/env bats

@test "should change timezone to UTC by default" {
  image "$BUILD_TAG" date +"%Z"
  assert_line --partial UTC
}

@test "should change timezone to specified timezone" {
  image -e "TZ=CEST" "$BUILD_TAG" date +"%Z"
  assert_line --partial CEST
}
