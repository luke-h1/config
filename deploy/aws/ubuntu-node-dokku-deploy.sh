#!/bin/bash

sudo apt update
sudo apt install -y apt-transport-https

wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | sudo apt-key add -

OS_ID="$(lsb_release -cs 2>/dev/null || echo "bionic")"

echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ ${OS_ID} main" | sudo tee /etc/apt/sources.list.d/dokku.list

sudo apt update -y

wget -nv -O - https://get.docker.com/ | sudo bash -

sudo apt update

sudo apt install dokku -y

dokku apps:create api
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git
dokku postgres:create db
dokku postgres:link db api
sudo dokku plugin:install https://github.com/dokku/dokku-redis.git
sudo dokku redis:create redis
dokku redis:link redis api
dokku plugin:install https://github.com/dokku/dokku-letsencrypt
dokku config:set --no-restart api DOKKU_LETSENCRYPT_EMAIL=your@email.com
sudo su -
hostnamectl set-hostname dev
sudo su - ubuntu
dokku domains:remove-global dev
dokku domains:remove api dev
sudo dokku domains:report
sudo dokku domains:add api api.domain.name
dokku proxy:ports-add api http:80:4010
echo "Sleeping for 30 seconds to give you time to update DNS config"
dokku letsencrypt:enable api
echo "enabled lets encrypt"
