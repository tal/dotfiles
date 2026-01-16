#!/usr/bin/env bash

# Read stdin JSON input
input=$(cat)

# Extract workspace directory
dir=$(echo "$input" | jq -r '.workspace.current_dir')
basename=$(basename "$dir")

# Get git branch (skip optional locks)
branch=$(cd "$dir" 2>/dev/null && git -c core.fileMode=false -c gc.autodetach=false rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

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

echo -e "$output"
