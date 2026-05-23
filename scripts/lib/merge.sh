is_merged() {
    local wt_dir="$1" branch="$2" default_branch="$3" auto_fetch="$4"
    # Fast local check only — relies on a reasonably up-to-date origin/<branch> ref.
    # Run 'git fetch origin <branch>' manually or let the background fetch in
    # cleanup_worktrees keep it fresh.  No network calls here so the fzf popup
    # appears instantly regardless of how many worktrees exist.
    if git -C "$wt_dir" merge-base --is-ancestor HEAD "origin/$default_branch" 2>/dev/null; then
        return 0
    fi
    return 1
}
