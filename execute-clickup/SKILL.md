---
name: execute-clickup
description: Turn a ClickUp task into a ready-to-build branch and validated spec. Use whenever the user hands you a ClickUp link (app.clickup.com/t/...), a ClickUp Custom ID like RT-656, or says things like "execute this clickup", "work on this clickup card", "start this ClickUp task", "let's build the clickup ticket", or "pick up <ticket>". Always use this when a ClickUp task is the starting point for work — it reads the card, creates a correctly-named git branch off a base you choose, then runs brainstorming + grilling to produce a stress-tested spec before any code is written.
---

# Execute ClickUp

Take a ClickUp task from link to a validated implementation spec, with a properly-named git branch in between. This skill is the front door for "here's a ticket, let's build it" — it pulls the card, sets up the branch, and then hands off to the brainstorming and grilling skills so the design is interrogated before anyone writes code.

The point is to never start coding from a raw ticket. Tickets are usually under-specified; this workflow forces the card's intent through a real design conversation first.

## Checklist

Create a TodoWrite task for each item and complete them in order. Do not skip ahead — each step depends on the previous one.

1. **Get the task ID** from the ClickUp link or Custom ID
2. **Verify the ClickUp MCP is available** — if not, help the user install it, then stop until it's connected
3. **Read the card** — title, description, Custom ID, status, priority, tags, and comments
4. **Classify the card** — feature, bugfix, or hotfix (ask if genuinely ambiguous)
5. **Ask the user which base branch to branch FROM** — never assume
6. **Create the branch** using the naming convention, after confirming the name
7. **Run brainstorming** (`superpowers:brainstorming`), seeded with the card details
8. **Run grilling** once a design/approach is converged on, *before* the spec is written
9. **Resume brainstorming's tail** — write spec, user review, then `writing-plans`

## Step 1 — Get the task ID

ClickUp links come in a few shapes:

- `https://app.clickup.com/t/86abc1234` → the part after `/t/` is the internal task ID
- `https://app.clickup.com/t/5747865/RT-656` → the last segment (`RT-656`) is the **Custom ID**; the number is the list/team ID
- A bare Custom ID like `RT-656` pasted directly

Pull out the identifier. If you only have a Custom ID, you may need the team/workspace ID too — the ClickUp MCP's get-task tool accepts a Custom ID when told it's custom. If a fetch fails because the ID is ambiguous, ask the user to paste the full URL.

## Step 2 — Verify the ClickUp MCP

This skill cannot read a card without the ClickUp MCP. Check whether ClickUp tools are available to you (tool names containing `clickup_get_task`, `clickup_get_task_comments`, etc. — the server prefix varies per install, so match on the `clickup_` portion, not a fixed prefix).

**If the ClickUp tools are present**, say so briefly and continue to Step 3.

**If they are NOT present**, do not improvise card details. Help the user install the ClickUp MCP, then stop and wait until it's connected. Read `references/installing-clickup-mcp.md` and walk the user through it. Once they confirm it's connected, restart from Step 1.

## Step 3 — Read the card

Use the ClickUp MCP to fetch the task. Gather everything that informs the design:

