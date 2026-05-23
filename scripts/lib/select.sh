fzf_select_worktree() {
    local existing="$1"
    local header="${2:-Type to filter, Enter to select/create}"
    local result branch
    local noinfo=""
    [[ -z "$existing" ]] && noinfo="--no-info"
    exec 3>&2 2>/dev/null
    result=$(printf '%s\n' "$existing" | fzf-tmux -p 60%,40% \
        --prompt="Worktree> " \
        --print-query \
        --header="$header" \
        $noinfo \
        2>/dev/null) || true
    exec 2>&3 3>&-
    branch=$(echo "$result" | tail -1)
    if [[ -z "$branch" ]]; then
        branch=$(echo "$result" | head -1)
    fi
    echo "$branch"
}

fzf_cleanup_picker() {
    local input="$1"
    local noinfo="${2:-}"
    echo "$input" | fzf-tmux -p 60%,40% \
        --prompt="Remove worktree> " \
        --header="Enter to remove selected worktree" \
        $noinfo \
        2>/dev/null || true
}
