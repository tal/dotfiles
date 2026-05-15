#!/bin/sh
# cmux notification command: plays per-type sounds for Claude Code events.
# Wired in ~/.config/cmux/settings.json via notifications.command.
# Receives CMUX_NOTIFICATION_{TITLE,SUBTITLE,BODY} via environment.

set -u

SOUNDS_DIR="/System/Library/Sounds"
LOG_FILE="$HOME/.config/cmux/notification-sound.log"

# cmux always sets TITLE="Claude Code" for CC notifications and encodes
# the notification_type in SUBTITLE. Verified by probing with
# `cmux claude-hook notification` for each notification_type:
#
#   permission_prompt   -> SUBTITLE="Permission"
#   idle_prompt         -> SUBTITLE="Waiting"
#   auth_success        -> SUBTITLE="Completed"
#   elicitation_dialog  -> SUBTITLE="Attention"
#   (unknown)           -> SUBTITLE="Attention"
#
# Note: `elicitation_dialog` and unknown types both map to "Attention" —
# cmux cannot distinguish them from the subtitle alone. If you need that
# distinction, read the Claude Code hook JSON directly in a parallel
# Notification hook and dispatch sounds from there instead.
subtitle="${CMUX_NOTIFICATION_SUBTITLE:-}"

# Sounds chosen to be sonically distinct from each other so the type is
# instantly recognizable by ear. Edit here to change.
case "$subtitle" in
  "Permission") sound="$SOUNDS_DIR/Submarine.aiff" ;;  # deep sonar — needs approval
  "Waiting")    sound="$SOUNDS_DIR/Frog.aiff" ;;       # croak — patient idle
  "Completed")  sound="$SOUNDS_DIR/Hero.aiff" ;;       # fanfare — success
  "Attention")  sound="$SOUNDS_DIR/Sosumi.aiff" ;;     # long tone — input needed
  *)            sound="$SOUNDS_DIR/Tink.aiff" ;;       # fallback for anything else
esac

# Log every invocation with full payload + relevant env for debugging/tuning.
{
  printf '=== %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'TITLE:    %s\n' "${CMUX_NOTIFICATION_TITLE:-}"
  printf 'SUBTITLE: %s\n' "${CMUX_NOTIFICATION_SUBTITLE:-}"
  printf 'BODY:     %s\n' "${CMUX_NOTIFICATION_BODY:-}"
  printf 'SOUND:    %s\n' "$sound"
  printf -- '--- cmux env ---\n'
  env | grep -E '^(CMUX_|TERM|TERM_PROGRAM|TMUX|PWD|USER)' | sort
  printf '\n'
} >> "$LOG_FILE" 2>&1

# Play asynchronously so cmux isn't blocked.
afplay "$sound" >/dev/null 2>&1 &
exit 0
