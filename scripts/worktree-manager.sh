#!/bin/bash

show_error() {
    local msg="$1"
    printf '%s\n' "$msg" >&2
    local tmpfile
    tmpfile=$(mktemp)
    printf '%s\n' "$msg" > "$tmpfile"
    tmux display-popup -E -h 20 \
        "cat '$tmpfile'; echo; echo 'Press any key or wait 10s...'; read -t 10 -n1 2>/dev/null || true; rm -f '$tmpfile'" 2>/dev/null || \
        tmux display-message -d 5000 "tmux-worktrees: $msg" 2>/dev/null || true
}

find_repo_root() {
    local dir
    dir=$(tmux show-environment -g MAIN_PROJECT_PATH 2>/dev/null | cut -d= -f2)
    if [[ -n "$dir" ]]; then
        echo "$dir"
        return 0
    fi
    dir="$(tmux display-message -p '#{pane_current_path}')"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    if [[ -d "/.git" ]]; then
        echo "/"
        return 0
    fi
    return 1
}

create_or_resume() {
    local branch="$1" repo_root worktrees_dir target target_abs
    if [[ -z "$branch" ]]; then
        show_error "Branch name cannot be empty — type a name (e.g. feat/foo) or select an existing worktree"
        exit 0
    fi
    repo_root=$(find_repo_root) || {
        show_error "Not in a git repository — no .git directory found when walking up from:\n\n  $(pwd)\n\nChecked all parent directories up to /."
        exit 0
    }
    cd "$repo_root" || { show_error "Cannot cd to $repo_root"; exit 0; }
    worktrees_dir=".worktrees"
    if [[ ! -d "$worktrees_dir" ]]; then
        mkdir "$worktrees_dir"
        if [[ -f ".git/info/exclude" ]]; then
            grep -qxF "$worktrees_dir/" .git/info/exclude 2>/dev/null ||
                echo "$worktrees_dir/" >> .git/info/exclude
        fi
    fi
    target="$worktrees_dir/$(echo "$branch" | tr '/' '-')"
    if [[ ! -d "$target" ]]; then
        local default_branch output
        if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            default_branch="main"
        elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            default_branch="master"
        else
            show_error "Neither main nor master branch found in:\n\n  $repo_root\n\nExisting branches:\n$(git branch 2>/dev/null | head -10)"
            exit 0
        fi
        output=$(git worktree add "$target" -b "$branch" "$default_branch" 2>&1) || {
            show_error "Worktree creation failed:\n\n$output"
            exit 0
        }
    fi
    if command -v realpath &>/dev/null; then
        target_abs="$(realpath "$target")"
    else
        target_abs="$(cd "$target" && pwd)"
    fi
    local command
    command=$(tmux show-option -gv @worktree-command 2>/dev/null)
    # When run via tmux run-shell, $SHELL may be /bin/sh.
    # Prefer the login shell from passwd as a more reliable default.
    if [[ -z "$command" ]]; then
        command=$(getent passwd "$(id -u)" | cut -d: -f7 2>/dev/null)
        command="${command:-$SHELL}"
        command="${command:-/bin/bash}"
    fi
    if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -Fxq "wt-$branch"; then
        tmux select-window -t "wt-$branch"
        tmux display-message "Resumed worktree: $branch"
    else
        tmux new-window -n "wt-$branch" -c "$target_abs" "$command"
        tmux display-message "Created worktree: $branch"
    fi
}

