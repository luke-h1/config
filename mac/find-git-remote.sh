#!/bin/bash

find_git_remotes() {
  local dir="$1"
  for d in "$dir"/*; do
    if [ -d "$d" ]; then
      if [ -d "$d/.git" ]; then
        remote_url=$(git -C "$d" remote get-url origin)
        echo "Repository found in: $d"
        echo "Remote URL: $remote_url"
        REMOTE_URLS+=("$remote_url")
      else
        find_git_remotes "$d"
      fi
    fi
  done
}

REMOTE_URLS=()

find_git_remotes "$(pwd)"

echo "All remote URLs:"
for url in "${REMOTE_URLS[@]}"; do
  echo "$url"
done
