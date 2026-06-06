# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A collection of Claude Code **agent skills**. Each skill is authored as Markdown — there is no build, compile, lint, or test step. "Working in this repo" means writing and editing skill definitions, not running code.

## Structure

Each skill lives in its own top-level directory named after the skill, containing a single `SKILL.md`:

```
<skill-name>/SKILL.md
```

The directory name must match the `name` field in the SKILL.md frontmatter.

## SKILL.md format

Every `SKILL.md` begins with YAML frontmatter, then Markdown instructions:

```yaml
---
name: <skill-name>            # kebab-case, matches the directory name
description: <when to invoke> # written for the dispatcher, not the user — see below
allowed-tools: Bash, Read    # comma-separated tools the skill may use
---
```

The body is the procedure Claude follows when the skill is invoked. The existing `gitlab-pr` skill is the reference for house style — mirror its conventions when adding new skills.

### `description` is a routing trigger, not a summary

The `description` is what a dispatching Claude reads to decide whether to invoke the skill. Write it to maximize correct matching: list the concrete phrasings and intents that should trigger it ("create an MR", "open a merge request", "submit my branch"), and call out near-misses to disambiguate (e.g. gitlab-pr fires even when the user says "PR" instead of "MR", but explicitly defers to `gh pr create` for GitHub-hosted projects). Pack synonyms and edge cases in — this field does the work of getting the skill picked at the right time.

### Body conventions (from `gitlab-pr`)

- Open with `## Overview` and `## When to use`, then a numbered/stepped `## Workflow`.
- **Prerequisite checks** come before the workflow: verify tools/auth/state, and on failure surface the exact error and stop rather than guessing past it.
- Ground every action in real data — diff/log the actual branch, never invent content. When a section has nothing, say so explicitly (`_None_`) rather than omitting it.
- Be prescriptive about what *not* to do (e.g. "do not pass `--fill`", "ask before pushing"), since these are the steps Claude will otherwise get wrong.
- Provide concrete examples of inputs → outputs and a full worked example at the end.