select_worktree() {
    local repo_root worktrees_dir existing result branch
    exec 3>&2 2>/dev/null
    repo_root=$(find_repo_root) || {
        show_error "Not in a git repository — no .git directory found when walking up from:\n\n  $(pwd)\n\nChecked all parent directories up to /."
        exit 0
    }
    cd "$repo_root" || { show_error "Cannot cd to $repo_root"; exit 0; }
    worktrees_dir=".worktrees"
    existing=$(find "$worktrees_dir" -mindepth 2 -name '.git' -type f \
        -printf '%P\n' 2>/dev/null | sed 's|/\.git$||' | sort)
    if [[ -z "$existing" ]]; then
        existing=$'\n'
    fi
    exec 2>&3 3>&-
    result=$(echo "$existing" | fzf-tmux -p 60%,40% \
        --prompt="Worktree> " \
        --print-query \
        --header="Type to filter, Enter to select/create" \
        2>/dev/null) || true
    branch=$(echo "$result" | tail -1)
    if [[ -z "$branch" ]]; then
        branch=$(echo "$result" | head -1)
    fi
    [[ -z "$branch" ]] && exit 0
    # Resolve real git branch name if selection is an existing worktree dir
    if [[ -d "$worktrees_dir/$branch" ]]; then
        local resolved
        resolved=$(git -C "$worktrees_dir/$branch" rev-parse --abbrev-ref HEAD 2>/dev/null)
        [[ -n "$resolved" ]] && branch="$resolved"
    fi
    create_or_resume "$branch"
}

cleanup_worktrees() {
    local repo_root worktrees_dir default_branch result branch wt_dir
    repo_root=$(find_repo_root) || {
        show_error "Not in a git repository — no .git directory found when walking up from:\n\n  $(pwd)\n\nChecked all parent directories up to /."
        exit 0
    }
    cd "$repo_root" || { show_error "Cannot cd to $repo_root"; exit 0; }
    worktrees_dir=".worktrees"
    default_branch=$(git config --global init.defaultBranch 2>/dev/null)
    if [[ -z "$default_branch" ]]; then
        default_branch=$(git config init.defaultBranch 2>/dev/null)
    fi
    if [[ -z "$default_branch" ]]; then
        default_branch=$(git branch --show-current 2>/dev/null)
    fi
    if [[ -z "$default_branch" ]]; then
        default_branch="main"
    fi
    local auto_fetch
    auto_fetch=$(tmux show-option -gv @worktree-auto-fetch 2>/dev/null)
    auto_fetch="${auto_fetch:-true}"
    if [[ "$auto_fetch" != "false" ]]; then
        git fetch origin "$default_branch" --no-tags --depth=1 2>/dev/null || true
    fi
    local fzf_input=""
    while IFS= read -r wt_dir; do
        branch=$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
        local merged=false
        if git -C "$wt_dir" merge-base --is-ancestor HEAD "origin/$default_branch" 2>/dev/null; then
            merged=true
        elif [[ "$auto_fetch" != "false" ]] && \
             ! git ls-remote --exit-code origin "refs/heads/$branch" 2>/dev/null; then
            merged=true
        fi
        if [[ "$merged" == "true" ]]; then
            fzf_input+="✓ merged  | $branch"$'\t'"$wt_dir"$'\n'
        else
            fzf_input+="✗ active  | $branch"$'\t'"$wt_dir"$'\n'
        fi
    done < <(find "$worktrees_dir" -mindepth 2 -name '.git' -type f -printf '%h\n' 2>/dev/null)
    if [[ -z "$fzf_input" ]]; then
        show_error "No worktrees found in $worktrees_dir/"
        exit 0
    fi
    result=$(echo "$fzf_input" | fzf-tmux -p 60%,40% \
        --prompt="Remove worktree> " \
        --header="Enter to remove selected worktree" \
        2>/dev/null) || exit 0
    branch=$(echo "$result" | cut -f1 | sed 's/^.*| *//')
    [[ -z "$branch" ]] && exit 0
    wt_dir=$(echo "$result" | cut -f2)
    local target="$wt_dir"
    if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -Fxq "wt-$branch"; then
        tmux kill-window -t "wt-$branch"
    fi
    local output
    output=$(git worktree remove "$target" 2>&1) || {
        show_error "Worktree removal failed:\n\n$output"
        exit 0
    }
    output=$(git branch -D "$branch" 2>&1) || true
    tmux display-message "Removed worktree: $branch"
}

case "${1:-}" in
    "")        select_worktree ;;
    create-worktree) create_or_resume "${2:-}" ;;
    choose)    select_worktree ;;
    cleanup)   cleanup_worktrees ;;
    *)         show_error "Unknown command: $1"; exit 0 ;;
esac
