# orca-theme.zsh
#
# Theme the terminal based on which Orca worktree/repo the shell is in, so
# parallel Orca agent terminals are distinguishable at a glance.
#
# REPO-FIRST + DATA-DRIVEN. There are NO per-repo handler functions here any
# more. To theme a repo you drop ONE JSON data file into the repo itself,
# committed at  <worktree>/design/terminal-theme.json  -- zero shell edits.
# Because git worktrees share tracked files, committing that file themes every
# Orca worktree of the repo automatically, and it travels with the repo.
#
# A machine-local override can live in the central dir
#   ~/.config/orca/themes/<displayName>.json
# and, when present, WINS over the in-repo file (git-config model: a deliberate
# local file beats the shared committed default). Use it for repos you can't
# commit to or want to retune on this machine only.
#
# LOOKUP KEY: the repo-level Orca displayName from
#   orca repo show --repo "id:${ORCA_WORKTREE_ID%%::*}" --json | jq -r .result.repo.displayName
# WORKTREE PATH: always ${ORCA_WORKTREE_ID#*::} (the real checkout), never
# repo.path (which diverges for non-main worktrees).
#
# Applied automatically on shell startup, but ONLY inside Orca worktree
# terminals (ORCA_WORKTREE_ID is set). Runs SYNCHRONOUSLY during ~/.zshrc
# sourcing (see the note at the bottom): a backgrounded emit raced with the
# line editor and could make Tab/Backspace stop working.
#
# Fully optional / graceful: it never breaks your shell. If `orca` or `jq`
# isn't on PATH it just logs one line to stderr and returns. Non-Orca
# terminals stay completely silent. Set ORCA_THEME_QUIET=1 to silence even the
# missing-tooling log.
#
# ENV KNOBS:
#   ORCA_THEME_VARIANT  day|night   -- which variant to apply (default night;
#                                       invalid values fall back to night).
#   ORCA_THEME_DIR      <dir>       -- central override dir (default
#                                       ~/.config/orca/themes); mainly for
#                                       testing.
#   ORCA_THEME_QUIET    <non-empty> -- silence the missing-tooling log line.
#   ORCA_THEME_DEBUG    <file>      -- append one "HH:MM:SS <pid> <trigger>"
#                                       line per repaint (precmd / winch /
#                                       statusline) to <file>, to see which
#                                       trigger actually fires on re-attach.
#
# NOTE: this loader only sets TERMINAL colors (OSC 10/11/12/4). The Claude Code
# half of a theme (the dim 'inactive' text token) is NOT a terminal color and
# cannot be set via OSC -- it is applied by `orca-theme install` from the same
# in-repo file's `claudeCode` section.

# --- OSC helpers ----------------------------------------------------------
# These APPEND their escape(s) to the global $_ORCA_THEME_OSC accumulator instead
# of printing directly, so the whole payload is built once into ONE cached
# string. orca-terminal-theme emits that string at startup to paint the surface;
# the precmd hook (_orca_theme_reapply) re-emits the SAME string after an Orca
# app restart -- where the shell (and thus this loader) does not re-run, but the
# renderer surface is recreated on its default background. One source of the
# escape format, so the startup paint and the re-paint can never drift.
# _orca_osc <code> <value>  -> one color: fg=10, bg=11, cursor=12
# _orca_palette <c0..c15>   -> the 16 ANSI palette slots via OSC 4
_orca_osc()     { _ORCA_THEME_OSC+=$'\e]'"$1;$2"$'\e\\'; }
_orca_palette() { local i=0 c; for c in "$@"; do _ORCA_THEME_OSC+=$'\e]4;'"$i;$c"$'\e\\'; (( i++ )); done; }

