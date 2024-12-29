#!/bin/bash

# shellcheck disable=SC2006
# shellcheck disable=SC2046
# shellcheck disable=SC2009
sudo kill -9 $(ps aux | grep 'coreaudiod[a-z]' | awk '{print $1}')
