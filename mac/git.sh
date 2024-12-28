#!/bin/bash

REPOS=(
  "https://github.com/luke-h1/lhowsam.com"
  "https://github.com/luke-h1/foam"
  "https://github.com/luke-h1/pets-api"
  "https://github.com/luke-h1/terraform-modules"
  "https://github.com/dfe-analytical-services/explore-education-statistics"
  "https://github.com/luke-h1/terraform-modules"
  "https://github.com/luke-h1/branches"
  "https://github.com/infinitered/ignite"
)

for repo in "${REPOS[@]}"; do
  echo "Cloning $repo..."
  git clone "$repo"
done

echo "All repositories cloned"
