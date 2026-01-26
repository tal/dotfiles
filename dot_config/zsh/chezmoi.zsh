# Chezmoi auto-commit and push wrapper
# Wraps 'chezmoi add' to automatically commit and push using Claude Code

function chezmoi() {
    # Find the real chezmoi binary, not this function
    local chezmoi_bin=$(whence -p chezmoi)

    # If the command is 'add', wrap it with auto-commit
    if [[ "$1" == "add" ]]; then
        shift
        local files=("$@")

        # Run the actual chezmoi add command
        echo "Adding files to chezmoi..."
        $chezmoi_bin add "${files[@]}"

        if [[ $? -eq 0 ]]; then
            local source_dir=$($chezmoi_bin source-path)

            # Check if there are changes to commit
            (
                cd "$source_dir"
                if [[ -n $(git status --porcelain) ]]; then
                    echo "\nCommitting changes with Claude Code..."
                    claude --dangerously-skip-permissions -p commit

                    if [[ $? -eq 0 ]]; then
                        echo "\nPushing to remote..."
                        git push
                    else
                        echo "\n❌ Commit failed. You can manually commit in: $source_dir"
                        return 1
                    fi
                else
                    echo "\n✓ No changes to commit"
                fi
            )
        else
            echo "❌ Failed to add files to chezmoi"
            return 1
        fi
    else
        # For all other chezmoi commands, just pass through
        $chezmoi_bin "$@"
    fi
}
