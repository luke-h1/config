#!/bin/bash

REPOS=(
  "https://github.com/luke-h1/lhowsam.com"
  "https://github.com/luke-h1/foam"
  "https://github.com/luke-h1/pets-api"
  "https://github.com/luke-h1/terraform-modules"
  "https://github.com/luke-h1/config"
  "https://github.com/luke-h1/terraform-modules"
  "https://github.com/luke-h1/bookmarks"
  "https://github.com/luke-h1/twitch-chat-poc"
  "https://github.com/luke-h1/lho-lambda"
  "https://github.com/luke-h1/branches"
  "https://github.com/luke-h1/app-runner-poc"
  "https://github.com/luke-h1/coolblue-tech-assignment"
  "https://github.com/luke-h1/storify"
  "https://github.com/luke-h1/fe-talk-2024"
  "https://github.com/dfe-analytical-services/explore-education-statistics"
  "https://github.com/infinitered/ignite"
)

for repo in "${REPOS[@]}"; do
  echo "Cloning $repo..."
  git clone "$repo"
done

echo "All repositories cloned"
