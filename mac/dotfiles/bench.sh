#!/bin/bash

# shellcheck disable=SC2120
timezsh() {
  shell=${1-$SHELL}
  # shellcheck disable=SC2034
  # shellcheck disable=SC2086
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}
timezsh
