# General aliases
alias ll='lsd -la'
alias la='lsd -A'
alias l='lsd -F'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Chezmoi aliases
alias cm='chezmoi'
alias cma='chezmoi apply'
alias cme='chezmoi edit'
alias cmu='chezmoi update'
alias cmd='chezmoi diff'

# Brew aliases
alias bi='brew install'
alias bs='brew search'
alias bu='brew update && brew upgrade'
alias binfo='brew info'

# Claude aliases
alias cyolo='claude --allow-dangerously-skip-permissions'