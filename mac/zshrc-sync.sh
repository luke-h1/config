#!/usr/bin/env bash
# Diff/sync ~/.zshrc with config repo at ~/srv/dev/config
# Run from anywhere: zshrc-sync.sh [diff|sync|pull]  (default: diff)

set -e
CONFIG_REPO="$HOME/srv/dev/config"
REPO_ZSHRC="$CONFIG_REPO/mac/dotfiles/.zshrc"
LOCAL_ZSHRC="$HOME/.zshrc"

cmd="${1:-diff}"

case "$cmd" in
  diff)
    if [[ ! -f "$REPO_ZSHRC" ]]; then
      echo "Repo file missing: $REPO_ZSHRC"
      exit 1
    fi
    if [[ ! -f "$LOCAL_ZSHRC" ]]; then
      echo "Local file missing: $LOCAL_ZSHRC"
      exit 1
    fi
    diff -u "$LOCAL_ZSHRC" "$REPO_ZSHRC" || true
    ;;
  sync)
    [[ -f "$REPO_ZSHRC" ]] || { echo "Repo file missing: $REPO_ZSHRC"; exit 1; }
    if [[ -f "$LOCAL_ZSHRC" ]]; then
      backup="$LOCAL_ZSHRC.bak.$(date +%Y%m%d-%H%M%S)"
      cp "$LOCAL_ZSHRC" "$backup"
      echo "Backed up to $backup"
    fi
    cp "$REPO_ZSHRC" "$LOCAL_ZSHRC"
    echo "Synced repo -> $LOCAL_ZSHRC"
    ;;
  pull)
    cp "$LOCAL_ZSHRC" "$REPO_ZSHRC"
    echo "Copied $LOCAL_ZSHRC -> repo"
    ;;
  *)
    echo "Usage: $0 [diff|sync|pull]"
    echo "  (no arg) diff  - show diff: ~/.zshrc vs $CONFIG_REPO"
    echo "  sync  - overwrite ~/.zshrc with repo (backup first)"
    echo "  pull  - overwrite repo with current ~/.zshrc"
    exit 1
    ;;
esac
