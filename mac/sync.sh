#!/bin/bash

# Create the sync.sh script
cat << 'EOF' > /Users/lukehowsam/srv/dev/config/mac/sync.sh
#!/bin/bash

REPO_DIR="/srv/dev"

for dir in "$REPO_DIR"/*; do
  if [ -d "$dir" ]; then
    if [ -d "$dir/.git" ]; then
      echo "Processing repository: $dir"
      cd "$dir" || continue

      current_branch=$(git rev-parse --abbrev-ref HEAD)

      if [ "$current_branch" == "main" ] || [ "$current_branch" == "master" ]; then
        echo "Pulling latest changes for branch: $current_branch"
        git pull origin "$current_branch"
      else
        echo "Skipping repository: $dir (current branch is $current_branch)"
      fi

      cd - > /dev/null || exit
    else
      echo "Skipping directory: $dir (not a Git repository)"
    fi
  fi
done
EOF

chmod +x /Users/lukehowsam/srv/dev/config/mac/sync.sh

# Add the sync.sh script to cron to run every day at 12:00 PM
(crontab -l 2>/dev/null; echo "0 12 * * * /Users/lukehowsam/srv/dev/config/mac/sync.sh >> /Users/lukehowsam/sync.log 2>&1") | crontab -
