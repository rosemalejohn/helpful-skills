---
name: gitlab-pr
description: Create a GitLab merge request via the glab CLI. Use whenever the user wants to open an MR/PR on GitLab, "create a glab MR", "open a merge request", "submit my branch to GitLab", or any phrasing that implies pushing the current branch up for review on GitLab. Trigger even if the user says "PR" instead of "MR" — on GitLab they are the same thing. Always asks the user for the target branch, diffs against origin/<target>, then generates the MR title and a structured body with Added / Changed / Removed sections derived from the actual diff.
allowed-tools: Bash, Read
---

# Create a GitLab Merge Request with glab

## Overview

Open a GitLab merge request for the current branch using the `glab` CLI. The MR title is generated from a diff summary, and the body follows a fixed template with Added / Changed / Removed sections grounded in the real diff against the target branch.

## When to use

- User asks to "create an MR", "open a PR on GitLab", "submit my branch", "glab pr", or similar.
- User mentions GitLab in a code-review/submission context.

If the project is hosted on GitHub instead of GitLab, do not use this skill — use the standard `gh pr create` flow.

## Prerequisites — check briefly, fix only if broken

1. `glab` is installed: `command -v glab`
2. `glab` is authenticated: `glab auth status` (only re-auth if it errors)
3. The current directory is a git repo with a GitLab remote: `git remote -v | grep -i gitlab`

If any check fails, surface the exact failure to the user and stop — don't guess past missing auth or a missing remote.

## Workflow

### Step 1 — Ask the target branch

Always ask the user which branch the MR should target. Do not assume `main`, `master`, or `develop` — projects vary, and picking the wrong base produces a noisy diff.

Phrase it simply: "What branch should this MR target?" Offer a sensible guess based on `git remote show origin | grep 'HEAD branch'` if useful, but require confirmation.

### Step 2 — Make sure the target ref is fresh

Fetch the target so the diff reflects current upstream:

```bash
git fetch origin <target-branch>
```

If the fetch fails (e.g. branch doesn't exist on origin), stop and tell the user — do not silently fall back to a different base.

### Step 3 — Diff the current branch against origin/<target>

Use the three-dot form so the diff shows only what this branch adds relative to the merge base, not unrelated upstream changes:

```bash
git diff origin/<target-branch>...HEAD --stat
git diff origin/<target-branch>...HEAD
git log origin/<target-branch>..HEAD --oneline
```

Read both the stat (for scope) and the full diff (for content). The commit log helps disambiguate intent when the diff alone is ambiguous.

### Step 4 — Check that the branch is pushed

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
```

If there is no upstream, or `git status` shows unpushed commits, **ask the user before pushing**:

> "Your branch isn't on origin yet (or has unpushed commits). Push `<branch>` to origin now?"

Only push after the user confirms. Use `git push -u origin <branch>` for a first-time push.

### Step 5 — Generate the MR title

Derive a short, concise title from the diff summary — not a copy of the latest commit message. Aim for under 70 characters, imperative mood, no trailing period.

Examples:
- Diff adds a new endpoint and a migration → `Add favorite players endpoint and migration`
- Diff fixes a bug in queue retry logic → `Fix retry backoff on failed notification jobs`
- Diff renames a service class and updates callers → `Rename PlayerService to AthleteService`

If the diff genuinely covers multiple unrelated themes, pick the dominant one and let the body cover the rest — don't cram everything into the title.

### Step 6 — Build the MR body

Use this exact template. Every section header is required even if empty (write `_None_` under empty sections so the structure is visible at a glance):

```
{Short and concise description}

# Added

- ...

# Changed

- ...

# Removed

- ...
```

**How to classify diff entries:**

- **Added** — new files, new functions/classes/methods, new routes, new migrations, new config keys, new dependencies, new tests for new behavior.
- **Changed** — modifications to existing logic, signature changes, behavior changes, refactors, renames, updates to existing config, dependency version bumps, updated tests for existing behavior.
- **Removed** — deleted files, deleted functions/methods, removed routes, removed config keys, removed dependencies, removed tests.

A rename usually shows up as Removed + Added in the raw diff but should be reported as one **Changed** entry (e.g. "Rename `PlayerService` → `AthleteService`"). Apply the same judgment to file moves.

Keep bullets concrete and reader-facing: name the files, routes, classes, or features. Don't write "Made improvements" or "Updated code" — those are noise. A reviewer should be able to read the body and know what to look at.

Keep the description line short — one sentence that frames the why. Save the what for the bullets.

### Step 7 — Create the MR

Pass the body via stdin or a heredoc so multi-line markdown survives:

```bash
glab mr create \
  --target-branch <target-branch> \
  --title "<generated title>" \
  --description "$(cat <<'EOF'
{description}

# Added

- ...

# Changed

- ...

# Removed

- ...
EOF
)"
```

Notes:
- Do **not** pass `--fill` — it overrides the carefully built title/body with commit messages.
- Do **not** pass `--draft` unless the user asked for a draft MR.
- Do **not** pass `--squash`, `--remove-source-branch`, or assignee/reviewer flags unless the user requested them. Defer to the project's GitLab settings.

### Step 8 — Return the MR URL

`glab mr create` prints the URL on success. Surface it to the user as a clickable line so they can open it. If creation fails, show the raw error — common causes are missing push, missing remote, or an existing MR for the same branch (in which case suggest `glab mr view` or updating the existing MR instead).

## Style guarantees

- Title: under 70 chars, imperative mood, no period, no conventional-commit prefix unless the project uses them in MR titles.
- Description: one sentence, present tense, focuses on the why.
- Bullets: each starts with a verb (`Add`, `Update`, `Remove`, `Rename`, `Extract`, `Inline`, `Bump`, …), names specific files or symbols, no end-of-line punctuation required but be consistent.
- Don't invent changes that aren't in the diff. If a section is empty, write `_None_` and move on.

## Example

User: "open a GitLab MR for this branch"

You: "What branch should this MR target?"

User: "develop"

You then run the diff/log commands against `origin/develop...HEAD`, confirm the branch is pushed, generate something like:

```
Add user favorite players feature with toggle endpoint

# Added

- `POST /api/v1/players/{player}/favorite` endpoint in `routes/api.php`
- `UserFavoritePlayer` model + migration `2026_06_06_000000_create_user_favorite_players_table.php`
- Feature test coverage in `tests/Feature/FavoritePlayerTest.php`

# Changed

- `User` model gains `favoritePlayers()` BelongsToMany relationship
- `PlayerResource` now includes an `is_favorited` attribute

# Removed

_None_
```

…and call `glab mr create --target-branch develop --title "…" --description "…"`, then return the URL.