- **Title** and **description** (the core of what's being asked)
- **Custom ID** (e.g. `RT-656`) — needed for the branch name
- **Status**, **priority**, and **tags** — these help classify the card
- **Comments** — fetch these too (get-task-comments); requirements and edge cases often live in the discussion, not the description

Summarize the card back to the user in a few lines so they can confirm you're working from the right ticket before you create a branch.

## Step 4 — Classify the card

The classification decides the branch prefix. Use this judgment, in priority order:

| Signal | Type | Prefix |
|---|---|---|
| Urgent production breakage — "hotfix", "urgent", "prod down", critical priority on a defect | Hotfix | `hotfix/` |
| Something is broken and needs fixing — "bug", "fix", "error", "not working", "regression", a Bug task type/tag | Bugfix | `bugfix/` |
| New capability or change in behavior — "add", "implement", "support", "enhance", a Feature/Story task type | Feature | `feature/` |

Lead with the card's ClickUp task type or tags if it has them; fall back to title/description keywords. When the signals genuinely conflict or are silent, state your best guess and ask the user to confirm rather than guessing silently — the prefix affects where the branch should base from and how it's reviewed.

## Step 5 — Ask which base branch

**Always ask the user which branch to create the new branch FROM.** Do not assume `develop` or `main`. The right base differs by type and by team flow — a hotfix often branches from `main`/production, a feature from `develop`. Phrase it as a question with your recommendation based on the classification, e.g.:

> "This looks like a bugfix. Which branch should I create it from? (I'd suggest `develop` based on your recent history.)"

Wait for their answer before touching git.

## Step 6 — Create the branch

Build the branch name from the convention:

```
{prefix}/{CUSTOM_ID}-{shortened-task-title}
```

- `prefix` — `feature`, `bugfix`, or `hotfix` from Step 4
- `CUSTOM_ID` — the ClickUp Custom ID exactly as shown (e.g. `RT-656`)
- `shortened-task-title` — the title trimmed to the essential 3-6 words, lowercased, kebab-cased, punctuation stripped

**Examples:**

Card: `RT-656` "Basic host can redial missed voice call participant" (bug)
→ `bugfix/RT-656-basic-host-redial-missed-participant`

Card: `RT-812` "Allow inviting external users as participants" (feature)
→ `feature/RT-812-invite-external-users`

Card: `RT-901` "Payments webhook crashing in production" (urgent)
→ `hotfix/RT-901-payments-webhook-crash`

**Show the proposed branch name to the user and get a quick confirmation** (the title shortening is a judgment call and they may prefer different words). Then create it:

```bash
git checkout <base-branch>
git pull
git checkout -b <branch-name>
```

Use the base branch the user chose in Step 5. If the working tree is dirty, surface that and let the user decide before switching branches.

## Step 7 — Brainstorm, seeded with the card

Invoke the `superpowers:brainstorming` skill. The difference from a cold brainstorm is that you already have the card as the starting point — feed it in. Open the brainstorming by summarizing what the ticket is asking for (title, description, key comments, acceptance criteria) so the clarifying questions build on the card instead of rediscovering it.

Then follow brainstorming normally: explore context, ask clarifying questions one at a time, and propose approaches — **up to the point where you and the user have converged on an approach/design.**

**Do not let brainstorming write the spec yet.** The grilling step (Step 8) has to happen first. So go through brainstorming's understanding → approaches → design-presentation phases, but pause before its "write design doc" step.

## Step 8 — Grill the design before writing it down

Once a design/approach is on the table, invoke the `grilling` skill and put that design through it. Grilling interviews the user relentlessly, one question at a time, walking every branch of the design tree and resolving dependencies between decisions — exactly the pressure a thin ticket needs before it becomes a spec.

Why here, specifically: a spec written from an un-grilled design tends to bake in the ticket's original blind spots. Grilling surfaces the unasked questions while the design is still cheap to change — before it's committed to a doc and a plan. Fold every resolution from grilling back into the design.

When grilling reaches a shared understanding and the design is solid, continue.

## Step 9 — Resume brainstorming and finish

Pick brainstorming back up from where you paused — its spec-writing tail:

1. Write the design doc to brainstorming's spec location (`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` unless the project overrides it). Reference the ClickUp Custom ID and link in the spec so the work traces back to the ticket.
2. Run the spec self-review (placeholders, consistency, scope, ambiguity).
3. Ask the user to review the written spec.
4. On approval, invoke `writing-plans` to produce the implementation plan.

The terminal state is the same as brainstorming's: `writing-plans`. Do not jump to implementation skills from here.

## Notes

- This skill orchestrates other skills; it doesn't replace them. Let `brainstorming`, `grilling`, and `writing-plans` own their own behavior — your job is sequencing them around the ClickUp card and the branch.
- If the user already created a branch or already brainstormed, don't redo those steps — slot in wherever they are.
- Keep the user in control. The two hard gates are: ask which base branch before creating one, and don't write the spec until grilling has happened.
