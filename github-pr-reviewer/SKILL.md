---
name: github-pr-reviewer
description: >
  Use when the user wants to review a GitHub pull request AND optionally post the
  review back to it — "review this PR and comment", "review PR 123", "review the diff
  and post it", "gh pr review", or /github-pr-reviewer. Generates terse, actionable
  inline comments, then asks before posting them to the PR via gh CLI as the
  authenticated user. Auto-triggers when reviewing a GitHub pull request.
metadata:
  version: "1.0.0"
---

# GitHub PR Reviewer

## Overview

Two phases:

1. **Review** — read the PR diff, write terse, actionable, one-line-per-finding comments (caveman-review style: location, problem, fix — no throat-clearing).
2. **Post (opt-in)** — ask the user whether to publish the findings as **inline** review comments on the PR via `gh`, on behalf of the current authenticated GitHub user.

Never post without an explicit yes. Posting is publishing public content on the user's behalf — the confirmation gate is mandatory, not optional.

## Phase 1 — Generate the review

### Get the diff (with real line numbers)

```bash
gh pr diff <number>          # unified diff; note the file paths and new-file line numbers
gh pr view <number> --json title,url,headRefName,files
```

Line numbers in your findings MUST be the **new-file** line numbers shown in the diff hunks (the `+` side). You will reuse these exact numbers when posting, and GitHub rejects comments on lines outside the diff hunks.

### Comment format

`L<line>: <problem>. <fix>.` — or `<file>:L<line>: ...` across multiple files.

Severity prefix when findings are mixed:
- `🔴 bug:` — broken behavior, will cause an incident
- `🟡 risk:` — works but fragile (race, missing null check, swallowed error)
- `🔵 nit:` — style, naming, micro-optim; author may ignore
- `❓ q:` — genuine question, not a suggestion

**Drop:** "I noticed that…", "It seems like…", "You might want to consider…", "Great work!", restating what the line does, hedging ("perhaps", "maybe", "I think" → use `q:`).

**Keep:** exact line numbers, exact symbol names in backticks, a concrete fix (not "consider refactoring"), and the *why* when the fix isn't obvious.

**Examples**

❌ "I noticed that on line 42 you're not checking if the user is null before accessing email…"
✅ `L42: 🔴 bug: user can be null after .find(). Add guard before .email.`

❌ "This function is doing a lot and might benefit from being broken up."
✅ `L88-140: 🔵 nit: 50-line fn does 4 things. Extract validate/normalize/persist.`

**Auto-clarity:** drop terse mode for security (CVE-class) findings, architectural disagreements, and onboarding contexts — write a normal paragraph there, then resume terse.

Output the full list to the user in chat first. This is what they approve.

## Phase 2 — Ask, then post

### Always ask first

After presenting the findings, ask the user (offer these choices):

- **Post all** inline to the PR
- **Select a subset** to post (they name which)
- **Skip** — leave the review in chat only

Name the target: which PR number, and that comments post as the authenticated user (`gh auth status` shows who). Wait for a clear answer. No answer / anything ambiguous → do NOT post.

### Build the review payload

One API call posts all inline comments as a single review. Write a JSON file — do not hand-concatenate strings, quoting will break.

```json
{
  "event": "COMMENT",
  "body": "Automated review — see inline comments.",
  "comments": [
    { "path": "app/Actions/FooAction.php", "line": 42, "side": "RIGHT", "body": "🔴 bug: `user` can be null after `.find()`. Guard before `.email`." },
    { "path": "app/Actions/FooAction.php", "start_line": 88, "line": 140, "side": "RIGHT", "body": "🔵 nit: 50-line fn does 4 things. Extract validate/normalize/persist." }
  ]
}
```

- `event`: always `COMMENT`. Never `APPROVE` or `REQUEST_CHANGES` — this skill reviews, it does not gate merges.
- `side`: `RIGHT` for added/current lines, `LEFT` for removed/old lines.
- Multi-line: add `start_line` (and `start_side`) with `line` as the end.
- Only include the findings the user approved.

### Post

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api --method POST "repos/$OWNER_REPO/pulls/<number>/reviews" --input review.json
```

Report the returned review URL to the user. If it errors, show the raw error — do not retry blindly.

## Common mistakes

| Problem | Fix |
|---|---|
| `422 ... line must be part of the diff` | The line isn't in a diff hunk. Only comment on changed/adjacent lines shown in `gh pr diff`. |
| Comment lands on wrong line | Used old-file line with `side: RIGHT`. Use new-file numbers for RIGHT, old-file for LEFT. |
| Whole review posts as one bottom comment | Findings went in `body` instead of the `comments[]` array. Each inline note is its own `comments[]` entry. |
| Posted without asking | Never. Phase 2 requires an explicit yes. |
| Wrong account | `gh auth status` before posting; comments attribute to the active account. |
| Quoting/escaping breaks the call | Always use `--input review.json`, never inline `-f body=...` for multi-comment payloads. |

## Boundaries

- Reviews and (with consent) posts inline comments. Does **not** approve or request changes, write the code fix, or run linters.
- One quote/finding per line; the author reads the diff.
- "stop" / "chat only" / "don't post": generate the review, skip Phase 2 entirely.
