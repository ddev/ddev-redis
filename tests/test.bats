TEST_BREW_PREFIX="$(brew --prefix)"
load "${TEST_BREW_PREFIX}/lib/bats-support/load.bash"
load "${TEST_BREW_PREFIX}/lib/bats-assert/load.bash"

setup() {
  set -eu -o pipefail

  export ADDON_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export PROJECT=testproj
  export TEST_DIR="$HOME/tmp/$PROJECT"
  export DDEV_NON_INTERACTIVE=true

  mkdir -p $TEST_DIR && cd "$TEST_DIR" || ( printf "unable to cd to $TEST_DIR\n" && exit 1 )

  ddev delete -Oy $PROJECT >/dev/null 2>&1 || true
  ddev config --project-name=$PROJECT --omit-containers=db --disable-upload-dirs-warning
}

health_checks() {
  set +u # bats-assert has unset variables so turn off unset check

  # get the addon
  run bash -c "ddev get $1"
  assert_success

  # start the project
  run bash -c "ddev start -y"
  assert_success

  # check that redis is running
  run bash -c "DDEV_DEBUG=true ddev redis --version"
  assert_success
  assert_output --partial "redis-cli"

  # key count should be 0
  run bash -c 'ddev redis "KEYS \*"'
  assert_success
  assert_output ""

  # populate 10000 keys
  echo '' > keys.txt
  run bash -c 'for i in {1..10000}; do echo "SET testkey-$i $i" >> keys.txt; done'
  run bash -c "cat keys.txt | ddev redis --pipe"
  assert_success
  assert_line --index 2 "errors: 0, replies: 10000"

  # Trigger a BGSAVE
  run ddev redis BGSAVE
  assert_success
  assert_output "Background saving started"

  sleep 10

  # Stop the project
  run bash -c "ddev stop"
  assert_success

  # start the project (again)
  run bash -c "ddev start -y"
  assert_success

  # Check the key count
  run bash -c "ddev redis DBSIZE"
  assert_success
  assert_output "10000"
}

teardown() {
  set -eu -o pipefail
  cd "$TEST_DIR" || ( printf "unable to cd to $TEST_DIR\n" && exit 1 )
  ddev stop
  ddev delete -Oy "$PROJECT" >/dev/null 2>&1
  [ "$TEST_DIR" != "" ] && rm -rf "$TEST_DIR"
}
# bats test_tags=local
@test "install from directory" {
  set -eu -o pipefail
  cd "$TEST_DIR"
  echo "# ddev get oblakstudio/ddev-redis with project "$PROJECT" in "$TEST_DIR"" >&3
  health_checks "$ADDON_DIR"
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd "$TEST_DIR" || ( printf "unable to cd to "$TEST_DIR"\n" && exit 1 )
  echo "# ddev get oblakstudio/ddev-redis with project "$PROJECT" in "$TEST_DIR"" >&3
  health_checks "oblakstudio/ddev-redis-7"
}

