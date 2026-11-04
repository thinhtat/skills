---
name: design-spec
description: Turn an intent.md from workspace/docs/intent/ into a reviewed spec.md under workspace/docs/design/specs/.
disable-model-invocation: true
---

# Design spec

Turns one **intent** (written by `/intent`) into a **spec**, using the process and template of `/to-spec` with the intent as the source. It finishes when the user has approved or closed the review of the spec. Tickets come afterwards, from `/design-to-tickets`.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`).

## Dependencies

This skill reads sibling skills: `to-spec` (mattpocock/skills), `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## 1. Pick the intent

- **Path given as argument:** use that `intent.md`.
- **No argument:** list every `$WS/docs/intent/*/intent.md`, mark the ones that already have a spec (a folder under `$WS/docs/design/specs/` ending in the same slug), and ask the user which one to design.

Done when exactly one `intent.md` is chosen and read in full.

## 2. Build the spec

Read [`../to-spec/SKILL.md`](../to-spec/SKILL.md) and follow its process and template, with these overrides:

- **Source.** The intent is the primary input; the conversation adds to it, never contradicts it. Map it onto the template:
  - Problem → Problem Statement.
  - Proposed outcome → Solution and the user stories.
  - Affected users and systems → the actors of the user stories and the modules in Implementation Decisions.
  - Constraints → Implementation Decisions and Out of Scope.
  - Open questions → Further Notes, still marked open. An answer found in the code or in existing docs under `$WS/docs/` is written as settled, with its source named.
- **Codebase.** Explore the repositories the intent names before writing Implementation and Testing Decisions; every module and seam named there exists in the code today or is marked new.
- **Publish.** Replace the issue-tracker step: write the file locally (step 3). No tracker, no triage label.

Done when every intent section is reflected in the spec, and the user has confirmed the test seams.

## 3. Write the spec

**Path.** `$WS/docs/design/specs/<DD-MM-YYYY>-<intent-slug>/spec.md`. The date is today; the intent slug is the intent folder's name without its date prefix (intent folder `30-10-2026-users-delete-draft-manual-entries` → slug `users-delete-draft-manual-entries`). Create `$WS/docs/design/specs/` if it does not exist. If the folder already exists, ask the user whether to update that spec or pick a new slug.

**Header.** The first line under the title is `Source intent: <path to intent.md>`, so the spec traces back to its intent.

Print the path of the written file.

## 4. Review the spec

Run the [review loop](../review-loop/SKILL.md) on `spec.md`.
