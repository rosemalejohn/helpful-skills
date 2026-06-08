#!/usr/bin/env bash
#
# Merge the current working branch into staging.
#
# Steps (in order, abort on first failure):
#   1. Refuse to run if the working branch has uncommitted/unstaged changes.
#   2. Update the working branch from its remote.
#   3. Checkout staging.
#   4. git fetch origin.
#   5. git reset --hard origin/staging.
#   6. git merge the working branch.
#   7. git push origin staging (report clearly if this fails).
#   8. Checkout back to the working branch (always, even on push failure).
#
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Step 0: capture working branch -----------------------------------------
WORKING_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$WORKING_BRANCH" = "HEAD" ] && die "Detached HEAD — checkout a working branch first."
[ "$WORKING_BRANCH" = "staging" ] && die "Already on staging. Run this from your working branch."
echo "Working branch: $WORKING_BRANCH"

# --- Step 1: working tree must be clean -------------------------------------
if [ -n "$(git status --porcelain)" ]; then
    git status --short
    die "Working branch has uncommitted/unstaged changes. Commit or stash them first."
fi

# --- Step 2: update working branch from remote ------------------------------
if git rev-parse --abbrev-ref "@{upstream}" >/dev/null 2>&1; then
    echo "Updating $WORKING_BRANCH from remote..."
    git pull --ff-only || die "Could not fast-forward $WORKING_BRANCH from remote. Resolve manually."
else
    echo "WARNING: $WORKING_BRANCH has no upstream — skipping remote update."
fi

# --- Steps 3-6: sync staging to remote, then merge --------------------------
echo "Checking out staging..."
git checkout staging

echo "Fetching origin..."
git fetch origin

echo "Resetting staging to origin/staging..."
git reset --hard origin/staging

echo "Merging $WORKING_BRANCH into staging..."
if ! git merge "$WORKING_BRANCH"; then
    git merge --abort 2>/dev/null || true
    git checkout "$WORKING_BRANCH"
    die "Merge of $WORKING_BRANCH into staging failed (conflicts). Aborted and returned to $WORKING_BRANCH."
fi

# --- Step 7: push -----------------------------------------------------------
echo "Pushing staging to origin..."
PUSH_OK=1
git push origin staging || PUSH_OK=0

# --- Step 8: always return to working branch --------------------------------
echo "Returning to $WORKING_BRANCH..."
git checkout "$WORKING_BRANCH"

if [ "$PUSH_OK" -eq 0 ]; then
    die "Push to origin staging FAILED. Returned to $WORKING_BRANCH. Report the push error to the user."
fi

echo "Done. $WORKING_BRANCH merged into staging and pushed. Back on $WORKING_BRANCH."
