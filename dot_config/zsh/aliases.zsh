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
