---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git log:*)
description: Create multiple git commit
---

## Context
- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task
Based on the above changes, create a single git commit.

## 1. Assessment Phase
- Read the context of the current git branch.
- Analyze changes to identify logical groupings for atomic commits

## 2. Atomic Commit Strategy
Prioritize multiple atomic commits over single large commits. Group changes by:
- **Feature boundaries**: Each new feature gets its own commit
- **File type**: Proto changes separate from generated code
- **Functional areas**: API changes vs implementation vs tests
- **Dependencies**: Changes that depend on each other vs independent changes

## 3. Commit Process
For each atomic group:

### A. Stage files selectively:
```bash
git add <specific-files-for-this-commit>

B. Generate commit message with this format:

<type>(<scope>): <brief description>

- <bullet point explaining what changed>
- <bullet point explaining why it changed>
- <bullet point for each major modification>
- <bullet point for any breaking changes or deprecations>
- <bullet point for generated/auto-updated files if relevant>

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>

C. Commit with heredoc:

git commit -m "$(cat <<'EOF'
[commit message here]
EOF
)"

D. Verify with git status

4. Commit Types

- feat: New features
- fix: Bug fixes
- refactor: Code restructuring without functionality change
- docs: Documentation changes
- test: Test additions/modifications
- chore: Build, dependencies, generated files
- style: Formatting, whitespace
- perf: Performance improvements

5. Generated Files Strategy

- Separate commit: If generated files are substantial (like protobuf bindings)
- Combined commit: If generated files are small and tightly coupled
- Always mention: In bullet points when generated files are included

6. Examples of Good Atomic Commits

Instead of one large commit:
feat: Add user authentication system with OAuth and database schema

Prefer multiple atomic commits:
1. feat(auth): Add OAuth configuration and middleware
2. feat(database): Add user authentication schema and migrations
3. feat(api): Add authentication endpoints and validation
4. chore(proto): Update user service protobuf definitions
5. chore(generated): Regenerate protobuf bindings for user service

7. Automation Triggers

Execute this process when:
- User explicitly asks to commit changes
- You see git status showing uncommitted changes during development
- After completing a development task
- Before creating pull requests

8. Quality Checks

Before each commit:
- Ensure commit message is descriptive and follows format
- Verify only related files are staged
- Check that commit represents one logical change
- Confirm generated files are properly attributed

Important ! If git command fails STOP immediatly.

Always prefer clarity and atomicity over convenience - multiple small, focused commits are better than one large commit.
