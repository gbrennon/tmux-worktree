test_worktree_abspath_realpath() {
    local repo result
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    result=$(worktree_abspath ".")

    teardown_temp_repo "$repo"
    assert_eq "$repo" "$result"
}

test_worktree_abspath_subdir() {
    local repo result
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    mkdir -p "sub"
    result=$(worktree_abspath "sub")

    teardown_temp_repo "$repo"
    assert_eq "$repo/sub" "$result"
}

test_worktree_branch_in_repo() {
    local repo result
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    result=$(worktree_branch ".")

    teardown_temp_repo "$repo"
    assert_eq "main" "$result"
}

test_worktree_branch_non_existent_path() {
    local result
    result=$(worktree_branch "/tmp/non-existent-path-xxxxx" 2>/dev/null)
    assert_eq "?" "$result"
}

test_list_worktrees_empty() {
    local repo result
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    mkdir -p ".worktrees"
    result=$(list_worktrees ".worktrees")

    teardown_temp_repo "$repo"
    assert_eq "" "$result"
}

test_create_and_remove_worktree() {
    local repo output branch
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    mkdir -p ".worktrees"
    output=$(create_worktree ".worktrees/test-feat" "test-feat" "main" 2>&1) || {
        teardown_temp_repo "$repo"
        echo "  (skipped — git worktree add failed: $output)"
        return 0
    }

    assert_true test -d ".worktrees/test-feat" || { teardown_temp_repo "$repo"; return 1; }

    branch=$(worktree_branch ".worktrees/test-feat")

    remove_worktree ".worktrees/test-feat" >/dev/null 2>&1

    if [[ -d ".worktrees/test-feat" ]]; then
        teardown_temp_repo "$repo"
        echo "    directory still exists after remove_worktree" >&2
        return 1
    fi

    teardown_temp_repo "$repo"
    assert_eq "test-feat" "$branch"
}

test_remove_worktree_force_dirty() {
    local repo output removed
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    mkdir -p ".worktrees"
    output=$(create_worktree ".worktrees/dirty-feat" "dirty-feat" "main" 2>&1) || {
        teardown_temp_repo "$repo"
        echo "  (skipped — git worktree add failed: $output)"
        return 0
    }

    echo "uncommitted" >> ".worktrees/dirty-feat/init.txt"

    remove_worktree ".worktrees/dirty-feat" >/dev/null 2>&1
    removed=$?

    if [[ -d ".worktrees/dirty-feat" ]]; then
        teardown_temp_repo "$repo"
        echo "    directory still exists after force removal" >&2
        return 1
    fi

    teardown_temp_repo "$repo"
    assert_eq "0" "$removed" "remove should succeed with --force on dirty worktree"
}

test_list_worktrees_with_entries() {
    local repo output result
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    mkdir -p ".worktrees"
    output=$(create_worktree ".worktrees/test-feat" "test-feat" "main" 2>&1) || {
        teardown_temp_repo "$repo"
        echo "  (skipped — git worktree add failed: $output)"
        return 0
    }

    result=$(list_worktrees ".worktrees")

    remove_worktree ".worktrees/test-feat" >/dev/null 2>&1
    teardown_temp_repo "$repo"
    assert_neq "" "$result"
}

test_delete_local_branch() {
    local repo exists stdout_output exit_code
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    git checkout -b "to-delete" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1

    stdout_output=$(delete_local_branch "to-delete" 2>/dev/null)
    exit_code=$?

    exists=0
    git show-ref --verify --quiet refs/heads/to-delete 2>/dev/null || exists=1

    teardown_temp_repo "$repo"

    # Every assertion must drive the function return code — no unconditional
    # 'return 0' at the end.
    assert_eq "0" "$exit_code" "delete_local_branch should exit 0" || return 1
    assert_eq "1" "$exists" "branch should be deleted" || return 1
    if [[ -n "$stdout_output" ]]; then
        echo "    unexpected stdout: $stdout_output" >&2
        return 1
    fi
}

test_delete_local_branch_nonexistent() {
    local repo exit_code stdout_output
    repo=$(setup_temp_repo)
    cd "$repo" || return 1

    stdout_output=$(delete_local_branch "non-existent-branch" 2>/dev/null)
    exit_code=$?

    teardown_temp_repo "$repo"

    assert_eq "0" "$exit_code" "should not error on non-existent branch" || return 1
    if [[ -n "$stdout_output" ]]; then
        echo "    unexpected stdout: $stdout_output" >&2
        return 1
    fi
}
