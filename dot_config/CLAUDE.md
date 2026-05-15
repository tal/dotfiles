# ~/.config Directory Guide

> **CRITICAL: This directory (`~/.config/`) is the PRIMARY working directory. When the user asks you to make config changes, edit settings, or modify any application configuration, ALWAYS look here FIRST. Do NOT search elsewhere in the filesystem before checking this directory. This is where the config files live.**

This is a macOS development environment configuration directory managed with [chezmoi](https://chezmoi.io/).

**This directory IS `~/.config/`.** When looking for any application config file — especially those listed in the Directory Reference below — always look here first using relative paths (e.g., `ghostty/config`, `zed/settings.json`, `karabiner/karabiner.json`). Do NOT search elsewhere in the filesystem for config files that live in `~/.config/`.

## Chezmoi-Tracked Files

The following paths under `~/.config/` are tracked by chezmoi: `bin/`, `Brewfile`, `CLAUDE.md`, `cmux/`, `ghostty/`, `karabiner/`, `leader-key/`, `lsd/`, `ripgrep/`, `starship.toml`, `tuna/`, `zed/`, `zsh/`.

After editing any of these files, ask the user if they would like to sync the changes to chezmoi. To sync: copy the edited file to its chezmoi source path (use `chezmoi source-path <file>` to find it), then run `chezmoi apply`.

## Editing ~/.zshrc

To edit `~/.zshrc`, make changes to the chezmoi source file at `~/.local/share/chezmoi/dot_zshrc` (available via `additionalDirectories`), then run `chezmoi apply` to apply the change to the actual `~/.zshrc`.

## Directory Reference

### Shell & Terminal

- **cmux/** - cmux terminal multiplexer helper config (`cmux.json` main config, `settings.json` settings, `notification-sound.sh` notification script).
- **zsh/** - Zsh configuration files auto-sourced by `~/.zshrc`. Contains aliases (`aliases.zsh`), shell functions like `mkcd`, `extract`, `backup` (`functions.zsh`), tab completions for the `cc` function (`completions.zsh`), a quick Claude question helper `q()` (`claude.zsh`), and ngrok completions (`ngrok.zsh`).
- **zplug-helpers/** - Custom Zsh plugin scripts: colored `ls` output, `.git/safe` PATH helper, and yarn/bin PATH exports.
- **starship.toml** - Starship prompt config (disables Node.js/gcloud indicators, shows AWS profile).
- **tmux/** - Tmux terminal multiplexer configuration.
- **ghostty/** - Ghostty terminal emulator config (Cobalt2 theme, focus-follows-mouse, split pane settings).
- **iterm2/** - Symlink to iTerm2 application support directory.

### Development Tools

- **git/** - Global git ignore patterns.
- **gh/** - GitHub CLI (`gh`) configuration and host auth.
- **graphite/** - Graphite CLI config for Git stacking workflows (aliases, user settings).
- **gcloud/** - Google Cloud SDK config, credentials, and active project settings.
- **flutter/** - Flutter SDK tool state.
- **tuist/** - Tuist (Xcode project generator) credentials.
- **github-copilot/** - GitHub Copilot extension settings.

### Editors

- **zed/** - Zed editor settings (Cobalt2 dark theme, AI conversations, custom prompts).

### System Utilities

- **karabiner/** - Karabiner-Elements keyboard remapping rules and complex modifications.
- **aerospace/** - AeroSpace tiling window manager configuration.
- **leader-key/** - Leader-key launcher config mapping key chords to apps (Arc, Slack, Spotify, etc.).
- **htop/** - htop process monitor display preferences.
- **nnn/** - nnn file manager bookmarks, plugins, sessions.
- **lsd/** - LSD (LSDeluxe) file lister config (tree layout, fancy icons, git column, date/size display).
- **ripgrep/** - Global ripgrep ignore patterns (node_modules, dist, .git, IDE files, etc.).
- **tuna/** - Tuna launcher config (leader-mode key chords to apps, smart links, catalog settings).

### Package Management

- **Brewfile** - Homebrew bundle manifest (~250 packages, casks, and VS Code extensions).
- **Brewfile.bak** - Backup of a previous Brewfile.
- **Gemfile / Gemfile.lock** - Ruby deps for the dotfiles automation scripts (`pastel`, `tty-command`).
- **yarn/** - Yarn global packages.

### Dotfiles & Automation

- **chezmoi/** - Chezmoi config (`chezmoi.toml` with age encryption, editor, git settings) and state DB.
- **dotfiles/** - Dotfiles repo with Brewfile, gitconfig, gitignore, SSH keys, p10k theme.
- **dotfiles.old/** - Legacy zshrc backup.
- **scripts/** - Ruby scripts for dotfiles linking, backup management, and installation orchestration.
- **install.yml** - Installation manifest for Xcode, Homebrew, RVM, Zplug, iTerm2, Janus.
- **backup/** - Tar.gz archives of app configs (VS Code, iTerm2, BetterTouchTool, Firefox, etc.).

### Security & Auth

- **age/** - Age encryption key used by chezmoi for encrypting secrets.
- **op/** - 1Password CLI config and daemon socket.
- **hub** - Legacy GitHub API auth config (github.tumblr.net).

### Misc

- **bin/** - Custom scripts: `dotenv` (load .env files), `trim-png` (image optimization).
- **configstore/** - Auto-generated config for npm CLI tools (Firebase, ngrok, yo).
- **simple-update-notifier/** - Update check timestamps for nodemon.
- **gatsby/** - Gatsby.js telemetry settings.
- **changelog/** - Change documentation files (YYYY-MM-DD_description.md format).
- **claude-notifications.jsonl** - Claude Code notification/session log.
