#!/bin/bash

# Check if we have permission to access System Events, and prompt if not
check_permissions() {
    echo "Checking System Events permissions..."
    
    # Try to trigger the permission dialog by using System Events
    if ! osascript -e 'tell application "System Events" to keystroke "a"' 2>/dev/null; then
        echo "❌ Permission denied or dialog needs to be approved."
        echo ""
        echo "To trigger the permission dialog, you can:"
        echo "1. Run: osascript -e 'tell application \"System Events\" to keystroke \"a\"'"
        echo "2. Or reset permissions with: /usr/bin/tccutil reset AppleEvents"
        echo "3. Then restart your terminal and re-run this script"
        echo ""
        echo "If you see the permission dialog, click 'OK' to grant access."
        exit 1
    fi
    
    echo "✅ System Events permissions granted"
}

# Check permissions before proceeding
check_permissions

# Array of application names (without .app extension)
apps=(
  "Ice"
  "Rectangle Pro"
  "Velja"
  "LaunchBar"
  "Hammerspoon"
  "InYourFace"
)

for app in "${apps[@]}"; do
    app_path="/Applications/$app.app"

    if [[ ! -d "$app_path" ]]; then
        echo "❌ $app not found in /Applications"
        continue
    fi

    # Check if the app is already in login items
    exists=$(osascript <<EOF
tell application "System Events"
    return name of every login item contains "$app"
end tell
EOF
)

    if [[ "$exists" == "true" ]]; then
        echo "✅ $app is already in login items"
    else
        echo "➕ Adding $app to login items..."
        osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$app_path\", hidden:false}"
    fi
done

# Final check: list all login items
echo -e "\n📋 Current login items:"
osascript -e 'tell application "System Events" to get the name of every login item'
