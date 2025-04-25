#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
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
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success

  export REDIS_MAJOR_VERSION=7
  export HAS_DRUPAL_SETTINGS=false
  export HAS_OPTIMIZED_CONFIG=false
  export RUN_BGSAVE=false
}

health_checks() {
  run ddev redis-cli INFO
  assert_success
  assert_output --partial "redis_version:$REDIS_MAJOR_VERSION."

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
  else
    for file in "${redis_optimized_files[@]}"; do
      assert_file_not_exist "$file"
    done
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

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail

  export RUN_BGSAVE=true

  run ddev start -y
  assert_success

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  run ddev start -y
  assert_success

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=optimized
@test "install from directory with optimized config" {
  set -eu -o pipefail

  export HAS_OPTIMIZED_CONFIG=true
  export RUN_BGSAVE=true

  run ddev start -y
  assert_success

  run ddev dotenv set .ddev/.env.redis --redis-optimized=true
  assert_success
  assert_file_exist .ddev/.env.redis

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

@test "Drupal installation" {
  set -eu -o pipefail

  export HAS_DRUPAL_SETTINGS=true

  run ddev config --project-type=drupal --docroot=web
  assert_success
  run ddev start -y
  assert_success

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

@test "Laravel installation with redis:6" {
  set -eu -o pipefail

  export REDIS_MAJOR_VERSION=6

  run ddev config --project-type=laravel --docroot=web
  assert_success
  run ddev start -y
  assert_success

  run ddev dotenv set .ddev/.env.redis --redis-docker-image=redis:${REDIS_MAJOR_VERSION}
  assert_success
  assert_file_exist .ddev/.env.redis

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

@test "Drupal 7 installation" {
  set -eu -o pipefail

  # Drupal configuration should not be present in Drupal 7
  export HAS_DRUPAL_SETTINGS=false

  run ddev config --project-type=drupal7 --docroot=web
  assert_success
  run ddev start -y
  assert_success

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}

@test "Drupal installation without settings management" {
  set -eu -o pipefail

  export HAS_DRUPAL_SETTINGS=false

  run ddev config --disable-settings-management --project-type=drupal --docroot=web
  assert_success
  run ddev start -y
  assert_success

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success
  health_checks
}
