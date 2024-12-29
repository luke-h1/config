#!/bin/bash
# shellcheck disable=SC2046
docker system prune -a && docker image prune && docker rmi $(docker images -a -q) && docker rm $(docker ps -a -f status=exited -q) && docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q) && docker volume prune
