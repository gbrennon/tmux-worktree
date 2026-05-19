#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read the user-customizable key binding (default: W)
# Set this in your tmux.conf with: set -g @worktree-key "T"
WORKTREE_KEY="$(tmux show-option -gv @worktree-key 2>/dev/null)"
WORKTREE_KEY="${WORKTREE_KEY:-W}"

# Cleanup key (default: C-W). Set via @worktree-cleanup-key in tmux.conf.
CLEANUP_KEY="$(tmux show-option -gv @worktree-cleanup-key 2>/dev/null)"
CLEANUP_KEY="${CLEANUP_KEY:-C-$WORKTREE_KEY}"

# Main binding: opens fzf popup to select or create a worktree.
# Type to filter/complete existing directories, or enter a new branch name.
tmux bind-key -T prefix "$WORKTREE_KEY" if-shell "true" \
    "run-shell -b '$CURRENT_DIR/scripts/worktree-manager.sh' choose"

# Legacy binding (prefix + M-W): traditional command-prompt without fzf.
# Useful as a fallback or when fzf is not available.
WT_TEMPLATE="run-shell -b '$CURRENT_DIR/scripts/worktree-manager.sh' create-worktree '%%'"
tmux bind-key -T prefix "M-$WORKTREE_KEY" command-prompt -p "Worktree branch:" \
    "$WT_TEMPLATE"

# Cleanup binding (prefix + C-W): remove merged / stale worktrees.
tmux bind-key -T prefix "$CLEANUP_KEY" if-shell "true" \
    "run-shell -b '$CURRENT_DIR/scripts/worktree-manager.sh' cleanup"
