# zoxide prefill: seed the database from ~/Projects so `z <repo>` lands on the
# first try even for a repo this shell has never cd'd into.
#
# Sourced by ~/.zshrc's `~/.config/zsh/*.zsh` loop, which sources in glob order.
# The `zzzz-` prefix is load-bearing: the daily auto-run at the bottom of this
# file executes at source time and calls `__zoxide_primary`, which
# zzz-zoxide.zsh defines. Sorting any earlier runs it against a missing
# function.

zmodload -F zsh/stat b:zstat
zmodload -F zsh/datetime p:EPOCHSECONDS

# Root to scan. Every top-level directory under it is a candidate, git or not.
typeset -g ZOXIDE_PREFILL_ROOT=${ZOXIDE_PREFILL_ROOT:-$HOME/Projects}

# `enabled` runs the once-a-day pass on shell startup; `disabled` leaves
# zoxide-prefill as a purely manual command.
typeset -g ZOXIDE_PREFILL_AUTORUN=${ZOXIDE_PREFILL_AUTORUN:-enabled}

# Touched on every successful --apply; its mtime is the auto-run's throttle.
typeset -g ZOXIDE_PREFILL_STAMP=${ZOXIDE_PREFILL_STAMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zoxide-prefill.stamp}

# Rank by directory mtime age, as (max age in days, rank) pairs, first match
# wins, -1 is the catch-all. Order matters, so this is a flat pair list rather
# than an associative array.
#
# These are ranks, not the scores `zoxide query -ls` prints. zoxide multiplies
# rank by a recency factor to get the score: 4x under an hour, 2x under a day,
# 0.5x under a week, 0.25x beyond. `zoxide add` always stamps an entry as
# accessed *now*, so a fresh seed starts at 4x its rank and settles to 0.25x
# over the following week. The numbers below are chosen for that settled state,
# which is why they read high next to the scores of directories you actually
# use.
#
# Nothing drops below 1.0 deliberately: once the database's total rank passes
# $_ZO_MAXAGE (default 10000) zoxide ages every entry down and deletes whatever
# lands under 1.0, and seeds should not be first against the wall.
#
# Caveat worth knowing when reading the AGE column: a directory's mtime only
# moves when an entry is added or removed at its top level. Editing files deep
# inside a repo, or committing, does not bump it. Age here means "last time the
# top-level layout changed", which is coarse but free — no subprocess per repo.
typeset -ga ZOXIDE_PREFILL_BUCKETS=(
    7    8.0
    30   4.0
    90   2.0
    365  1.5
    -1   1.0
)

