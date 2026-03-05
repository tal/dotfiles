#!/bin/zsh
set -euo pipefail

INPUT=$(cat)
NAME=$(jq -r '.name' <<< "$INPUT")
CWD=$(jq -r '.cwd' <<< "$INPUT")

# Create the git worktree (detached HEAD)
WORKTREE_PATH="${TMPDIR:-/tmp}/claude-worktrees/$NAME"
mkdir -p "${WORKTREE_PATH:h}"
git -C "$CWD" worktree add --detach "$WORKTREE_PATH" >&2

# ── Hardcoded patterns to always symlink (.gitignore-style wildcards) ──
symlink_patterns=(
    '.env'
    '.env.*'
    '.envrc'
    '.tool-versions'
    '.nvmrc'
    '.node-version'
    '.ruby-version'
    '.python-version'
    '.mise.toml'
    '.mise.*.toml'
    '.secrets'
    '.secrets.*'
)

# Match patterns against project root and symlink hits
cd "$CWD"
() {
    setopt localoptions nullglob
    for pattern in $symlink_patterns; do
        for file in ${~pattern}; do
            [[ -e "$file" ]] || continue
            target="$WORKTREE_PATH/$file"
            [[ -e "$target" || -L "$target" ]] && rm -rf "$target"
            ln -s "$CWD/$file" "$target"
            print -u2 "Symlinked (pattern): $file"
        done
    done
}

# ── Symlink gitignored items from .claude/ ──
source_claude="$CWD/.claude"
target_claude="$WORKTREE_PATH/.claude"

if [[ -d "$source_claude" ]]; then
    mkdir -p "$target_claude"

    # *(DN) = include Dotfiles + Nullglob
    for item in "$source_claude"/*(DN); do
        basename="${item:t}"
        rel_path=".claude/$basename"

        if git -C "$CWD" check-ignore -q "$rel_path" 2>/dev/null; then
            target="$target_claude/$basename"
            [[ -e "$target" || -L "$target" ]] && rm -rf "$target"
            ln -s "$item" "$target"
            print -u2 "Symlinked (gitignored): $rel_path"
        fi
    done

    # ── Symlink *.local.* files recursively under .claude/ ──
    () {
        setopt localoptions nullglob globdots
        for file in "$source_claude"/**/*.local.*; do
            rel="${file#$source_claude/}"
            target="$target_claude/$rel"
            mkdir -p "${target:h}"
            [[ -e "$target" || -L "$target" ]] && continue  # already handled above
            ln -s "$file" "$target"
            print -u2 "Symlinked (local): .claude/$rel"
        done
    }
fi

# Output the worktree path (hook contract)
print "$WORKTREE_PATH"
