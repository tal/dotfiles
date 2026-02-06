#!/usr/bin/env bash

# Read stdin JSON input
input=$(cat)

# Extract workspace directory
dir=$(echo "$input" | jq -r '.workspace.current_dir')
basename=$(basename "$dir")

# Get git branch (skip optional locks)
branch=$(cd "$dir" 2>/dev/null && git -c core.fileMode=false -c gc.autodetach=false rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Get PR URL for current branch (cached for 30s)
pr_url=""
if [ -n "$branch" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
  cache_file="/tmp/claude-statusline-pr-${dir//\//_}-${branch}"
  cache_max_age=30
  if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0))) -lt $cache_max_age ]; then
    pr_url=$(cat "$cache_file")
  else
    pr_url=$(cd "$dir" 2>/dev/null && gh pr view --json url -q .url 2>/dev/null || echo "")
    echo "$pr_url" > "$cache_file" 2>/dev/null
  fi
fi

# Calculate context usage percentage
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$input" | jq '.context_window.context_window_size')
  pct=$((current * 100 / size))
else
  pct=0
fi

# Define colors using ANSI escape codes
# Cyan for directory
DIR_COLOR="\033[36m"
# Magenta for git branch
BRANCH_COLOR="\033[35m"
# Dynamic color for context based on usage level
# Grey (<50%), Yellow (50-75%), Red (>75%)
if [ $pct -lt 50 ]; then
  CONTEXT_COLOR="\033[90m"  # Grey
elif [ $pct -lt 75 ]; then
  CONTEXT_COLOR="\033[33m"  # Yellow
else
  CONTEXT_COLOR="\033[31m"  # Red
fi
# Reset color
RESET="\033[0m"

# Choose circle representation based on usage
if [ $pct -lt 20 ]; then
  CIRCLE="○"  # Empty circle
elif [ $pct -lt 40 ]; then
  CIRCLE="◔"  # Quarter filled
elif [ $pct -lt 60 ]; then
  CIRCLE="◑"  # Half filled
elif [ $pct -lt 80 ]; then
  CIRCLE="◕"  # Three-quarters filled
else
  CIRCLE="●"  # Full circle
fi

# Build output with colors
output="${DIR_COLOR}${basename}${RESET}"

# Add branch if present
if [ -n "$branch" ]; then
  output="${output}  ${BRANCH_COLOR}${branch}${RESET}"
fi

# Add context usage
output="${output}  ${CONTEXT_COLOR}${CIRCLE} ${pct}%${RESET}"

# Detect OSC 8 hyperlink support (mirrors supports-hyperlinks npm package)
supports_osc8() {
  case "${TERM_PROGRAM:-}" in
    iTerm.app|WezTerm|ghostty|vscode|zed|Hyper) return 0 ;;
  esac
  [ -n "${CURSOR_TRACE_ID:-}" ] && return 0
  [ -n "${WT_SESSION:-}" ] && return 0
  [ -n "${VTE_VERSION:-}" ] && return 0
  case "${TERM:-}" in
    *alacritty*|*kitty*) return 0 ;;
  esac
  return 1
}

# Add PR link if available (right side)
if [ -n "$pr_url" ]; then
  PR_COLOR="\033[34m"
  if supports_osc8; then
    # Terminal renders clickable links natively - use short label
    output="${output}  ${PR_COLOR}\033]8;;${pr_url}\033\\\\PR\033]8;;\033\\\\${RESET}"
  else
    # No link support - show full URL
    output="${output}  ${PR_COLOR}${pr_url}${RESET}"
  fi
fi

echo -e "$output"
