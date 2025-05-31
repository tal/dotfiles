# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository managed with [chezmoi](https://chezmoi.io/), designed to configure macOS systems and manage software installations. The repository contains:

- Configuration files for various applications and tools
- Shell scripts for system preferences and automation
- Package management through Homebrew
- Terminal and developer environment setup

## Key Commands and Operations

### Chezmoi Management

```bash
# Apply changes from source state to destination state
chezmoi apply

# Add a new dotfile to chezmoi
chezmoi add ~/.filename

# Edit a dotfile managed by chezmoi
chezmoi edit ~/.filename

# Update dotfiles from the source repo
chezmoi update
```

### Package Management

```bash
# Install packages from Brewfile without upgrading existing packages
brew bundle install --file=Brewfile --no-upgrade

# Install DataDog-specific packages
brew bundle install --file=DDBrewfile --no-upgrade
```

## Repository Structure

### Naming Conventions

- `dot_` prefix: Files that should be hidden in the home directory (e.g., `.zshrc`)
- `private_` prefix: Files that contain sensitive information
- `run_` prefix: Executable scripts that run when chezmoi applies changes
- `run_onchange_` prefix: Scripts that run only when their contents change

### Key Directories and Files

- `run_onchange_*.sh` scripts: Configure system preferences and install software
- `private_dot_zshrc`: Shell configuration with various tools (starship, zoxide, fzf)
- `Brewfile` and `DDBrewfile`: Package lists for Homebrew installation
- `dot_config/`: Application configurations
- `private_Library/`: Application settings and preferences stored in macOS Library

## Development Workflow

1. Make changes to files in the chezmoi source directory
2. Test changes with `chezmoi apply`
3. Commit changes to the repository
4. On other machines, run `chezmoi update` to pull and apply changes

## Special Considerations

- The `run_onchange_` scripts run automatically when their content changes (tracked by the templated hash comment)
- System-specific files use the `.darwin` suffix for macOS-specific settings
- Some configurations contain private information and should be handled with care