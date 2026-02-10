# Zsh completions for cc (claude) function

_cc() {
  local -a claude_options shorthand_commands

  # Shorthand commands (c and r)
  shorthand_commands=(
    'c:Continue the most recent conversation'
    'r:Resume a conversation by session ID'
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
    '--permission-mode[Permission mode]:mode:(acceptEdits bypassPermissions default delegate dontAsk plan)'
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

  _arguments -s -S \
    '1: :->commands' \
    '*:: :->options' \
    && return 0

  case $state in
    commands)
      _describe -t shorthand-commands 'shorthand commands' shorthand_commands
      _describe -t claude-options 'claude options' claude_options
      ;;
    options)
      _describe -t claude-options 'claude options' claude_options
      ;;
  esac
}

# Register completion for cc function
compdef _cc cc
