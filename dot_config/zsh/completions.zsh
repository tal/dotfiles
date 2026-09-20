# Treat a directory name in command position as `cd <directory>`.
# Zsh's _autocd completer also offers directories alongside PATH commands.
setopt AUTO_CD

# Zsh completions for cc (claude) function

# Offer the nearest project's custom params (from custom-params.json) as
# completion candidates. Shared by _cc and _cx. Silent when there's no config
# file, no jq, or no params. Helpers live in ~/.config/zsh/coding-agents.zsh.
_ca_param_completions() {
  (( $+functions[_ca_merged] )) || return
  local merged
  merged="$(_ca_merged 2>/dev/null)" || return
  [[ -n "$merged" ]] || return
  # Offer only params applicable to this tool's harness (cx => codex, else claude).
  local harness=claude
  [[ "$words[1]" == cx ]] && harness=codex
  local -a params
  params=("${(@f)$(_ca_param_names "$merged" "$harness")}")
  (( ${#params} )) || return
  # Offer each param only once: drop any already present on the command line.
  # words[1] is the command (cc/cx); words[2,-1] are the args typed so far.
  local -a already=("${(@)words[2,-1]}")
  local -a fresh
  local entry
  for entry in "${params[@]}"; do
    (( ${already[(Ie)${entry%%:*}]} )) && continue
    fresh+=("$entry")
  done
  (( ${#fresh} )) && _describe -t custom-params 'project custom params' fresh
}

_cc() {
  local -a claude_options shorthand_commands
  local state

  # Shorthand commands (c, r), bare model names -> --model <name>, and
  # versioned model shorthand (e.g. opus4.6, sonnet4.5) -> --model claude-<family>-<version>.
  # Any (opus|sonnet|haiku|fable) followed by digits works (dot optional,
  # e.g. opus48 == opus4.8); these are just the last two versions per family
  # offered as completion hints.
  # Bare model names (opus/sonnet/haiku/fable) and effort aliases now live in the
  # merged custom-params config and are offered via _ca_param_completions; only
  # the native control shorthands and the generative versioned hints stay here.
  shorthand_commands=(
    'c:Continue the most recent conversation'
    'r:Resume a conversation by session ID'
    'opus5:Use Opus 5 (--model claude-opus-5)'
    'opus4.6:Use Opus 4.6 (--model claude-opus-4-6)'
    'sonnet5:Use Sonnet 5 (--model claude-sonnet-5)'
    'sonnet4.5:Use Sonnet 4.5 (--model claude-sonnet-4-5)'
    'haiku4.5:Use Haiku 4.5 (--model claude-haiku-4-5)'
    'fable5.1:Use Fable 5.1 (--model claude-fable-5-1)'
  )

  # Claude options and flags
  claude_options=(
    '--add-dir[Additional directories to allow tool access to]:directories:_directories'
    '--agent[Agent for the current session]:agent:'
    '--agents[JSON object defining custom agents]:json:'
    '--allow-dangerously-skip-permissions[Enable bypassing permission checks as an option]'
    '--allowedTools[Comma or space-separated list of tool names to allow]:tools:'
    '--allowed-tools[Comma or space-separated list of tool names to allow]:tools:'
    '--append-system-prompt[Append a system prompt]:prompt:'
    '--betas[Beta headers to include in API requests]:betas:'
    '--chrome[Enable Claude in Chrome integration]'
    {-c,--continue}'[Continue the most recent conversation]'
    '--dangerously-skip-permissions[Bypass all permission checks]'
    {-d,--debug}'[Enable debug mode with optional category filtering]:filter:'
    '--debug-file[Write debug logs to a specific file path]:path:_files'
    '--disable-slash-commands[Disable all skills]'
    '--disallowedTools[Comma or space-separated list of tool names to deny]:tools:'
    '--disallowed-tools[Comma or space-separated list of tool names to deny]:tools:'
    '--enable-auto-mode[Enable auto mode as an available permission option]'
    '--fallback-model[Enable automatic fallback to specified model]:model:(sonnet opus haiku)'
    '--file[File resources to download at startup]:specs:'
    '--fork-session[Create a new session ID instead of reusing]'
    '--from-pr[Resume a session linked to a PR]:value:'
    {-h,--help}'[Display help for command]'
    '--ide[Automatically connect to IDE on startup]'
    '--include-partial-messages[Include partial message chunks]'
    '--input-format[Input format]:format:(text stream-json)'
    '--json-schema[JSON Schema for structured output validation]:schema:'
    '--max-budget-usd[Maximum dollar amount to spend]:amount:'
    '--mcp-config[Load MCP servers from JSON files or strings]:configs:'
    '--mcp-debug[Enable MCP debug mode]'
    '--model[Model for the current session]:model:(sonnet opus haiku claude-sonnet-4-5-20250929 claude-opus-4-6 claude-haiku-4-5-20251001)'
    '--no-chrome[Disable Claude in Chrome integration]'
    '--no-session-persistence[Disable session persistence]'
    '--output-format[Output format]:format:(text json stream-json)'
    '--permission-mode[Permission mode]:mode:(acceptEdits auto bypassPermissions default delegate dontAsk plan)'
    '--plugin-dir[Load plugins from directories]:paths:_directories'
    {-p,--print}'[Print response and exit]'
    '--replay-user-messages[Re-emit user messages from stdin]'
    {-r,--resume}'[Resume a conversation]:value:'
    '--session-id[Use a specific session ID]:uuid:'
    '--setting-sources[Comma-separated list of setting sources]:sources:'
    '--settings[Path to settings JSON file or JSON string]:file-or-json:_files'
    '--strict-mcp-config[Only use MCP servers from --mcp-config]'
    '--system-prompt[System prompt to use]:prompt:'
    '--tools[Specify the list of available tools]:tools:'
  )

  # '*' so shorthands/models are offered at any position, not just the first
  _arguments -s -S \
    '*: :->args' \
    $claude_options

  if [[ $state == args ]]; then
    _describe -t shorthand-commands 'shorthand commands' shorthand_commands
    _ca_param_completions
  fi
}

# Register completion for cc function
compdef _cc cc

# Zsh completions for claude binary
_claude() {
  local -a claude_subcommands claude_options
  local state

  claude_subcommands=(
    'api:Send a single API request'
    'auto-mode:Inspect the auto mode classifier configuration'
    'config:Manage configuration'
    'mcp:Configure and manage MCP servers'
  )

  claude_options=(
    '--add-dir[Additional directories to allow tool access to]:directories:_directories'
    '--agent[Agent for the current session]:agent:'
    '--agents[JSON object defining custom agents]:json:'
    '--allow-dangerously-skip-permissions[Enable bypassing permission checks as an option]'
    '--allowedTools[Comma or space-separated list of tool names to allow]:tools:'
    '--allowed-tools[Comma or space-separated list of tool names to allow]:tools:'
    '--append-system-prompt[Append a system prompt]:prompt:'
    '--betas[Beta headers to include in API requests]:betas:'
    '--chrome[Enable Claude in Chrome integration]'
    {-c,--continue}'[Continue the most recent conversation]'
    '--dangerously-skip-permissions[Bypass all permission checks]'
    {-d,--debug}'[Enable debug mode with optional category filtering]:filter:'
    '--debug-file[Write debug logs to a specific file path]:path:_files'
    '--disable-slash-commands[Disable all skills]'
    '--disallowedTools[Comma or space-separated list of tool names to deny]:tools:'
    '--disallowed-tools[Comma or space-separated list of tool names to deny]:tools:'
    '--enable-auto-mode[Enable auto mode as an available permission option]'
    '--fallback-model[Enable automatic fallback to specified model]:model:(sonnet opus haiku)'
    '--file[File resources to download at startup]:specs:'
    '--fork-session[Create a new session ID instead of reusing]'
    '--from-pr[Resume a session linked to a PR]:value:'
    {-h,--help}'[Display help for command]'
    '--ide[Automatically connect to IDE on startup]'
    '--include-partial-messages[Include partial message chunks]'
    '--input-format[Input format]:format:(text stream-json)'
    '--json-schema[JSON Schema for structured output validation]:schema:'
    '--max-budget-usd[Maximum dollar amount to spend]:amount:'
    '--mcp-config[Load MCP servers from JSON files or strings]:configs:'
    '--mcp-debug[Enable MCP debug mode]'
    '--model[Model for the current session]:model:(sonnet opus haiku claude-sonnet-4-5-20250929 claude-opus-4-6 claude-haiku-4-5-20251001)'
    '--no-chrome[Disable Claude in Chrome integration]'
    '--no-session-persistence[Disable session persistence]'
    '--output-format[Output format]:format:(text json stream-json)'
    '--permission-mode[Permission mode]:mode:(acceptEdits auto bypassPermissions default delegate dontAsk plan)'
    '--plugin-dir[Load plugins from directories]:paths:_directories'
    {-p,--print}'[Print response and exit]'
    '--replay-user-messages[Re-emit user messages from stdin]'
    {-r,--resume}'[Resume a conversation]:value:'
    '--session-id[Use a specific session ID]:uuid:'
    '--setting-sources[Comma-separated list of setting sources]:sources:'
    '--settings[Path to settings JSON file or JSON string]:file-or-json:_files'
    '--strict-mcp-config[Only use MCP servers from --mcp-config]'
    '--system-prompt[System prompt to use]:prompt:'
    '--tools[Specify the list of available tools]:tools:'
    {-V,--version}'[Display version]'
  )

  _arguments -s -S \
    '1: :->firstarg' \
    $claude_options

  if [[ $state == firstarg ]]; then
    _describe -t subcommands 'claude subcommands' claude_subcommands
  fi
}

compdef _claude claude

# Zsh completions for the `cx` function (codex counterpart to cc; see coding-agents.zsh).
# `cx` reuses codex's own generated completion. `codex completion zsh` is ~4k
# lines and shelling out to codex on every startup would tax time-to-prompt, so
# cache the output and regenerate only when the codex binary is newer than the
# cache. `compdef cx=codex` then maps the `cx` function onto codex's `_codex`.
if (( $+commands[codex] )); then
  _codex_comp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/codex-completion.zsh"
  if [[ ! -s $_codex_comp_cache || $commands[codex] -nt $_codex_comp_cache ]]; then
    mkdir -p ${_codex_comp_cache:h}
    codex completion zsh >| $_codex_comp_cache 2>/dev/null
  fi
  source $_codex_comp_cache
  # Wrap codex's own completion so `cx` also offers this project's custom params
  # (see _ca_param_completions above) alongside codex's flags/subcommands.
  _cx() {
    _ca_param_completions
    (( $+functions[_codex] )) && _codex "$@"
  }
  compdef _cx cx
  unset _codex_comp_cache
fi

# Zsh completions for the orca-theme CLI (~/.config/orca/bin/orca-theme).
# Per-repo Orca terminal + Claude Code theming helper; see ~/.config/orca/README.md.
# Completes: subcommands, their flags, --variant values, and live repo names.

_orca_theme_repos() {
  # Orca repo displayNames (may contain spaces -> _describe quotes them for us).
  # One `orca repo list` per repo-arg completion; empty & silent if Orca is down.
  local -a _repos
  _repos=(${(f)"$(orca repo list --json 2>/dev/null | jq -r '.result.repos[].displayName' 2>/dev/null)"})
  (( ${#_repos} )) && _describe -t repos 'orca repo' _repos
}

_orca-theme() {
  local curcontext="$curcontext" state line
  local -a commands
  commands=(
    'list:Table of every registered repo theme status'
    'preview:Apply a repo theme to THIS terminal, live (temporary)'
    'apply:Apply a repo theme to THIS terminal (no temporary framing)'
    'reset:Reset this terminal to its own default colors'
    'new:Scaffold design/terminal-theme.json in the repo (source of truth)'
    'scaffold:Alias of new'
    'install:Materialize the Claude Code half of a repo theme'
    'statusline-color:Print the statusline project-name color'
    'doctor:Check orca/jq, themes dir, resolved theme source'
    'help:Show help'
  )

  _arguments -C \
    {-h,--help}'[Show help]' \
    '1: :->cmd' \
    '*:: :->args'

  case $state in
    cmd)
      _describe -t commands 'orca-theme command' commands
      ;;
    args)
      case $line[1] in
        preview|apply)
          _arguments \
            '--variant[Which variant to apply]:variant:(day night)' \
            '1:repo:_orca_theme_repos'
          ;;
        new|scaffold)
          _arguments \
            '--central[Write the central override instead of the in-repo file]' \
            '--from-badge[Seed colors from the repo Orca badgeColor]' \
            '--force[Overwrite an existing theme file]' \
            '1:repo:_orca_theme_repos'
          ;;
        install)
          _arguments \
            '--shared[Write the selection into the committed settings.json]' \
            '1:repo:_orca_theme_repos'
          ;;
        statusline-color)
          _arguments \
            '--variant[Which statusName variant to use]:variant:(day night)' \
            '1:dir:_files -/'
          ;;
        # list | reset | doctor | help take no further arguments
      esac
      ;;
  esac
}

compdef _orca-theme orca-theme