# _orca_theme_reapply [<source>] -- re-emit the cached theme payload.
# Registered by orca-terminal-theme as BOTH a precmd hook and the SIGWINCH trap,
# so the colors are re-asserted (a) before every prompt and (b) the instant the
# renderer resizes the pty. (b) is what makes a pane repaint the moment Orca
# re-attaches it to a fresh renderer surface (app restart, tab re-activation):
# the new surface comes up on its default background and fires a resize on
# attach, while the surviving shell never re-runs the loader. Without it a shell
# idling at a prompt stays un-themed until you press Enter.
# Cheap: one print of a pre-built string, zero orca/jq calls. Emits only
# color-setting OSC (no cursor moves, no input reads), synchronously from the
# shell itself, so it cannot race the line editor the way the old '&!'
# background emit could.
# <source> is informational ("precmd" / "winch") and only shows up when
# ORCA_THEME_DEBUG names a log file -- set it to see which trigger actually
# fires when a pane comes back.
_orca_theme_reapply() {
  [[ -n "$_ORCA_THEME_OSC" ]] || return 0
  print -rn -- "$_ORCA_THEME_OSC"
  [[ -n "$ORCA_THEME_DEBUG" ]] && print -rP -- "%D{%H:%M:%S} $$ ${1:-precmd}" >> "$ORCA_THEME_DEBUG"
  return 0
}

# --- reset to terminal defaults ------------------------------------------
# Reset everything a theme might touch back to the terminal's own defaults.
orca-theme-reset() {
  printf '\e]110\e\\'   # reset foreground
  printf '\e]111\e\\'   # reset background
  printf '\e]112\e\\'   # reset cursor
  printf '\e]104\e\\'   # reset the whole ANSI palette
}

