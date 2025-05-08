#!/bin/bash

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
