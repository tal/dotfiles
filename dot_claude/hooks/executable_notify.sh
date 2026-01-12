#!/bin/bash
# Notification hook script for Claude Code
# Uses terminal-notifier to display notifications
# Opens the launching terminal/IDE when user clicks the notification

# Read JSON payload from stdin
payload=$(cat)

# Detect terminal/IDE and get its bundle identifier
detect_bundle_id() {
  # First, check if __CFBundleIdentifier is set (most reliable on macOS)
  if [ -n "$__CFBundleIdentifier" ]; then
    echo "$__CFBundleIdentifier"
    return
  fi

  # Check for JetBrains IDEs (they set TERMINAL_EMULATOR)
  if [ -n "$TERMINAL_EMULATOR" ]; then
    case "$TERMINAL_EMULATOR" in
      *JetBrains*)
        # Try to detect specific JetBrains IDE from other env vars or process
        if [ -n "$IDEA_INITIAL_DIRECTORY" ]; then
          echo "com.jetbrains.intellij"
          return
        fi
        # Default to IntelliJ if we can't determine the specific IDE
        echo "com.jetbrains.intellij"
        return
        ;;
    esac
  fi

  # Check for VSCode-specific environment variables
  if [ -n "$VSCODE_INJECTION" ] || [ -n "$VSCODE_GIT_ASKPASS_NODE" ] || [ -n "$TERM_PROGRAM" ] && [ "$TERM_PROGRAM" = "vscode" ]; then
    echo "com.microsoft.VSCode"
    return
  fi

  # Check for Cursor (VSCode fork)
  if [ -n "$CURSOR_TRACE_ID" ] || [ "$TERM_PROGRAM" = "cursor" ]; then
    echo "com.todesktop.230313mzl4w4u92"
    return
  fi

  # Fall back to TERM_PROGRAM detection
  case "$TERM_PROGRAM" in
    WarpTerminal)
      echo "dev.warp.Warp-Stable"
      ;;
    ghostty)
      echo "com.mitchellh.ghostty"
      ;;
    iTerm.app)
      echo "com.googlecode.iterm2"
      ;;
    Apple_Terminal)
      echo "com.apple.Terminal"
      ;;
    vscode)
      echo "com.microsoft.VSCode"
      ;;
    Hyper)
      echo "co.zeit.hyper"
      ;;
    alacritty)
      echo "org.alacritty"
      ;;
    kitty)
      echo "net.kovidgoyal.kitty"
      ;;
    tmux)
      # tmux: trace back through parent processes to find the terminal emulator
      if [ -n "$TMUX" ]; then
        # Get the tmux client PID
        client_pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null)
        if [ -n "$client_pid" ]; then
          # Trace parent processes to find a GUI app with a bundle ID
          current_pid=$client_pid
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            # Try to get bundle ID for this PID
            bundle_info=$(lsappinfo info -only bundleid -pid "$current_pid" 2>/dev/null)
            if [ -n "$bundle_info" ]; then
              # Extract bundle ID from output like: "CFBundleIdentifier"="com.example.App"
              found_bundle=$(echo "$bundle_info" | sed -n 's/.*"\(.*\)"$/\1/p')
              if [ -n "$found_bundle" ] && [ "$found_bundle" != "NULL" ]; then
                echo "$found_bundle"
                return
              fi
            fi
            # Get parent PID
            parent_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ')
            if [ -z "$parent_pid" ] || [ "$parent_pid" = "1" ] || [ "$parent_pid" = "0" ]; then
              break
            fi
            current_pid=$parent_pid
          done
        fi
      fi
      # Fallback: check LC_TERMINAL
      if [ -n "$LC_TERMINAL" ]; then
        case "$LC_TERMINAL" in
          iTerm2) echo "com.googlecode.iterm2" ;;
          *) echo "" ;;  # Unknown, trigger warning
        esac
      else
        echo ""  # Unknown, trigger warning
      fi
      ;;
    *)
      # Unknown terminal - return empty to trigger warning
      echo ""
      ;;
  esac
}

# Get the bundle identifier for the current terminal/IDE
BUNDLE_ID=$(detect_bundle_id)

# If we couldn't detect the terminal, show a warning notification
if [ -z "$BUNDLE_ID" ]; then
  terminal-notifier -message "Unsupported terminal/IDE: TERM_PROGRAM='$TERM_PROGRAM'" -title "Claude Code - Configuration Warning" -sound "Basso" &>/dev/null &
fi

# Extract fields from payload
message=$(echo "$payload" | jq -r '.message // "Notification from Claude"')
notification_type=$(echo "$payload" | jq -r '.notification_type // "unknown"')
cwd=$(echo "$payload" | jq -r '.cwd // ""')

# Append payload with timestamp to .jsonl file in cwd
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$payload" | jq -c --arg ts "$timestamp" '. + {timestamp: $ts}' >> "$cwd/claude-notifications.jsonl"
fi

# Set title and sound based on notification type
case "$notification_type" in
  "permission_prompt")
    title="Claude Code - Permission Required"
    sound="Glass"
    ;;
  "idle_prompt")
    title="Claude Code - Waiting for Input"
    sound="Purr"
    ;;
  "auth_success")
    title="Claude Code - Authentication"
    sound="Hero"
    ;;
  "elicitation_dialog")
    title="Claude Code - Input Needed"
    sound="Pop"
    ;;
  *)
    title="Claude Code"
    sound="default"
    ;;
esac

# Add project context to message if cwd is available
if [ -n "$cwd" ]; then
  # Use PROJECT_NAME env var if set, otherwise fall back to folder name
  if [ -n "$PROJECT_NAME" ]; then
    project_name="$PROJECT_NAME"
  else
    project_name=$(basename "$cwd")
  fi
  subtitle="$project_name"
  if [ -n "$BUNDLE_ID" ]; then
    terminal-notifier -message "$message" -title "$title" -subtitle "$subtitle" -activate "$BUNDLE_ID" -sound "$sound" &>/dev/null
  else
    terminal-notifier -message "$message" -title "$title" -subtitle "$subtitle" -sound "$sound" &>/dev/null
  fi
else
  if [ -n "$BUNDLE_ID" ]; then
    terminal-notifier -message "$message" -title "$title" -activate "$BUNDLE_ID" -sound "$sound" &>/dev/null
  else
    terminal-notifier -message "$message" -title "$title" -sound "$sound" &>/dev/null
  fi
fi

# Output standard hook response immediately
echo '{"continue": true}'
