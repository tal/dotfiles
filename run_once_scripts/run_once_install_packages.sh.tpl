#!/bin/bash

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew already installed."
fi

# Make sure we're using the latest Homebrew
brew update

# Install all dependencies from Brewfile
BREWFILE_PATH="{{ .chezmoi.sourceDir }}/Brewfile"
if [ ! -f "$BREWFILE_PATH" ]; then
    echo "Brewfile not found at $BREWFILE_PATH. Skipping installation of dependencies."
    exit 1
fi
# Install dependencies from Brewfile
echo "Installing dependencies from Brewfile at $BREWFILE_PATH..."
brew bundle --file="$BREWFILE_PATH" --no-lock --no-upgrade
if [ $? -ne 0 ]; then
    echo "Failed to install dependencies from Brewfile."
    exit 1
fi
echo "Dependencies installed successfully from Brewfile."
