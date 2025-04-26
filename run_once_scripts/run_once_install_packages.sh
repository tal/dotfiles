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
echo "Installing dependencies from Brewfile..."
brew bundle --file="{{ .chezmoi.sourceDir }}/Brewfile"
