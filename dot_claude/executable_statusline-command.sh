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
elif [ "${current_dir#"$initial_dir"/}" != "$current_dir" ]; then
  # current_dir is a descendant of initial_dir -> show relative path
  rel_path="${current_dir#"$initial_dir"/}"
  dir_display="$project_name (${rel_path}/)"
else
  # current_dir is outside initial_dir -> show full absolute path (with ~ for HOME)
  abs_path="$current_dir"
  if [ "${abs_path#"$HOME"/}" != "$abs_path" ]; then
    abs_path="~/${abs_path#"$HOME"/}"
  elif [ "$abs_path" = "$HOME" ]; then
    abs_path="~"
  fi
  dir_display="$project_name ($abs_path)"
fi

# Extract model name and reasoning effort level (effort absent on unsupported models)
# Collapse a "(1M context)" suffix into a compact "m" tag (e.g. "Opus 4.8 (1M context)" -> "Opus 4.8m")
model_name=$(echo "$input" | jq -r '(.model.display_name // empty) | gsub("\\s*\\(1M context\\)"; "m"; "i")')
effort_level=$(echo "$input" | jq -r '.effort.level // empty')

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
# Project-name color: ask orca-theme for a per-repo color (claudeCode.statusName
# in the repo's design/terminal-theme.json, else the repo's Orca badge color),
# falling back to the starship purple #cc44ff when there's no orca theme.
DIR_R=204; DIR_G=68; DIR_B=255  # #cc44ff default (matches starship prompt)
ORCA_THEME_BIN="$HOME/.config/orca/bin/orca-theme"
# orca_theme <subcommand> [args] -- run the CLI under a short timeout so a
# slow/hung `orca` (badge lookup) never freezes the statusline; the in-repo
# paths are orca-free and fast either way.
orca_theme() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 1 "$ORCA_THEME_BIN" "$@" 2>/dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout 1 "$ORCA_THEME_BIN" "$@" 2>/dev/null
  else
    "$ORCA_THEME_BIN" "$@" 2>/dev/null
  fi
}
if [ -x "$ORCA_THEME_BIN" ]; then
  theme_color=$(orca_theme statusline-color "$initial_dir")
  if [[ "$theme_color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    hex="${theme_color#\#}"
    DIR_R=$((16#${hex:0:2})); DIR_G=$((16#${hex:2:2})); DIR_B=$((16#${hex:4:2}))
  fi

  # Re-assert the pane's terminal colors (OSC 10/11/12/4) while Claude Code
  # owns the foreground. Orca recreates the renderer surface (on its default
  # background) when it restores / re-activates a pane, and the shell's own
  # precmd/TRAPWINCH repaint can't run until the TUI exits -- so every
  # statusline render pushes the theme again, straight to the controlling tty
  # (our stdout is the statusline text, not the terminal). Color-only OSC: no
  # cursor movement, nothing visible, one small write, so Ink doesn't notice.
  # Gated on ORCA_WORKTREE_ID so non-Orca terminals are never written to.
  if [ -n "${ORCA_WORKTREE_ID:-}" ]; then
    theme_osc=$(orca_theme osc)
    if [ -n "$theme_osc" ]; then
      { printf '%s' "$theme_osc" > /dev/tty; } 2>/dev/null
      if [ -n "${ORCA_THEME_DEBUG:-}" ]; then
        echo "$(date +%H:%M:%S) $$ statusline" >> "$ORCA_THEME_DEBUG"
      fi
    fi
  fi
fi
DIR_COLOR="\033[1;38;2;${DIR_R};${DIR_G};${DIR_B}m"
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

# Add model + effort on the right side in light grey, separated by an en dash
MODEL_COLOR="\033[90m"
if [ -n "$model_name" ]; then
  model_display="$model_name"
  if [ -n "$effort_level" ]; then
    model_display="${model_display}–${effort_level}"
  fi
  output="${output}  ${MODEL_COLOR}${model_display}${RESET}"
fi

echo -e "$output"