# Resolve the current Orca repo, find its theme file, and paint the terminal
# (or reset to defaults when the repo has no theme anywhere).
orca-terminal-theme() {
  emulate -L zsh

  # 1. Not an Orca worktree terminal -> nothing to do, silently.
  [[ -n "$ORCA_WORKTREE_ID" ]] || return 0

  # 1b. Start each run with an empty payload accumulator. Any early return below
  #     (missing tooling, no theme, malformed JSON -> reset) then leaves it
  #     empty, so the precmd re-emit is a no-op for un-themed / reset repos.
  typeset -g _ORCA_THEME_OSC=""

  # 2. In an Orca worktree but tooling is missing -> degrade gracefully + log.
  if ! (( $+commands[orca] && $+commands[jq] )); then
    [[ -n "$ORCA_THEME_QUIET" ]] || \
      print -u2 -- "orca-theme: skipping, need 'orca' and 'jq' on PATH"
    return 0
  fi

  # 3. Resolve the repo-level Orca displayName (the only orca call).
  local name
  name="$(orca repo show --repo "id:${ORCA_WORKTREE_ID%%::*}" --json 2>/dev/null \
            | jq -r '.result.repo.displayName // empty' 2>/dev/null)"
  [[ -n "$name" ]] || return 0

  # 4. Locate the theme file by precedence: CENTRAL OVERRIDE first, then
  #    IN-REPO. (Repo-first by default, but a local override wins.) The
  #    worktree path comes straight from the env var (zero cost).
  local wt="${ORCA_WORKTREE_ID#*::}"
  local central="${ORCA_THEME_DIR:-$HOME/.config/orca/themes}/${name}.json"
  local inrepo="${wt}/design/terminal-theme.json"
  local file=""
  if   [[ -r "$central" ]]; then file="$central"
  elif [[ -r "$inrepo"  ]]; then file="$inrepo"
  fi

  # 5. No theme for this repo -> terminal defaults.
  if [[ -z "$file" ]]; then orca-theme-reset; return 0; fi

  # 6. Variant enum: ORCA_THEME_VARIANT in {day,night}, default night; an
  #    invalid value falls back to night rather than erroring.
  local variant="${ORCA_THEME_VARIANT:-night}"
  case "$variant" in day|night) ;; *) variant=night ;; esac

  # 7. ONE jq parse of the (small) theme file. bg/fg/cursor land on the first
  #    three lines ("-" marks an absent color, keeping positions stable), then
  #    each palette entry on its own line.
  local -a lines
  lines=("${(@f)$(jq -r --arg v "$variant" '
      .variants[$v].background // "-",
      .variants[$v].foreground // "-",
      .variants[$v].cursor     // "-",
      (.palette[]?)
    ' "$file" 2>/dev/null)}")

  # 8. Malformed/empty JSON -> treat as no theme, reset.
  if (( ${#lines} < 3 )); then orca-theme-reset; return 0; fi

  local bg="${lines[1]}" fg="${lines[2]}" cur="${lines[3]}"
  local -a palette=("${(@)lines[4,-1]}")   # zsh 1-indexed slice, elements 4..end

  # 9. Build the cached OSC payload (skip any color left as "-"), emit it once to
  #    paint this surface now.
  [[ "$fg"  != "-" ]] && _orca_osc 10 "$fg"
  [[ "$bg"  != "-" ]] && _orca_osc 11 "$bg"
  [[ "$cur" != "-" ]] && _orca_osc 12 "$cur"
  (( ${#palette} )) && _orca_palette "${palette[@]}"
  print -rn -- "$_ORCA_THEME_OSC"

  # 10. Re-assert the theme before every prompt. This is the fix for "an Orca
  #     restart resets the background": Orca hosts the shell in a persistent
  #     daemon, so a restart recreates only the renderer surface (on its default
  #     background) -- the shell survives and this loader never re-runs. The
  #     precmd re-emit repaints on the next prompt. Idempotent (same colors, no
  #     flicker) and add-zsh-hook de-dupes, so re-invoking this is safe.
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _orca_theme_reapply

  # 11. ...and the instant the pty is resized. A fresh renderer surface fits
  #     itself to the pane on attach, which sends SIGWINCH to the foreground
  #     process group -- for a shell idling at its prompt that's us, so we can
  #     repaint immediately instead of waiting for the next Enter. (A foreground
  #     TUI owns the process group instead; see the statusline path in
  #     ~/.claude/statusline-command.sh for that case.) Installed once per shell
  #     and chained onto any TRAPWINCH that was already defined, so re-running
  #     this can't recurse into itself.
  if [[ -z "$_ORCA_THEME_WINCH_INSTALLED" ]]; then
    # `emulate -L` above turned on LOCAL_TRAPS, under which a trap defined in
    # a function is silently restored to its previous value when the function
    # returns -- i.e. this TRAPWINCH would vanish on exit. Switch it off for the
    # definition; LOCAL_OPTIONS puts the option back on return, the trap stays.
    setopt nolocaltraps
    (( $+functions[TRAPWINCH] )) && functions -c TRAPWINCH _orca_theme_prev_winch
    TRAPWINCH() {
      (( $+functions[_orca_theme_prev_winch] )) && _orca_theme_prev_winch "$@"
      _orca_theme_reapply winch
    }
    typeset -g _ORCA_THEME_WINCH_INSTALLED=1
  fi
}

# Auto-apply on startup. Guard on ORCA_WORKTREE_ID first so non-Orca shells pay
# exactly zero cost; the function itself handles (and logs) the missing-tooling
# case.
#
# SYNCHRONOUS on purpose (was '&!' before). A backgrounded job writing OSC
# escapes to the TTY races with zsh's line editor once the prompt is up: the
# terminal's escape parser can swallow the next keystrokes, so Tab/Backspace
# appear "dead". Running it here, inline during ~/.zshrc sourcing, means all
# escapes are written BEFORE ZLE takes over the terminal -- no concurrent
# writer, no eaten keys. Cost is one `orca repo show` (~0.15s) on Orca-worktree
# shells only.
if [[ -o interactive && -n "$ORCA_WORKTREE_ID" ]]; then
  orca-terminal-theme
fi
