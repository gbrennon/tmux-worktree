#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux bind-key W command-prompt -p "Worktree branch:" \
    "run-shell -b \"$CURRENT_DIR/scripts/worktree.sh create-worktree '%%'\""
