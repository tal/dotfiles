# General aliases
alias ll='lsd -la'
alias la='lsd -A'
alias l='lsd -F'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Claude aliases
alias cyolo='claude --allow-dangerously-skip-permissions'

# cc function with shorthand parameter support
cc() {
  local args=()

  # If no parameters, just call the base command
  if [[ $# -eq 0 ]]; then
    claude --allow-dangerously-skip-permissions
    return
  fi

  # Process parameters
  for arg in "$@"; do
    case "$arg" in
      c)
        args+=(--continue)
        ;;
      r)
        args+=(--resume)
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done

  claude --allow-dangerously-skip-permissions "${args[@]}"
}
