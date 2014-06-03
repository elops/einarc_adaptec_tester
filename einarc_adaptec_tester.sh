#!/bin/bash

# vim settings 
# set ai ts=2 sts=2 et sw=2 expandtab

# collect following information
# - logical list
#   /var/lib/einarc/tools/adaptec_arcconf/cli getconfig "$controller_num" ld
# - physical list
#   /var/lib/einarc/tools/adaptec_arcconf/cli getconfig "$controller_num" pd
# - adapter info
#   /var/lib/einarc/tools/adaptec_arcconf/cli getconfig "$controller_num" ad
# - bbu info
#   /var/lib/einarc/tools/adaptec_arcconf/cli getconfig "$controller_num" ad
# - query (all information)
#   /var/lib/einarc/tools/adaptec_arcconf/cli getconfig "$controller_num" al

name='adaptec_test_suite_collector'
cli_binary='/var/lib/einarc/tools/adaptec_arcconf/cli'
lock_dir='/tmp/'"$name"

_exit() {
  local rc="$?"
  trap - EXIT
  if [ ! -z "$1" ]; then
    echo "ERROR : $1" 1>&2
  fi

  # remove lock and tmp stuff
  rm -rf "$tmp_dir" || echo "Couldn't remove dir : $tmp_dir" 1>&2
  rmdir "$lock_dir" || echo "Couldn't remove dir : $lock_dir" 1>&2
  exit "$rc"
}

_err() {
  local rc="$?"
  local err_line="$1"
  echo -e "Failed executing :\n$BASH_COMMAND\nat line @$err_line"
  exit "$rc"
}

generic_test() {
  out_dir="${tmp_dir}/controller_${controller_num}/${test_no}_${command/\ /_}"
  mkdir -p "$out_dir"

  echo "$command" > "$out_dir"/command.txt
  echo "$args" > "$out_dir"/cli_input_1.txt
  eval "$cli_binary" "$args" > "$out_dir"/cli_output_1.txt
}

test_query() {
  test_no="01"
  command="query"
  args="getconfig $controller_num al"
  generic_test
}

test_adapter_info() {
  test_no="02"
  command="adapter info"
  args="getconfig $controller_num ad"
  generic_test
}

test_physical_list() { 
  test_no="10"
  command="physical list"
  args="getconfig $controller_num pd"
  generic_test
}

test_logical_list() { 
  test_no="20"
  command="logical list"
  args="getconfig $controller_num ld"
  generic_test
}

test_bbu_info() { 
  test_no="90"
  command="bbu info"
  args="getconfig $controller_num ad"
  generic_test
}


if [ -e "$lock_dir" ]; then
   echo 'Lock dir detected; possible duplicate script running; exiting' 1>&2
   exit 1
else
  trap _exit EXIT
  trap '_err $LINENO' ERR
  set -o errtrace
  mkdir -p "$lock_dir"
fi

tmp_dir=$(mktemp -d /tmp/adaptect_test.XXXXX)
umask 0077

# first of all check if we have adaptec controller...
if ! lspci | egrep -q 'RAID.*Adaptec'; then
  echo "No adaptec controller found"
  exit
else
  lspci | egrep 'RAID.*Adaptec' > "$tmp_dir"/lspci_info
fi

# make sure we have adaptec cli binary in place
if [ ! -x "$cli_binary" ]; then
  echo "Missing adaptec CLI on $(hostname)"
  exit 1
fi
  
# check and count controller count
if [[ $("$cli_binary" getversion 2>&1 ) =~ Controllers\ found:\ ([[:digit:]]) ]]; then
  controller_count="${BASH_REMATCH[1]}"
else
  _exit "Coudln't find any controllers, exiting..."
fi

# run tests for all controllers
for controller_num in $(seq 1 "$controller_count")
do
  test_query
  test_adapter_info
  test_physical_list
  test_logical_list
  test_bbu_info
done

test_name=$(basename "$tmp_dir")
if [ ! -f /tmp/"$test_name" ]; then
  cd /tmp
  tar czf "$test_name".tgz "$test_name"/
  readlink -f /tmp/"$test_name".tgz
else
  _exit "Archive exists, skipping archiving..."
fi
