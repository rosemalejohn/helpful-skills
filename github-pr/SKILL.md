---
name: github-pr
description: Use when the user wants to open, create, or submit a pull request (PR/MR) on GitHub for the current branch using the GitHub CLI. Triggers on "create a PR", "open a pull request", "submit my branch", "gh pr".
metadata:
  version: "1.0.0"
---

# Create GitHub PR

## Overview

Creates a pull request on GitHub for the current branch using the `gh` CLI, with a concise, structured body. The PR body is generated from the real diff between the current branch and the **target branch on origin** — not from guesses.

## Workflow

Follow these steps in order. Do not skip the target-branch question.

### 1. Verify `gh` is installed

```bash
gh --version
```

If the command is not found, STOP and guide the user to install it (do not attempt to create the PR):

- **macOS:** `brew install gh`
- **Linux/Windows/other:** point to https://github.com/cli/cli#installation

After install, they must authenticate once: `gh auth login`. Then resume.

### 2. Always ask the user for the target branch

This is REQUIRED every time — never assume `main`, `develop`, or the repo default.

> "What is the target branch for this PR?"

Wait for the answer before continuing.

### 3. Diff the current branch against the target on origin

```bash
git fetch origin <target>
git diff origin/<target>...HEAD --stat
git diff origin/<target>...HEAD
```

Use this real diff as the sole basis for the PR body. If the diff is empty, tell the user there are no changes against `origin/<target>` and stop.

### 4. Write the PR body in this exact format

```
{Short and concise description}

# Added

- ...

# Changed

- ...

# Removed

- ...
```

Rules:
- First line: one short, concise sentence describing the change. No heading.
- Use only the sections that apply. Omit `# Added`, `# Changed`, or `# Removed` entirely if there's nothing for them.
- Bullets are terse and factual — straight to the point, no filler, no marketing language, no restating the obvious.

### 5. Create the PR

```bash
gh pr create --base <target> --title "<short description>" --body "<formatted body>"
```

Return the PR URL that `gh` prints.

## Quick Reference

| Step | Command |
|------|---------|
| Check CLI | `gh --version` |
| Fetch target | `git fetch origin <target>` |
| Diff | `git diff origin/<target>...HEAD` |
| Create | `gh pr create --base <target> --title "..." --body "..."` |

## Common Mistakes

- **Assuming the target branch.** Always ask. The base must match the user's answer.
- **Generating the body from commit messages or memory instead of the diff.** Use `git diff origin/<target>...HEAD`.
- **Verbose bodies.** Keep the description to one line and bullets terse.
- **Including empty sections.** Drop any of Added/Changed/Removed that have no items.
- **Proceeding without `gh`.** If not installed, guide installation and stop.
