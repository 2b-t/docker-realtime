#!/usr/bin/env bats
# Unit-tests for Bash output library
# Tobit Flatscher - github.com/2b-t (2022)
#
# Usage:
# - '$ ./test_lib_output.bats'


function setup() {
  load "test_helper/bats-support/load"
  load "test_helper/bats-assert/load"
  local DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" >/dev/null 2>&1 && pwd )"
  local TEST_FILE="${DIR}/../src/lib_output.sh"
  source "${TEST_FILE}"
}

@test "Test error_msg" {
  declare desc="Test if error message contains the desired string"
  run error_msg "error"
  assert_output --partial "error"
}

@test "Test warning_msg" {
  declare desc="Test if warning message contains the desired string"
  run warning_msg "warning"
  assert_output --partial "warning"
}

@test "Test info_msg" {
  declare desc="Test if info message contains the desired string"
  run info_msg "info"
  assert_output --partial "info"
}

@test "Test success_msg" {
  declare desc="Test if success message contains the desired string"
  run success_msg "success"
  assert_output --partial "success"
}

