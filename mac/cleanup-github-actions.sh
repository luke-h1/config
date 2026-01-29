#!/bin/bash
#
# GitHub Actions Runner Cleanup Script for macOS
#
# This script removes the LaunchAgent and related files created by setup-github-actions.sh
#
# Usage:
#   ./cleanup-github-actions.sh
#   ./cleanup-github-actions.sh --all    # Also removes runner directory and env files
#   ./cleanup-github-actions.sh --help

set -e

LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.github.actions.runner.plist"
RUNNER_START_SCRIPT="$HOME/start-runner.sh"
RUNNER_ENV_FILE="$HOME/.github-actions-runner.env"
RUNNER_DIR="$HOME/actions-runner"

REMOVE_ALL=false

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  echo "Usage: $0 [--all]"
  echo ""
  echo "Options:"
  echo "  --all    Also remove runner directory and environment files"
  echo "  --help   Show this help message"
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  REMOVE_ALL=true
fi

log() {
  echo "--> $*"
}

logn() {
  printf -- "--> %s " "$*"
}

logk() {
  echo "OK"
}

log "🧹 Cleaning up GitHub Actions Runner setup"

logn "Checking if LaunchAgent is loaded:"
if launchctl list | grep -q "com.github.actions.runner"; then
  logk
  logn "Unloading LaunchAgent:"
  launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
  logk
else
  logk
  log "LaunchAgent is not loaded"
fi

logn "Removing LaunchAgent plist:"
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
  rm -f "$LAUNCH_AGENT_PLIST"
  logk
else
  logk
  log "LaunchAgent plist not found (already removed)"
fi

logn "Removing start script:"
if [ -f "$RUNNER_START_SCRIPT" ]; then
  rm -f "$RUNNER_START_SCRIPT"
  logk
else
  logk
  log "Start script not found (already removed)"
fi

if [ "$REMOVE_ALL" = true ]; then
  logn "Removing environment file:"
  if [ -f "$RUNNER_ENV_FILE" ]; then
    rm -f "$RUNNER_ENV_FILE"
    logk
  else
    logk
    log "Environment file not found (already removed)"
  fi
  
  logn "Removing runner directory:"
  if [ -d "$RUNNER_DIR" ]; then
    read -p "Are you sure you want to remove $RUNNER_DIR? This will delete all runner files. (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$RUNNER_DIR"
      logk
    else
      log "Skipped removing runner directory"
    fi
  else
    logk
    log "Runner directory not found (already removed)"
  fi
else
  log ""
  log "Note: To also remove the runner directory and environment files, run:"
  log "  $0 --all"
fi

log ""
log "✅ Cleanup complete!"
log ""
log "Remaining files (if any):"
if [ -f "$RUNNER_ENV_FILE" ]; then
  log "  - $RUNNER_ENV_FILE"
fi
if [ -d "$RUNNER_DIR" ]; then
  log "  - $RUNNER_DIR"
fi

if [ ! -f "$RUNNER_ENV_FILE" ] && [ ! -d "$RUNNER_DIR" ]; then
  log "  (none)"
fi

