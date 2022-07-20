#!/bin/bash
# Bash library containing different output utility functions
# Tobit Flatscher - github.com/2b-t (2022)


function _msg() {
  declare desc="Output text in colour to the console"
  local COLOUR=$1
  local CLEAR="\033[0m"
  printf "${COLOUR}%s${CLEAR} \\n" "${*:2}" 1>&2
}

function error_msg() {
  declare desc="Output errors in red to the console"
  local RED="\033[0;31m"
  _msg ${RED} ${*}
}

function warning_msg() {
  declare desc="Output warnings in yellow to the console"
  local YELLOW="\033[1;33m"
  _msg ${YELLOW} ${*}
}

function info_msg() {
  declare desc="Output information in white to the console"
  local WHITE="\033[1;37m"
  _msg ${WHITE} ${*}
}

function success_msg() {
  declare desc="Output success in green to the console"
  local GREEN="\033[0;32m"
  _msg ${GREEN} ${*}
}

