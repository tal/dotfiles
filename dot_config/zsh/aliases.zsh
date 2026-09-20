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

# The `cc` (claude) and `cx` (codex) wrapper functions now live in
# ~/.config/zsh/coding-agents.zsh, alongside the custom-params `_ca_*` engine
# they call into. Completions for both are in completions.zsh.
