#!/bin/bash

# Prevent any script output from leaking to the terminal (tmux run-shell capture).
# All user-visible output goes through show_error() which uses display-popup.
exec 2>/dev/null

# Show a multi-line error in a tmux popup that stays visible until the user
# presses Escape.  The message is written to a temp file so that newlines and
# special characters are preserved safely (no quoting issues).
show_error() {
    local client tmpfile
    client=$(tmux display-message -p '#{client_name}' 2>/dev/null)

    if [[ -n "$client" ]]; then
        tmpfile=$(mktemp)
        printf '%s\n' "$1" > "$tmpfile"
        tmux display-popup -c "$client" -h 20 \
            "cat '$tmpfile'; echo; echo 'Press Escape to dismiss'; rm -f '$tmpfile'"
    else
        tmux display-message "Error: $1"
    fi
}

if [[ "${1:-}" == "create-worktree" ]]; then
    BRANCH="${2:-}"

    if [[ -z "$BRANCH" ]]; then
        show_error "Branch name cannot be empty"
        exit 1
    fi

    MAIN_PROJECT=$(tmux show-environment -g MAIN_PROJECT_PATH 2>/dev/null | cut -d= -f2)

    if [[ -z "$MAIN_PROJECT" ]]; then
        MAIN_PROJECT="$(tmux display-message -p '#{pane_current_path}')"
    fi

    cd "$MAIN_PROJECT" || { show_error "Cannot cd to $MAIN_PROJECT"; exit 1; }

    if ! git rev-parse --git-dir &>/dev/null; then
        show_error "Not in a git repository"
        exit 1
    fi

    WORKTREES_DIR=".worktrees"
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        mkdir "$WORKTREES_DIR"
        if [[ -f ".git/info/exclude" ]]; then
            echo "$WORKTREES_DIR/" >> .git/info/exclude
        fi
    fi

    TARGET="$WORKTREES_DIR/$BRANCH"

    if [[ ! -d "$TARGET" ]]; then
        # Detect default branch
        if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            DEFAULT_BRANCH="main"
        elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            DEFAULT_BRANCH="master"
        else
            show_error "Neither 'main' nor 'master' branch found"
            exit 1
        fi

        OUTPUT=$(git worktree add "$TARGET" -b "$BRANCH" "$DEFAULT_BRANCH" 2>&1) || {
            show_error "Worktree creation failed:\n\n$OUTPUT"
            exit 1
        }
    fi

    if command -v realpath &>/dev/null; then
        TARGET_ABS="$(realpath "$TARGET")"
    else
        TARGET_ABS="$(cd "$TARGET" && pwd)"
    fi

    if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -Fxq "wt-$BRANCH"; then
        tmux select-window -t "wt-$BRANCH"
        tmux display-message "Resumed worktree: $BRANCH"
    else
        tmux new-window -n "wt-$BRANCH" -c "$TARGET_ABS" "nvim"
        tmux display-message "Created worktree: $BRANCH"
    fi
fi
