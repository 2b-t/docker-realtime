#!/usr/bin/env bats
# Unit-tests for Bash library for installing PREEMPT_RT Linux kernel from a Debian package
# Tobit Flatscher - github.com/2b-t (2022)
#
# Usage:
# - '$ ./test_lib_install_debian.bats'


function test_file() {
  local DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" >/dev/null 2>&1 && pwd )"
  echo "${DIR}/../src/lib_install_debian.sh"
}

function setup() {
  load "test_helper/bats-support/load"
  load "test_helper/bats-assert/load"
  local TEST_FILE=$(test_file)
  source ${TEST_FILE}
}

@test "Test get_debian_versions" {
  declare desc="Test if valid Debian version is detected"
  local DEBIAN_VERSIONS=$(get_debian_versions)
  assert_not_equal "${DEBIAN_VERSIONS}" ""
  assert_regex "${DEBIAN_VERSIONS}" "^([a-z]( )?)+$"
}

@test "Test get_preemptrt_file" {
  declare desc="Test if a valid Debian file is returned for the given Debian version"
  local DEBIAN_VERSION="bullseye"
  local PREEMPTRT_FILE=$(get_preemptrt_file "${DEBIAN_VERSION}")
  assert_regex "${PREEMPTRT_FILE}" "^(linux-image-rt-).+(\.deb)$"
}

@test "Test select_debian_version" {
  declare desc="Test if select Debian version dialog returns a single option only"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_debian_version) >/tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local DEBIAN_VERSION=$(</tmp/capture)
  assert_regex "${DEBIAN_VERSION}" "^([a-z])+$"
}

@test "Test get_download_locations" {
  declare desc="Test if a valid hyperlink is returned for the given Debian version"
  local DEBIAN_VERSION="bullseye"
  local DOWNLOAD_LOCATION=$(get_download_locations "${DEBIAN_VERSION}")
  assert_regex "${DOWNLOAD_LOCATION}" "^(http://).+(\.deb)$"
}

@test "Test select_download_location" {
  declare desc="Test if select download location dialog returns a single option only"
  local DEBIAN_VERSION="bullseye"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_download_location '"${DEBIAN_VERSION})"' >/tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local DOWNLOAD_LOCATION=$(</tmp/capture)
  assert_regex "${DOWNLOAD_LOCATION}" "^(http://).+(\.deb)$"
}

@test "Test extract_filename" {
  declare desc="Test if filename is extracted correctly from hyperlink"
  local DOWNLOAD_LOCATION="http://ftp.us.debian.org/debian/pool/main/l/linux-signed-amd64/linux-image-rt-amd64_5.10.127-1_amd64.deb"
  local DOWNLOADED_FILE=$(extract_filename "${DOWNLOAD_LOCATION}")
  assert_regex "${DOWNLOADED_FILE}" "^(linux-image-rt-).+(\.deb)$"
}

