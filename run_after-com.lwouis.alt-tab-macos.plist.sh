#!/bin/bash

# Only run if this specific file was changed
if echo "$CHEZMOI_CHANGED_FILES" | grep -q "Library/Preferences/com.lwouis.alt-tab-macos.plist"; then
  echo "AltTab preferences changed, restarting AltTab..."

  # Quit AltTab if running
  osascript -e 'tell application "AltTab" to quit'

  # Give it a moment to shut down
  sleep 1

  # Relaunch AltTab
  open -a AltTab
else
  echo "AltTab preferences not changed, skipping restart."
fi
