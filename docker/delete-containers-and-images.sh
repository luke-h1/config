#!/bin/bash
# shellcheck disable=SC2046
docker rm $(docker ps -a -q) && docker rmi -f $(docker images -a -q)
