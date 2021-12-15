#!/usr/bin/env bats
# bashsupport disable=BP5007

@test "should provide Docker client" {
  image "$BUILD_TAG" docker --version
  assert_line --partial 'Docker version'
  assert_line --partial 'build'
}

@test "should pass-through socket" {
  image -v /var/run/docker.sock:/var/run/docker.sock "$BUILD_TAG" docker run --rm hello-world
  assert_line --partial 'Hello from Docker!'
}
