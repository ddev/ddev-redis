#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# To run specific test:
#   bats ./tests/test.bats --filter-tags 'laravel-redis'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=ddev/ddev-redis

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success

  # The default image from docker-compose.redis.yaml, e.g. "redis:8"
  export DEFAULT_REDIS_DOCKER_IMAGE=$(grep -m1 -oE 'REDIS_DOCKER_IMAGE:-[^}]+' "${DIR}/docker-compose.redis.yaml" | cut -d- -f2-)
  export DEFAULT_REDIS_MAJOR_VERSION=$(echo "${DEFAULT_REDIS_DOCKER_IMAGE}" | grep -oE ':[0-9]+' | tr -d :)
  export HAS_DRUPAL_SETTINGS=false
  export HAS_OPTIMIZED_CONFIG=false
  export RUN_BGSAVE=false
  export CHECK_REDIS_READ_WRITE=false
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

# Usage: install_add_on [source]
# source defaults to the add-on directory, use "${GITHUB_REPO}" for the latest release
install_add_on() {
  local source="${1:-${DIR}}"

  run ddev start -y
  assert_success

  echo "# ddev add-on get ${source} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${source}"
  assert_success
}

# Enables the optimized config, must be called before install_add_on
use_optimized_config() {
  export HAS_OPTIMIZED_CONFIG=true

  run ddev dotenv set .ddev/.env.redis --redis-optimized=true
  assert_success
  assert_file_exist .ddev/.env.redis
}

# Pins the Docker image, must be called before install_add_on
use_redis_image() {
  run ddev dotenv set .ddev/.env.redis --redis-docker-image="$1"
  assert_success
}

# Usage: use_redis_backend <image|alias> [optimized]
use_redis_backend() {
  if [ "${2:-}" = "optimized" ]; then
    export HAS_OPTIMIZED_CONFIG=true
  fi

  run ddev redis-backend "$@"
  assert_success
}

# Creates a Laravel project that uses Redis for the cache, with routes to read/write it
setup_laravel() {
  export CHECK_REDIS_READ_WRITE=true

  run ddev config --project-type=laravel --docroot=public
  assert_success

  run ddev composer create laravel/laravel
  assert_success

  run ddev dotenv set .env --cache-store=redis --redis-host=redis
  assert_success

  cat <<'EOF' >routes/web.php
<?php
use Illuminate\Support\Facades\Route;
Route::get('/set/{key}/{value}', function ($key, $value) {
    cache()->set($key, $value);
    echo $value;
});
Route::get('/get/{key}', function ($key) {
    echo cache()->get($key);
});
EOF
  assert_file_exist routes/web.php
}

# Usage: assert_redis_version [server] [major_version]
# server is "redis" or "valkey" (Valkey always reports "redis_version:7.2.4" for compatibility)
assert_redis_version() {
  local server="${1:-redis}"
  local major_version="${2:-${DEFAULT_REDIS_MAJOR_VERSION}}"

  run ddev redis-cli INFO server
  assert_success
  assert_output --regexp "${server}_version:${major_version}\."
}

# Usage: health_checks [server] [major_version]
# Restarts the project and checks that Redis works, see assert_redis_version for arguments
health_checks() {
  run ddev restart -y
  assert_success

  assert_redis_version "$@"

  if [ "${HAS_DRUPAL_SETTINGS}" = "true" ]; then
    assert_file_exist web/sites/default/settings.ddev.redis.php

    run grep -F "settings.ddev.redis.php" web/sites/default/settings.php
    assert_success
  else
    assert_file_not_exist web/sites/default/settings.ddev.redis.php
  fi

  assert_file_exist .ddev/redis/redis.conf

  redis_optimized_files=(
    .ddev/docker-compose.redis_extra.yaml
    .ddev/redis/advanced.conf
    .ddev/redis/append.conf
    .ddev/redis/general.conf
    .ddev/redis/io.conf
    .ddev/redis/memory.conf
    .ddev/redis/network.conf
    .ddev/redis/security.conf
    .ddev/redis/snapshots.conf
  )

  if [ "$HAS_OPTIMIZED_CONFIG" = "true" ]; then
    for file in "${redis_optimized_files[@]}"; do
      assert_file_exist "$file"
    done

    run grep -F "${PROJNAME}" .ddev/redis/snapshots.conf
    assert_output "dbfilename ${PROJNAME}.rdb"

    run ddev describe
    assert_success
    assert_output --partial "Backend:"
    assert_output --partial "User: redis"
    assert_output --partial "Pass: redis"
  else
    for file in "${redis_optimized_files[@]}"; do
      assert_file_not_exist "$file"
    done

    run ddev describe
    assert_success
    assert_output --partial "Backend:"
    assert_output --partial "Pass: <none>"
  fi

  run ddev redis-cli "KEYS \*"
  assert_success
  assert_output ""

  # populate 10000 keys
  echo '' > keys.txt
  run bash -c 'for i in {1..10000}; do echo "SET testkey-$i $i" >> keys.txt; done'
  assert_success
  run bash -c "cat keys.txt | ddev redis --pipe"
  assert_success
  assert_line --index 2 "errors: 0, replies: 10000"

  # check if Redis really works with read/write from the app
  if [ "${CHECK_REDIS_READ_WRITE}" = "true" ]; then
    if [ "${HAS_OPTIMIZED_CONFIG}" = "true" ]; then
      run ddev dotenv set .env --redis-password=redis
      assert_success
    fi

    run curl -sf https://${PROJNAME}.ddev.site/set/foo/bar
    assert_success
    assert_output "bar"

    run curl -sf https://${PROJNAME}.ddev.site/set/test/value
    assert_success
    assert_output "value"

    run curl -sf https://${PROJNAME}.ddev.site/get/foo
    assert_success
    assert_output "bar"

    run curl -sf https://${PROJNAME}.ddev.site/get/test
    assert_success
    assert_output "value"

    # double-check the value to make sure nothing has been deleted
    run curl -sf https://${PROJNAME}.ddev.site/get/foo
    assert_success
    assert_output "bar"

    run curl -sf https://${PROJNAME}.ddev.site/get/test
    assert_success
    assert_output "value"

    run ddev redis-flush
    assert_success
    assert_output "OK"

    # after flushing, nothing should be here
    run curl -sf https://${PROJNAME}.ddev.site/get/foo
    assert_success
    assert_output ""

    run curl -sf https://${PROJNAME}.ddev.site/get/test
    assert_success
    assert_output ""
  fi

  if [ "${RUN_BGSAVE}" != "true" ]; then
    return
  fi

  # Trigger a BGSAVE
  run ddev redis BGSAVE
  assert_success
  assert_output "Background saving started"

  sleep 10

  run ddev stop
  assert_success

  run ddev start -y
  assert_success

  run ddev redis DBSIZE
  assert_success
  assert_output "10000"

  run ddev redis-flush
  assert_success
  assert_output "OK"

  run ddev redis DBSIZE
  assert_success
  assert_output "0"
}

