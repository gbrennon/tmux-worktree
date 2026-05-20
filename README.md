# tmux-worktrees

A tmux plugin that lets you create, switch between, and clean up
[git worktrees][git-worktree] without ever leaving tmux session.

**Demo**: press `prefix + W`, pick (or type) a branch name, and you're in a
fresh tmux window pointing at that worktree.

Done with a branch?  `prefix + D` lets you remove its worktree in one keystroke.

---

## Getting Started

This section walks you through installing the plugin, understanding the
key bindings, and using them day-to-day.  No prior knowledge of git worktrees
is assumed — we'll explain the concepts as we go.

### What problem does this solve?

You're working on `feature-a` when someone asks you to hotfix `main`.  Without
worktrees you'd have to stash, commit a WIP, or clone the repo a second time.
With git worktrees, each branch lives in its own directory so you can have
`feature-a` and `main` checked out _at the same time_ — no stashing, no
context-switching pain.

**tmux-worktrees** makes this workflow frictionless inside tmux.  A single
keybinding opens an interactive picker; choosing a branch name creates the
worktree (if it doesn't exist yet) and opens a new tmux window pointing at it.

---

### 1. Install it

tmux-worktrees is installed like any other [TPM][tpm] plugin.  Add this line
to your `~/.tmux.conf`:

```tmux
set -g @plugin 'gbrennon/tmux-worktrees'
```

Then reload your tmux config with `prefix + I` (capital `i`), or restart tmux.

**One dependency** — the plugin uses [`fzf`][fzf] for its interactive menus.
Make sure `fzf` is installed and available on your `$PATH`:

```bash
# Fedora based
sudo dnf install fzf

# Debian based
sudo apt install fzf

# Arch based
sudo pacman -S fzf

# macOS(brew required)
brew install fzf

```

---

### 2. The two keybindings

Once installed, you get two new prefix-key bindings:

| Keys            | What it does                                          |
|-----------------|-------------------------------------------------------|
| `prefix` + `W`  | Open the worktree picker — create or switch to one    |
| `prefix` + `D`  | Open the cleanup menu — remove merged/stale worktrees |

> `prefix` is `Ctrl-b` by default (the key you press before any tmux command).
> If you've remapped your prefix to something else (e.g. `Ctrl-a`), substitute
> that instead.

---

### 3. Create your first worktree

1. Inside tmux, `cd` into **any** git repository.
2. Press `prefix` + `W`.
3. An fzf popup appears.  Start typing a branch name — for example `feat/awesome-feature`.
4. Press `Enter`.

If the branch doesn't exist yet, tmux-worktrees will:

- Create a worktree at `.worktrees/feat-awesome-feature` inside your repo
  (slashes in branch names are replaced with dashes for the directory),
  branching off `main` (or `master`, whichever exists).
- Open a new tmux window named `wt-feat/awesome-feature` with your shell's
  working directory already set to that worktree.

If the worktree already exists, the same keybinding switches you to its tmux
window — so `prefix + W` doubles as a fast project-wide window switcher.

---

### 4. Switch between worktrees

Press `prefix` + `W` again.  This time the fzf picker lists every worktree
you've created so far.  Use the arrow keys (or keep typing to filter) and hit
`Enter`.  You'll jump straight to that worktree's tmux window.

Think of `prefix + W` as a "project dashboard" — one keystroke to see every
active branch and jump to any of them.

---

### 5. Clean up when you're done

When a branch is merged (or you simply don't need it anymore), press
`prefix` + `D`.  The popup shows all your worktrees, each prefixed with:

- **✓ merged** — the branch has been merged into `main`/`master` and is safe
  to delete.
- **✗ active** — the branch still has unmerged commits; the plugin won't stop
  you from removing it, but the mark helps you decide.

Select one with `Enter` and the worktree, its tmux window, and the local git
branch are all removed in one shot.

---

### 6. Customise the keys (optional)

Don't like `W` and `D`?  Set your own keys in `~/.tmux.conf` **before** the
plugin line:

```tmux
set -g @worktree-key 't'           # prefix + T to pick a worktree
set -g @worktree-cleanup-key 'x'   # prefix + X to clean up
```

### 7. Customise the shell (optional)

When a new tmux window opens, the plugin launches your login shell by default.
If you'd prefer a different command (e.g. `nvim` or `fish`), set:

```tmux
set -g @worktree-command 'fish'
```

---

## How it works (under the hood)

1. **Repo discovery** — the script walks up from the active pane's current
   directory until it finds a `.git` folder.  That becomes the repo root.
2. **Worktree storage** — all worktrees live in a `.worktrees/` directory at
   the repo root.  The plugin adds `.worktrees/` to `.git/info/exclude`
   automatically so git never sees them as untracked files.
3. **Window naming** — each worktree gets a tmux window named
   `wt-<branch-name>`.  The plugin checks for an existing window with that
   name before creating a new one, so you never end up with duplicates.
4. **Cleanup safety** — the removal flow kills the tmux window first, then
   runs `git worktree remove` followed by `git branch -D`, so nothing is
   left dangling.

---

## Requirements

| Thing   | Minimum version / notes                  |
|---------|------------------------------------------|
| tmux    | 2.4+ (uses `display-popup` internally)   |
| git     | 2.5+ (when `git worktree` was added)     |
| fzf     | Any recent version with `fzf-tmux`       |
| bash    | 4.0+ (used by the scripts)               |

---

## License

MIT

[git-worktree]: https://git-scm.com/docs/git-worktree
[tpm]: https://github.com/tmux-plugins/tpm
[fzf]: https://github.com/junegunn/fzf
