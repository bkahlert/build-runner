#!/usr/bin/env bats
# bashsupport disable=BP5007

@test "should persist APP_USER and APP_GROUP in entrypoint.sh" {
  image "$BUILD_TAG" bash -c 'cat /usr/local/sbin/entrypoint.sh'
  assert_line '  local -r app_user=runner app_group=runner'
}

@test "should change user ID to 1000 by default" {
  IMAGE_PUID='' image "$BUILD_TAG" id
  assert_line --partial "uid=1000"
}

@test "should change group ID to 1000 by default" {
  IMAGE_PGID='' image "$BUILD_TAG" id
  assert_line --partial "gid=1000"
}

@test "should change user ID to specified ID" {
  IMAGE_PUID="echo 2000" image "$BUILD_TAG" id
  assert_line --partial "uid=2000"
}

@test "should change group ID to specified ID" {
  IMAGE_PGID="echo 2000" image "$BUILD_TAG" id
  assert_line --partial "gid=2000"
}
