# General aliases
alias ll='lsd -la'
alias la='lsd -A'
alias l='lsdl --limit 3 -F'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Claude aliases
alias cyolo='claude --allow-dangerously-skip-permissions'

# cc function with shorthand parameter support
cc() {
  local args=()
  local permission_flag='--allow-dangerously-skip-permissions'

  # Process parameters
  for arg in "$@"; do
    case "$arg" in
      a)
        permission_flag='--enable-auto-mode'
        ;;
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

  claude "$permission_flag" "${args[@]}"
}
