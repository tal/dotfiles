# zoxide: init plus the worktrunk-aware `z`/`zi` wrappers.
#
# Sourced by ~/.zshrc's `~/.config/zsh/*.zsh` loop, which runs AFTER `compinit`.
# That ordering is load-bearing: a second `compinit` rebuilds the `_comps` map
# from scratch and silently erases every `compdef` registered before it, so
# initializing zoxide any earlier leaves `z` with no tab completion at all.
#
# Tab completion is whatever `zoxide init` registers (Space-Tab opens its fzf
# picker). There is deliberately no custom completer and no typeahead widget
# here — see changelog/2026-08-01_zoxide-tab-completion-and-case-insensitivity.md
# for what was tried and why each approach was removed.
eval "$(zoxide init zsh)"

# --- worktrunk integration: `z` always lands on the primary worktree --------
#
# worktrunk creates worktrees as `{{ repo }}.{{ branch | sanitize }}` beside the
# repo, so the database filled up with near-duplicates that outrank the repo
# itself (`z spotify-playlist` used to land in
# spotify-playlist.listen-limit-before-archiving, which scored 4.0 vs 0.8).
# Worktrees are reached with `wt switch`; `z` is strictly a repo-level jumper.

# Resolve a path to the equivalent path under its PRIMARY worktree. Sets $REPLY.
#
# Zero subprocesses, so it is safe on every chpwd and every ZLE redraw: a linked
# worktree's .git is a FILE containing "gitdir: <primary>/.git/worktrees/<name>",
# while a main worktree's .git is a DIRECTORY. Subpaths are preserved, so
# <repo>.<branch>/src maps to <repo>/src. Measured at ~0.065ms, vs ~8.4ms for
# `git rev-parse --git-common-dir`.
function __zoxide_primary() {
    local d=${1:-$PWD} rel='' gitdir main
    REPLY=${1:-$PWD}
    while [[ -n $d && $d != / ]]; do
        if [[ -f $d/.git ]]; then
            gitdir=$(<$d/.git)
            gitdir=${gitdir#gitdir: }
            gitdir=${gitdir%%$'\n'*}
            main=${gitdir%%/.git/worktrees/*}
            [[ $main == $gitdir ]] && return 0   # .git file, but not a worktree
            REPLY="${main}${rel}"
            return 0
        elif [[ -d $d/.git ]]; then
            return 0                              # already the primary worktree
        fi
        rel="/${d:t}${rel}"
        d=${d:h}
    done
    return 0
}

# Record the primary-equivalent path, so worktrees never enter the database and
# time spent in them accrues to the repo itself.
function __zoxide_hook() {
    local REPLY
    __zoxide_primary "$(__zoxide_pwd)"
    \command zoxide add -- "$REPLY"
}

# `z <keywords>` always lands on the primary worktree. Every other form zoxide
# handles natively (`z`, `z -`, `z +2`, `z <real-path>`, `z -- X`) is delegated
# untouched — otherwise `z -` would refuse to return to a worktree you just left.
function z() {
    local -i native=0
    if (( $# == 0 )); then
        native=1
    elif (( $# == 1 )) && [[ $1 == '-' ]]; then
        native=1
    elif (( $# == 1 )) && { [[ $1 =~ ^[-+][0-9]+$ ]] || ( \builtin cd -q -- "$1" ) &>/dev/null; }; then
        native=1
    elif (( $# == 2 )) && [[ $1 == '--' ]]; then
        native=1
    fi
    if (( native )); then
        __zoxide_z "$@"
        return
    fi

    local result REPLY
    result="$(\command zoxide query --exclude "$(__zoxide_pwd)" -- "$@")" || return
    __zoxide_primary "$result"
    __zoxide_cd "$REPLY"
}

function zi() {
    local result REPLY
    result="$(\command zoxide query --interactive -- "$@")" || return
    __zoxide_primary "$result"
    __zoxide_cd "$REPLY"
}
