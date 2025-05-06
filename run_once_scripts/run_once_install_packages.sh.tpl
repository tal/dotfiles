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
HOMEBREW_BUNDLE_FILE="{{ .chezmoi.sourceDir }}/Brewfile"
if [ ! -f "$HOMEBREW_BUNDLE_FILE" ]; then
    echo "Brewfile not found at $HOMEBREW_BUNDLE_FILE. Skipping installation of dependencies."
    exit 1
fi
# Install dependencies from Brewfile
echo "Installing dependencies from Brewfile at $HOMEBREW_BUNDLE_FILE..."
brew bundle install
if [ $? -ne 0 ]; then
    echo "Failed to install dependencies from Brewfile."
    exit 1
fi
echo "Dependencies installed successfully from Brewfile."
