# 2026-09-04 — ideas-sync LaunchAgent (auto-pull every 15 min)

Automates pulling ideas that **bee1** (or any peer) pushes to `origin/main` of the
`~/Documents` repo, so this Mac stays current without manual `git pull`.

## Files added (chezmoi source)

| Source path | Target | Notes |
| --- | --- | --- |
| `dot_config/ideas-sync/executable_pull.sh.tmpl` | `~/.config/ideas-sync/pull.sh` | The sync script. `+x`, `homeDir` templated. |
| `private_Library/LaunchAgents/com.tal.ideas-sync.plist.tmpl` | `~/Library/LaunchAgents/com.tal.ideas-sync.plist` | `StartInterval` 900s, `RunAtLoad`, background/low-prio, PATH+HOME set for launchd. |
| `run_onchange_after_reload-ideas-sync.sh.tmpl` | (script) | `launchctl bootout`+`bootstrap` whenever the plist hash changes, so `chezmoi apply` self-activates on any machine. |

## Behavior (safe by design)

- `git -c gc.auto=0 fetch` then a **fast-forward-only** merge.
- **Up to date** → silent. **Origin ahead** → ff-merge + log. **Local ahead / diverged**
  → does nothing, logs `diverged … skipping`. Never rewrites history, never fights a
  dirty working tree.
- Log: `~/.local/state/ideas-sync.log`. LFS smudges automatically on ff (git-lfs on PATH).

## Activation done this session

`chezmoi apply` (targeted) → `launchctl bootstrap gui/501 … && enable` → `kickstart -k`.
First run correctly logged `diverged` (local was 2 commits ahead of origin) and left the
repo at `ad7206b` untouched.

## Verified beforehand

- Headless SSH auth to `origin` works (BatchMode ls-remote succeeded) — launchd can fetch
  non-interactively thanks to `UseKeychain yes` on `~/.ssh/id_rsa`.
- git + git-lfs live in `/opt/homebrew/bin` (baked into the plist PATH).

## Not committed

New chezmoi-source files are applied but **left uncommitted** in the chezmoi repo (which
already had unrelated modified `dot_config/zsh/*` files). Commit when ready — don't sweep
the zsh edits in unintentionally.
