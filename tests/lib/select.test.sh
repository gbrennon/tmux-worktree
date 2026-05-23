test_select_sources_cleanly() {
    local funcs
    funcs=$(declare -F | awk '{print $3}' | grep -E '^fzf_')
    local count
    count=$(echo "$funcs" | wc -l)
    assert_eq "2" "$count" "should define 2 fzf functions"
}

test_select_functions_exist() {
    assert_true type fzf_select_worktree >/dev/null 2>&1
    assert_true type fzf_cleanup_picker >/dev/null 2>&1
}

test_cleanup_no_worktrees_shows_popup_not_error() {
    local repo exit_code
    repo=$(setup_temp_repo)

    # Run the cleanup in a bash -c subshell so 'exit' inside cleanup_worktrees
    # only exits the subshell, not the test runner.  We nest cleanup_worktrees
    # in another subshell so the 'exit 0' doesn't kill our bash -c before we
    # can report success.
    exit_code=0
    cd "$repo" && bash -c '
        fzf-tmux() { echo "No worktrees found in .worktrees/ — press Enter to dismiss"; }
        export -f fzf-tmux

        tmux() {
            case "$1" in
                show-option) echo "false" ;;
                *) : ;;
            esac
        }
        export -f tmux

        DIR="'"$PROJECT_DIR"'/scripts"
        source "$DIR/lib/repo.sh"
        source "$DIR/lib/worktree.sh"
        source "$DIR/lib/merge.sh"
        source "$DIR/lib/tmux.sh"
        source "$DIR/lib/select.sh"
        source "$DIR/worktree-manager.sh"

        mkdir -p .worktrees
        git config init.defaultBranch main

        # Extra subshell: cleanup_worktrees calls exit 0 which kills only
        # the inner ( ... ) and control returns here.
        ( cleanup_worktrees )
        echo "OK"
    ' 2>/dev/null || exit_code=$?

    teardown_temp_repo "$repo"
    assert_eq "0" "$exit_code" "cleanup with no worktrees should succeed"
}
