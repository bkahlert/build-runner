#!/usr/bin/env bats

@test "should run services by default" {
  local output
  image --env DEBUG=1 -d "$BUILD_TAG"
  assert_within 10s -- assert_container_log "$output" --partial "starting services"
}

@test "should run specified command if specified" {
  image "$BUILD_TAG" printf "foo"
  assert_line "foo"
}