# Saves the current data, switches to the default image the way an add-on update does
# for projects without .env.redis, and checks that the data is still there
upgrade_to_default_image() {
  run ddev redis-cli DBSIZE
  assert_success
  local keys="${output}"

  run ddev redis-cli SAVE
  assert_success
  assert_output "OK"

  rm -f .ddev/.env.redis
  install_add_on

  run ddev restart -y
  assert_success

  assert_redis_version

  run ddev redis-cli DBSIZE
  assert_success
  assert_output "${keys}"
}

# bats test_tags=default
@test "install from directory" {
  set -eu -o pipefail
  export RUN_BGSAVE=true
  install_add_on
  health_checks
}

# bats test_tags=default
@test "install from directory with optimized config" {
  set -eu -o pipefail
  export RUN_BGSAVE=true
  use_optimized_config
  install_add_on
  health_checks
}

# bats test_tags=default
@test "upgrade from Redis 7 to the default image keeps data" {
  set -eu -o pipefail
  use_redis_image redis:7
  install_add_on
  health_checks redis 7
  upgrade_to_default_image
}

# bats test_tags=default
@test "ddev redis-backend fails with a non-existent image" {
  set -eu -o pipefail
  install_add_on

  run ddev redis-backend ddev/ddev-redis-non-existent-image:latest
  assert_failure
  assert_output --partial "Unable to pull ddev/ddev-redis-non-existent-image:latest"

  # Nothing is removed if the image can't be pulled
  assert_file_exist .ddev/docker-compose.redis.yaml
  assert_file_exist .ddev/redis/redis.conf
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  export RUN_BGSAVE=true
  install_add_on "${GITHUB_REPO}"
  # The released version may have a different default image
  health_checks redis "[0-9]+"
}

# bats test_tags=release
@test "install from release with optimized config" {
  set -eu -o pipefail
  export RUN_BGSAVE=true
  use_optimized_config
  install_add_on "${GITHUB_REPO}"
  # The released version may have a different default image
  health_checks redis "[0-9]+"
}

# bats test_tags=drupal
@test "Drupal installation" {
  set -eu -o pipefail
  export HAS_DRUPAL_SETTINGS=true
  run ddev config --project-type=drupal --docroot=web
  assert_success
  install_add_on
  health_checks
}

# bats test_tags=drupal
@test "Drupal 7 installation" {
  set -eu -o pipefail
  # Drupal configuration should not be present in Drupal 7
  export HAS_DRUPAL_SETTINGS=false
  run ddev config --project-type=drupal7 --docroot=web
  assert_success
  install_add_on
  health_checks
}

# bats test_tags=drupal
@test "Drupal installation without settings management" {
  set -eu -o pipefail
  export HAS_DRUPAL_SETTINGS=false
  run ddev config --disable-settings-management --project-type=drupal --docroot=web
  assert_success
  install_add_on
  health_checks
}

# bats test_tags=laravel-redis
@test "Laravel installation: ddev redis-backend redis" {
  set -eu -o pipefail
  setup_laravel
  install_add_on
  use_redis_backend redis
  # The default image is not pinned in .env.redis
  assert_file_not_exist .ddev/.env.redis
  health_checks
}

# bats test_tags=laravel-redis
@test "Laravel installation: ddev redis-backend redis-alpine optimized" {
  set -eu -o pipefail
  setup_laravel
  install_add_on
  use_redis_backend redis-alpine optimized
  health_checks
}

# bats test_tags=laravel-redis
@test "Laravel installation: ddev redis-backend redis:7" {
  set -eu -o pipefail
  setup_laravel
  install_add_on
  use_redis_backend redis:7
  health_checks redis 7
}

# bats test_tags=laravel-valkey
@test "Laravel installation: ddev redis-backend valkey" {
  set -eu -o pipefail
  setup_laravel
  install_add_on
  use_redis_backend valkey
  health_checks valkey 9
}

# bats test_tags=laravel-valkey
@test "Laravel installation: ddev redis-backend valkey-alpine optimized" {
  set -eu -o pipefail
  setup_laravel
  install_add_on
  use_redis_backend valkey-alpine optimized
  health_checks valkey 9
}
