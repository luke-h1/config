#!/bin/bash
echo What should the version be ?
# shellcheck disable=SC2162
read VERSION
echo Enter IP address
# shellcheck disable=SC2162
read TARGET
echo Enter user 
# shellcheck disable=SC2162
read USER 

echo "Deploying to production 🚀 🔥"

# shellcheck disable=SC2086
docker build -t lhowsam/<API_NAME>:$VERSION .
# shellcheck disable=SC2086
docker push lhowsam/<DOCKER_IMAGE>:$VERSION
# shellcheck disable=SC2086
ssh ${USER}@${TARGET} -i /Users/lukehowsam/aws/*.cer "sudo docker pull lhowsam/<DOCKER_IMAGE>:$VERSION && sudo docker tag lhowsam/<DOCKER_IMAGE>:$VERSION dokku/<API_NAME>:$VERSION && dokku deploy <API_NAME> $VERSION"
