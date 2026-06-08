---
name: merging-branch-to-staging
description: Use when the user wants to merge, ship, or promote their current working/feature branch into the staging branch and push it to origin — including "merge this to staging", "push my branch to staging", "deploy to staging", "update staging with my branch".
---

# Merging Branch to Staging

## Overview

Promotes the current working branch into `staging` by syncing local `staging` to
`origin/staging` first (hard reset), merging the working branch, pushing, and
returning to the working branch. The hard reset guarantees `staging` always
mirrors origin before the merge, so no stale local commits leak in.

**Destructive step:** `git reset --hard origin/staging` discards any local-only
commits on `staging`. That is intentional — `staging` is treated as a
disposable mirror of origin.

## When to Use

- "Merge my branch to staging" / "ship this to staging" / "update staging"
- Working from a feature/working branch that is ready to land on staging

**Do NOT use when:**
- You are merging into `develop`, `main`, or any branch other than `staging`
- You are already on `staging` (run it from the working branch)
- The working branch has uncommitted work you are not ready to ship

## Workflow

Run the helper script from the working branch:

```bash
~/.claude/skills/merging-branch-to-staging/merge-to-staging.sh
```

It performs, in order, aborting on first failure:

1. **Capture** the current branch as the working branch (abort if on `staging` or detached HEAD).
2. **Verify clean tree** — abort if there are uncommitted/unstaged changes.
3. **Update working branch** from its remote (`git pull --ff-only`; skipped with a warning if no upstream).
4. `git checkout staging`
5. `git fetch origin`
6. `git reset --hard origin/staging`
7. `git merge <working-branch>` — on conflict, abort the merge, return to the working branch, and report.
8. `git push origin staging` — **if the push fails, report the error to the user** (the script still returns to the working branch first).
9. `git checkout <working-branch>` — always runs, even after a failed push.

## Reporting Back

- **Push failed:** Surface the exact push error to the user (e.g. protected branch,
  non-fast-forward, auth). Do not silently retry — the user decides next steps.
- **Merge conflict:** Tell the user the merge was aborted and they are back on the
  working branch; conflicts must be resolved before retrying.
- **Dirty tree:** Tell the user which files are dirty; they must commit or stash first.

## Common Mistakes

| Mistake | Consequence |
|---------|-------------|
| Running while on `staging` | No working branch to merge — script aborts. |
| Ignoring a failed push | User thinks staging updated when it did not. Always report. |
| Skipping the clean-tree check | Reset/checkout would clobber or block on local changes. |
| Force-pushing on push failure | Never. Report the error and let the user decide. |
