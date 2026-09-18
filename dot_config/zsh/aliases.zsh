# General aliases
alias ll='lsd -la'
alias la='lsd -A'
alias l='lsdl --limit 3 -F'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Claude aliases
alias cyolo='claude --allow-dangerously-skip-permissions'

# Muscle-memory: let `/exit` close the shell like it closes Claude Code
alias /exit='exit'

# cc function with shorthand parameter support
cc() {
  local args=()
  local model=''

  # Process parameters. Order doesn't matter: shorthand commands (c/r) and a
  # model name can appear in any position, before or after each other.
  for arg in "$@"; do
    case "$arg" in
      c)
        args+=(--continue)
        ;;
      r)
        args+=(--resume)
        ;;
      opus|sonnet|haiku|fable|claude-*)
        model="$arg"
        ;;
      (opus|sonnet|haiku|fable)[0-9]*)
        # Versioned shorthand: opus4.8, opus48, fable5, fable5.0, etc.
        # The dot is optional -- "opus48" is treated the same as "opus4.8".
        if [[ "$arg" =~ ^(opus|sonnet|haiku|fable)([0-9]+)(\.[0-9]+)?$ ]]; then
          local family="$match[1]" verpart="$match[2]" dotpart="$match[3]"
          local major minor
          if [[ -n "$dotpart" ]]; then
            major="$verpart"
            minor="${dotpart#.}"
          elif (( ${#verpart} > 1 )); then
            major="${verpart[1]}"
            minor="${verpart[2,-1]}"
          else
            major="$verpart"
            minor=""
          fi
          if [[ -n "$minor" ]]; then
            model="claude-${family}-${major}-${minor}"
          else
            model="claude-${family}-${major}"
          fi
        else
          args+=("$arg")
        fi
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done

  if [[ -n "$model" ]]; then
    args+=(--model "$model")
  fi

  claude --allow-dangerously-skip-permissions --chrome "${args[@]}"
}

# cx function: codex counterpart to cc. Always runs with --yolo
# (alias for --dangerously-bypass-approvals-and-sandbox). No shorthand
# parameters are implemented yet; every argument is passed straight
# through to codex. Tab completion is inherited from codex itself
# (see `compdef cx=codex` in completions.zsh).
cx() {
  codex --yolo "$@"
}