# zoxide-prefill [--apply] [--quiet] [<dir>]
#
# Prints what it would add and changes nothing unless --apply is given.
function zoxide-prefill() {
    emulate -L zsh -o extended_glob

    local mode=dry-run output=verbose root=$ZOXIDE_PREFILL_ROOT
    while (( $# )); do
        case $1 in
            --apply)   mode=apply ;;
            --dry-run) mode=dry-run ;;
            --quiet)   output=quiet ;;
            -h|--help)
                print -r -- 'usage: zoxide-prefill [--apply] [--quiet] [<dir>]'
                print -r -- ''
                print -r -- "Seed every top-level directory under <dir> (default ${ZOXIDE_PREFILL_ROOT})"
                print -r -- 'into the zoxide database, ranked by directory mtime. Worktrees fold into'
                print -r -- 'their primary repo, and paths zoxide already knows are left untouched.'
                print -r -- 'Prints a table and exits without writing unless --apply is given.'
                return 0 ;;
            --) shift; [[ -n $1 ]] && root=$1; break ;;
            -*) print -ru2 -- "zoxide-prefill: unknown option: $1"; return 2 ;;
            *)  root=$1 ;;
        esac
        shift
    done

    if (( ! $+commands[zoxide] )); then
        [[ $output == verbose ]] && print -ru2 -- 'zoxide-prefill: zoxide is not installed'
        return 1
    fi
    if (( ! $+functions[__zoxide_primary] )); then
        [[ $output == verbose ]] && print -ru2 -- 'zoxide-prefill: __zoxide_primary is missing (zzz-zoxide.zsh did not load)'
        return 1
    fi
    if [[ ! -d $root ]]; then
        [[ $output == verbose ]] && print -ru2 -- "zoxide-prefill: not a directory: $root"
        return 1
    fi

    # Paths zoxide already knows, which seeds must never touch: re-adding one
    # would bump a score that took real navigation to earn.
    local -A known
    local path_line
    for path_line in ${(f)"$(command zoxide query -l 2>/dev/null)"}; do
        known[$path_line]=1
    done

    # Collect candidates, folding worktrees into their primary repo the same
    # way the `z` wrapper does. Sibling worktrees of one repo therefore collapse
    # to a single entry — and that entry is usually already `known`. Where a
    # worktree is newer than its primary, the newer mtime wins: time spent in a
    # worktree is still time spent on that repo.
    local -A candidate
    local dir target REPLY
    local -a st
    for dir in $root/*(N/); do
        __zoxide_primary $dir
        target=$REPLY
        [[ -n ${known[$target]} ]] && continue
        zstat -A st +mtime -- $dir 2>/dev/null || continue
        (( ${candidate[$target]:-0} < st[1] )) && candidate[$target]=$st[1]
    done

    # Bucket by age so one `zoxide add` covers every path sharing a rank —
    # five subprocesses at most, rather than one per directory.
    local -A by_rank
    local -a rows
    local age days rank limit i
    for target in ${(k)candidate}; do
        # ${...} is required, not stylistic: a bare candidate[$target] inside
        # (( )) is an arithmetic subscript, so the slashes in the path parse as
        # division and the lookup dies with "invalid subscript".
        age=$(( EPOCHSECONDS - ${candidate[$target]} ))
        (( age < 0 )) && age=0
        days=$(( age / 86400 ))
        rank=
        for (( i = 1; i <= $#ZOXIDE_PREFILL_BUCKETS; i += 2 )); do
            limit=$ZOXIDE_PREFILL_BUCKETS[i]
            if (( limit < 0 || days <= limit )); then
                rank=$ZOXIDE_PREFILL_BUCKETS[i+1]   # no spaces: `[i + 1]` is a parse error
                break
            fi
        done
        [[ -n $rank ]] || continue
        by_rank[$rank]+=$target$'\n'
        rows+=( $days$'\t'$rank$'\t'$target )
    done

    if (( ! $#rows )); then
        [[ $output == verbose ]] && print -r -- "zoxide-prefill: nothing new under $root (${#known} paths already in the database)"
        return 0
    fi

    if [[ $output == verbose ]]; then
        print -r -- "zoxide-prefill: $root — $#rows new $( (( $#rows == 1 )) && print -n entry || print -n entries )"
        printf '  %6s  %6s  %s\n' AGE RANK PATH
        local row
        for row in ${(@on)rows}; do
            printf '  %5dd  %6s  %s\n' ${(ps:\t:)row}
        done
    fi

    if [[ $mode == dry-run ]]; then
        [[ $output == verbose ]] && print -r -- '  (dry run — re-run with --apply to write)'
        return 0
    fi

    local -a paths
    for rank in ${(k)by_rank}; do
        # (@f) keeps empty fields out; by_rank values are newline-terminated.
        paths=( ${(f)by_rank[$rank]} )
        (( $#paths )) || continue
        command zoxide add -s $rank $paths || return 1
    done

    [[ -d ${ZOXIDE_PREFILL_STAMP:h} ]] || mkdir -p ${ZOXIDE_PREFILL_STAMP:h}
    : >| $ZOXIDE_PREFILL_STAMP

    [[ $output == verbose ]] && print -r -- "  added $#rows $( (( $#rows == 1 )) && print -n entry || print -n entries )"
    return 0
}

# --- daily auto-run ---------------------------------------------------------
#
# Fires at most once every 24h, gated on the stamp file's mtime, so a normal
# shell startup pays one `zstat` and nothing else. On the day it does fire the
# cost is one `zoxide query -l` plus one `zoxide add` per rank bucket — batched,
# so it stays in the low milliseconds even on the very first run.
#
# The auto-run always applies. Dry-run is the default for *you*, at a prompt
# where the table is worth reading; a startup hook that printed it daily and
# changed nothing would be pure noise.
() {
    [[ $ZOXIDE_PREFILL_AUTORUN == enabled ]] || return 0
    local -a st
    if zstat -A st +mtime -- $ZOXIDE_PREFILL_STAMP 2>/dev/null; then
        (( EPOCHSECONDS - st[1] < 86400 )) && return 0
    fi
    zoxide-prefill --apply --quiet
} 2>/dev/null
