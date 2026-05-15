#!/usr/bin/env bash

# Read stdin JSON input
input=$(cat)

# Extract workspace directories
initial_dir=$(echo "$input" | jq -r '.workspace.project_dir')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir="$current_dir"  # Keep for git operations

# Resolve project name: PROJECT_NAME env var > git remote > directory name
initial_name=$(basename "$initial_dir")
parent_dir=$(dirname "$initial_dir")

if [ -n "${PROJECT_NAME:-}" ]; then
  project_name="$PROJECT_NAME"
else
  # Try git remote name
  project_name=$(cd "$dir" 2>/dev/null && git remote get-url origin 2>/dev/null | sed 's/.*\///;s/\.git$//' || echo "")
fi

# Fallback to directory-based name
if [ -z "$project_name" ]; then
  if [ "$initial_name" = ".claude" ]; then
    if [ "$parent_dir" = "$HOME" ]; then
      project_name="~/.claude"
    elif [ "$(dirname "$parent_dir")" = "$HOME" ]; then
      project_name="~/$(basename "$parent_dir")/.claude"
    else
      project_name="$(basename "$parent_dir")/.claude"
    fi
  elif [ "$parent_dir" = "$HOME" ]; then
    project_name="~/$(basename "$initial_dir")"
  else
    project_name=$(basename "$initial_dir")
  fi
fi

# Detect if in a git worktree
worktree_name=""
git_dir_path=$(cd "$dir" 2>/dev/null && git rev-parse --git-dir 2>/dev/null || echo "")
if [[ "$git_dir_path" == */worktrees/* ]]; then
  worktree_name="$initial_name"
fi

# Build dir_display: project name + relative path (same whether in worktree or not)
if [ "$initial_dir" = "$current_dir" ]; then
  dir_display="$project_name"
else
  rel_path="${current_dir#"$initial_dir"}"
  rel_path="${rel_path#/}"
  if [ -z "$rel_path" ]; then
    rel_path="$(basename "$current_dir")"
  fi
  dir_display="$project_name (${rel_path}/)"
fi

# Get git branch (skip optional locks)
branch=$(cd "$dir" 2>/dev/null && git -c core.fileMode=false -c gc.autodetach=false rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Calculate context usage percentage
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$input" | jq '.context_window.context_window_size')
  pct=$((current * 100 / size))
  current_k=$((current / 1000))
  if [ $current_k -ge 1000 ]; then
    token_display="$((current_k / 1000)).$(( (current_k % 1000) / 100))m"
  else
    token_display="${current_k}k"
  fi
else
  pct=0
  current_k=0
  token_display="0k"
fi

# Define colors using ANSI escape codes
# Purple for directory (matches starship prompt #cc44ff)
DIR_COLOR="\033[1;38;2;204;68;255m"
# Green bold for git branch (matches starship git_branch style)
BRANCH_COLOR="\033[1;32m"
# Dynamic color for context based on usage level
# Grey (<150k), Yellow (150k-500k), Red (>500k)
if [ $current_k -lt 150 ]; then
  CONTEXT_COLOR="\033[90m"  # Grey
elif [ $current_k -lt 500 ]; then
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

# Check battery level (macOS)
battery_warning=""
battery_pct=$(pmset -g batt 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%')
if [ -n "$battery_pct" ] && [ "$battery_pct" -lt 20 ]; then
  RED="\033[31m"
  battery_warning="${RED}🪫 ${battery_pct}%${RESET}  "
fi

# Build output with colors
output="${battery_warning}${DIR_COLOR}${dir_display}${RESET}"

# Add branch if present
if [ -n "$branch" ]; then
  output="${output}  ${BRANCH_COLOR}${branch}${RESET}"
fi

# Add context usage
output="${output}  ${CONTEXT_COLOR}${CIRCLE} ${token_display}${RESET}"

# Add worktree name at the end in light grey
if [ -n "$worktree_name" ]; then
  GREY="\033[90m"
  output="${output}  ${GREY}worktree: ${worktree_name}${RESET}"
fi

echo -e "$output"
